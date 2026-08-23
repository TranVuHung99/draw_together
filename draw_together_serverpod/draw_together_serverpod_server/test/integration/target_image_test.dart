import 'dart:convert';
import 'dart:typed_data';

import 'package:draw_together_serverpod_server/src/composition/target_image_slicer.dart';
import 'package:draw_together_serverpod_server/src/generated/protocol.dart';
import 'package:image/image.dart' as img;
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'streaming_harness.dart';
import 'test_tools/serverpod_test_tools.dart';

/// The target image end to end through the real endpoints: what the server
/// accepts, what it stores, how it slices it, and who it hands each slice to.
void main() {
  withServerpod('Given a room with a host and three drawers', (
    sessionBuilder,
    endpoints,
  ) {
    late Session session;
    late Room room;
    late int hostId;

    /// A source whose four quadrants are four flat colours, so a crop can be
    /// identified from its pixels alone.
    ByteData quadrantPng(int width, int height) {
      final image = img.Image(width: width, height: height);
      final colours = [
        img.ColorRgb8(255, 0, 0),
        img.ColorRgb8(0, 255, 0),
        img.ColorRgb8(0, 0, 255),
        img.ColorRgb8(255, 255, 0),
      ];
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final index = (y < height / 2 ? 0 : 2) + (x < width / 2 ? 0 : 1);
          image.setPixel(x, y, colours[index]);
        }
      }
      final bytes = Uint8List.fromList(img.encodePng(image));
      return ByteData.view(bytes.buffer);
    }

    List<int> centreColour(TargetImage stored) {
      final bytes = stored.bytes.buffer.asUint8List(
        stored.bytes.offsetInBytes,
        stored.bytes.lengthInBytes,
      );
      final decoded = img.decodeImage(bytes)!;
      final pixel = decoded.getPixel(decoded.width ~/ 2, decoded.height ~/ 2);
      return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
    }

    Future<List<TargetImage>> storedTargets() => TargetImage.db.find(
      session,
      where: (t) => t.roomId.equals(room.id!),
      orderBy: (t) => t.id,
    );

    Future<List<Player>> drawers() async {
      final players = await endpoints.room.getPlayersInRoom(
        sessionBuilder,
        room.id!,
      );
      return players.where((p) => p.id != hostId).toList();
    }

    setUp(() async {
      session = sessionBuilder.build();
      // A 1000 x 500 canvas, so the crop arithmetic the spec names is the
      // arithmetic under test rather than a square special case.
      room = (await endpoints.room.createRoom(
        sessionBuilder,
        'host',
        1000,
        500,
      ))!;
      hostId = room.hostId;
      for (final name in ['alice', 'bob', 'carol', 'dave']) {
        await endpoints.room.joinRoom(sessionBuilder, room.roomCode, name);
      }
    });

    group('when a target is uploaded', () {
      test('then it is normalized to the room aspect and stored as the one '
          'row owned by nobody', () async {
        expect(
          await endpoints.room.uploadTargetImage(
            sessionBuilder,
            room.id!,
            hostId,
            quadrantPng(600, 600),
          ),
          isTrue,
        );

        final stored = await storedTargets();
        expect(stored, hasLength(1));
        expect(stored.single.playerId, isNull);
        expect(stored.single.mimeType, targetImageMimeType);
        // A square source in a 2:1 room is centre-cropped to 2:1, not
        // stretched and not letterboxed.
        expect(stored.single.width / stored.single.height, closeTo(2.0, 0.02));
      });

      test('then a JPEG is stored as a PNG', () async {
        final jpeg = Uint8List.fromList(
          img.encodeJpg(img.Image(width: 400, height: 200)),
        );
        expect(
          await endpoints.room.uploadTargetImage(
            sessionBuilder,
            room.id!,
            hostId,
            ByteData.view(jpeg.buffer),
          ),
          isTrue,
        );

        final stored = (await storedTargets()).single;
        expect(stored.mimeType, targetImageMimeType);
        final bytes = stored.bytes.buffer.asUint8List(
          stored.bytes.offsetInBytes,
          stored.bytes.lengthInBytes,
        );
        expect(img.findFormatForData(bytes), img.ImageFormat.png);
      });

      test('then a second upload replaces the first', () async {
        await endpoints.room.uploadTargetImage(
          sessionBuilder,
          room.id!,
          hostId,
          quadrantPng(400, 200),
        );
        await endpoints.room.uploadTargetImage(
          sessionBuilder,
          room.id!,
          hostId,
          quadrantPng(800, 400),
        );

        final stored = await storedTargets();
        expect(stored, hasLength(1));
        expect(stored.single.width, 800);
      });

      test('then a file that is not an image is refused with no row '
          'written', () async {
        final notAnImage = Uint8List.fromList(
          utf8.encode('PK definitely not a picture'),
        );
        expect(
          await endpoints.room.uploadTargetImage(
            sessionBuilder,
            room.id!,
            hostId,
            ByteData.view(notAnImage.buffer),
          ),
          isFalse,
        );
        expect(await storedTargets(), isEmpty);
      });

      test('then an upload past the byte cap is refused with no row '
          'written', () async {
        expect(
          await endpoints.room.uploadTargetImage(
            sessionBuilder,
            room.id!,
            hostId,
            ByteData(maxTargetImageBytes + 1),
          ),
          isFalse,
        );
        expect(await storedTargets(), isEmpty);
      });

      test('then a non-host caller is refused and the stored target is '
          'unchanged', () async {
        await endpoints.room.uploadTargetImage(
          sessionBuilder,
          room.id!,
          hostId,
          quadrantPng(400, 200),
        );
        final alice = (await drawers()).first;

        expect(
          await endpoints.room.uploadTargetImage(
            sessionBuilder,
            room.id!,
            alice.id!,
            quadrantPng(800, 400),
          ),
          isFalse,
        );

        final stored = await storedTargets();
        expect(stored, hasLength(1));
        expect(stored.single.width, 400);
      });

      test('then an upload after the game has started is refused', () async {
        await endpoints.room.startGame(sessionBuilder, room.id!, hostId, 60);
        expect(
          await endpoints.room.uploadTargetImage(
            sessionBuilder,
            room.id!,
            hostId,
            quadrantPng(400, 200),
          ),
          isFalse,
        );
        expect(await storedTargets(), isEmpty);
      });
    });

    group('when the game starts with a target', () {
      setUp(() async {
        await endpoints.room.uploadTargetImage(
          sessionBuilder,
          room.id!,
          hostId,
          quadrantPng(1000, 500),
        );
      });

      test('then one crop is stored per drawing player and none for the '
          'host', () async {
        final connection = await RoomClients(
          endpoints,
          sessionBuilder,
          room.id!,
        ).connect(hostId);

        await endpoints.room.startGame(sessionBuilder, room.id!, hostId, 60);
        await settle();

        final crops = (await storedTargets())
            .where((t) => t.playerId != null)
            .toList();
        expect(crops, hasLength(4));
        expect(
          crops.map((c) => c.playerId).toSet(),
          (await drawers()).map((d) => d.id).toSet(),
        );
        expect(crops.any((c) => c.playerId == hostId), isFalse);

        // No image data travels on the room channel — it is a broadcast, so a
        // crop posted there would reach every subscriber.
        for (final message in connection.received) {
          expect(message, isNot(isA<TargetImage>()));
        }
        expect(connection.stateChanges.map((m) => m.status), contains('PLAYING'));

        await connection.close();
      });

      test('then each crop is the pixel rect its owner\'s region names',
          () async {
        await endpoints.room.startGame(sessionBuilder, room.id!, hostId, 60);

        // Four drawers partition the unit square into 2 x 2, so each region is
        // one quadrant of a 1000 x 500 target: a 500 x 250 rect, and the one
        // at (0.5, 0) is the 500 x 250 rect at (500, 0).
        for (final drawer in await drawers()) {
          final crop = (await endpoints.room.getTargetImagePart(
            sessionBuilder,
            room.id!,
            drawer.id!,
          ))!;

          expect(crop.width, (drawer.regionWidth! * 1000).round());
          expect(crop.height, (drawer.regionHeight! * 500).round());

          final expected = {
            '0.0,0.0': [255, 0, 0],
            '0.5,0.0': [0, 255, 0],
            '0.0,0.5': [0, 0, 255],
            '0.5,0.5': [255, 255, 0],
          }['${drawer.regionX},${drawer.regionY}']!;
          expect(centreColour(crop), expected, reason: drawer.name);
        }
      });

      test('then the host gets the whole target and each player only their '
          'own crop', () async {
        await endpoints.room.startGame(sessionBuilder, room.id!, hostId, 60);

        final whole = (await endpoints.room.getTargetImagePart(
          sessionBuilder,
          room.id!,
          hostId,
        ))!;
        expect(whole.playerId, isNull);
        expect(whole.width, 1000);
        expect(whole.height, 500);

        for (final drawer in await drawers()) {
          final crop = (await endpoints.room.getTargetImagePart(
            sessionBuilder,
            room.id!,
            drawer.id!,
          ))!;
          expect(crop.playerId, drawer.id);
          expect(crop.width, lessThan(whole.width));
        }
      });

      test('then a player of another room gets nothing', () async {
        await endpoints.room.startGame(sessionBuilder, room.id!, hostId, 60);

        final other = (await endpoints.room.createRoom(
          sessionBuilder,
          'other host',
          1000,
          500,
        ))!;
        final stranger = (await endpoints.room.joinRoom(
          sessionBuilder,
          other.roomCode,
          'stranger',
        ))!;

        expect(
          await endpoints.room.getTargetImagePart(
            sessionBuilder,
            room.id!,
            stranger.id!,
          ),
          isNull,
        );
        // Nor does the other room's host get this room's whole image.
        expect(
          await endpoints.room.getTargetImagePart(
            sessionBuilder,
            room.id!,
            other.hostId,
          ),
          isNull,
        );
      });
    });

    test('when the game starts with no target then it starts normally and '
        'produces no crops', () async {
      expect(
        await endpoints.room.startGame(sessionBuilder, room.id!, hostId, 60),
        isTrue,
      );
      expect(
        (await endpoints.room.getRoom(sessionBuilder, room.id!))!.status,
        'PLAYING',
      );
      expect(await storedTargets(), isEmpty);
      expect(
        await endpoints.room.getTargetImagePart(
          sessionBuilder,
          room.id!,
          hostId,
        ),
        isNull,
      );
    });
  });
}
