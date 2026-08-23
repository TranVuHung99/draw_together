import 'package:draw_together_serverpod_server/src/composition/canvas_svg.dart';
import 'package:draw_together_serverpod_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'streaming_harness.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Given a room being played', (sessionBuilder, endpoints) {
    late Session session;
    late RoomClients clients;
    late Room room;
    late Player host;
    late Player alice;
    late Player bob;

    setUp(() async {
      session = sessionBuilder.build();

      room = await Room.db.insertRow(
        session,
        Room(
          roomCode: 'TEST01',
          hostId: 0,
          status: 'WAITING',
          canvasWidth: 1000,
          canvasHeight: 1000,
        ),
      );
      host = await Player.db.insertRow(
        session,
        Player(roomId: room.id!, name: 'host'),
      );
      room = await Room.db.updateRow(session, room.copyWith(hostId: host.id!));

      alice = await Player.db.insertRow(
        session,
        Player(
          roomId: room.id!,
          name: 'alice',
          colorInfo: '0xFFF44336',
          regionX: 0,
          regionY: 0,
          regionWidth: 0.5,
          regionHeight: 1,
        ),
      );
      bob = await Player.db.insertRow(
        session,
        Player(
          roomId: room.id!,
          name: 'bob',
          colorInfo: '0xFF2196F3',
          regionX: 0.5,
          regionY: 0,
          regionWidth: 0.5,
          regionHeight: 1,
        ),
      );

      room = await Room.db.updateRow(
        session,
        room.copyWith(
          status: 'PLAYING',
          endTime: DateTime.now().add(const Duration(minutes: 5)),
        ),
      );

      clients = RoomClients(endpoints, sessionBuilder, room.id!);
    });

    Future<List<Stroke>> storedStrokes() => Stroke.db.find(
      session,
      where: (s) => s.roomId.equals(room.id!),
      orderBy: (s) => s.sequence,
    );

    test('when a stroke completes then exactly one row is written', () async {
      final connection = await clients.connect(alice.id!);
      await clients.draw(connection, alice.id!, 'stroke-a', [0.1, 0.1, 0.2, 0.2]);

      final stored = await storedStrokes();
      expect(stored, hasLength(1));
      expect(stored.single.strokeId, 'stroke-a');
      expect(stored.single.playerId, alice.id);
      expect(stored.single.points, [0.1, 0.1, 0.2, 0.2]);
      expect(stored.single.sequence, greaterThan(0));

      await connection.close();
    });

    test('when only start and update arrive then nothing is written', () async {
      final connection = await clients.connect(alice.id!);
      connection.outgoing.add(
        strokeMsg(
          roomId: room.id!,
          playerId: alice.id!,
          strokeId: 'stroke-open',
          action: 'start',
          points: [0.1, 0.1],
        ),
      );
      connection.outgoing.add(
        strokeMsg(
          roomId: room.id!,
          playerId: alice.id!,
          strokeId: 'stroke-open',
          action: 'update',
          points: [0.2, 0.2],
        ),
      );
      await settle();

      expect(await storedStrokes(), isEmpty);
      await connection.close();
    });

    test('when an end message is duplicated then it writes once', () async {
      final connection = await clients.connect(alice.id!);
      await clients.draw(connection, alice.id!, 'stroke-a', [0.1, 0.1, 0.2, 0.2]);
      connection.outgoing.add(
        strokeMsg(
          roomId: room.id!,
          playerId: alice.id!,
          strokeId: 'stroke-a',
          action: 'end',
          points: [0.1, 0.1, 0.2, 0.2],
        ),
      );
      await settle();

      expect(await storedStrokes(), hasLength(1));
      await connection.close();
    });

    test('when strokes complete then sequence increases per room', () async {
      final aliceConnection = await clients.connect(alice.id!);
      final bobConnection = await clients.connect(bob.id!);

      await clients.draw(aliceConnection, alice.id!, 'a1', [0.1, 0.1, 0.2, 0.2]);
      await clients.draw(bobConnection, bob.id!, 'b1', [0.6, 0.1, 0.7, 0.2]);
      await clients.draw(aliceConnection, alice.id!, 'a2', [0.3, 0.3, 0.4, 0.4]);

      final stored = await storedStrokes();
      expect(stored.map((s) => s.strokeId), ['a1', 'b1', 'a2']);
      expect(
        stored[0].sequence < stored[1].sequence &&
            stored[1].sequence < stored[2].sequence,
        isTrue,
      );

      await aliceConnection.close();
      await bobConnection.close();
    });

    test('when a client subscribes then stored strokes are replayed', () async {
      final aliceConnection = await clients.connect(alice.id!);
      await clients.draw(aliceConnection, alice.id!, 'a1', [0.1, 0.1, 0.2, 0.2]);
      await clients.draw(aliceConnection, alice.id!, 'a2', [0.3, 0.3, 0.4, 0.4]);

      // A reconnecting player gets their own strokes back, notwithstanding
      // echo suppression.
      final reconnected = await clients.connect(alice.id!);
      expect(reconnected.strokes.map((s) => s.strokeId), ['a1', 'a2']);
      expect(reconnected.strokes.every((s) => s.action == 'end'), isTrue);
      expect(reconnected.strokes.first.points, [0.1, 0.1, 0.2, 0.2]);

      // A late joiner sees the same canvas.
      final late = await clients.connect(bob.id!);
      expect(late.strokes.map((s) => s.strokeId), ['a1', 'a2']);

      await aliceConnection.close();
      await reconnected.close();
      await late.close();
    });

    test('when a room has no strokes then nothing is replayed', () async {
      final connection = await clients.connect(alice.id!);
      expect(connection.received, isEmpty);
      await connection.close();
    });

    test('when a stroke is live then its sender does not receive it', () async {
      final aliceConnection = await clients.connect(alice.id!);
      final bobConnection = await clients.connect(bob.id!);

      await clients.draw(aliceConnection, alice.id!, 'a1', [0.1, 0.1, 0.2, 0.2]);

      expect(aliceConnection.strokes, isEmpty);
      expect(bobConnection.strokes.map((s) => s.strokeId), ['a1', 'a1']);

      await aliceConnection.close();
      await bobConnection.close();
    });

    test('when a player undoes their latest then it is deleted and '
        'broadcast to everyone', () async {
      final aliceConnection = await clients.connect(alice.id!);
      final bobConnection = await clients.connect(bob.id!);
      await clients.draw(aliceConnection, alice.id!, 'a1', [0.1, 0.1, 0.2, 0.2]);
      await clients.draw(aliceConnection, alice.id!, 'a2', [0.3, 0.3, 0.4, 0.4]);

      aliceConnection.outgoing.add(
        StrokeUndoMsg(
          roomId: room.id!,
          playerId: alice.id!,
          strokeId: 'a2',
        ),
      );
      await settle();

      expect((await storedStrokes()).map((s) => s.strokeId), ['a1']);
      // The originator receives it too: the server is the authority on what
      // was removed.
      expect(aliceConnection.undos.map((u) => u.strokeId), ['a2']);
      expect(bobConnection.undos.map((u) => u.strokeId), ['a2']);

      await aliceConnection.close();
      await bobConnection.close();
    });

    test('when an undo names another player\'s stroke then nothing '
        'is deleted', () async {
      final aliceConnection = await clients.connect(alice.id!);
      final bobConnection = await clients.connect(bob.id!);
      await clients.draw(bobConnection, bob.id!, 'b1', [0.6, 0.1, 0.7, 0.2]);

      aliceConnection.outgoing.add(
        StrokeUndoMsg(
          roomId: room.id!,
          playerId: alice.id!,
          strokeId: 'b1',
        ),
      );
      await settle();

      expect((await storedStrokes()).map((s) => s.strokeId), ['b1']);
      expect(aliceConnection.undos, isEmpty);
      expect(bobConnection.undos, isEmpty);

      await aliceConnection.close();
      await bobConnection.close();
    });

    test('when an undo names an older stroke then it is refused', () async {
      final connection = await clients.connect(alice.id!);
      await clients.draw(connection, alice.id!, 'a1', [0.1, 0.1, 0.2, 0.2]);
      await clients.draw(connection, alice.id!, 'a2', [0.3, 0.3, 0.4, 0.4]);

      connection.outgoing.add(
        StrokeUndoMsg(
          roomId: room.id!,
          playerId: alice.id!,
          strokeId: 'a1',
        ),
      );
      await settle();

      expect((await storedStrokes()).map((s) => s.strokeId), ['a1', 'a2']);
      expect(connection.undos, isEmpty);

      await connection.close();
    });

    test('when a player has drawn nothing then undo is refused', () async {
      final connection = await clients.connect(alice.id!);
      connection.outgoing.add(
        StrokeUndoMsg(
          roomId: room.id!,
          playerId: alice.id!,
          strokeId: 'nothing',
        ),
      );
      await settle();

      expect(await storedStrokes(), isEmpty);
      expect(connection.undos, isEmpty);
      await connection.close();
    });

    test('when an undo claims someone else\'s playerId then it is '
        'discarded', () async {
      final aliceConnection = await clients.connect(alice.id!);
      final bobConnection = await clients.connect(bob.id!);
      await clients.draw(bobConnection, bob.id!, 'b1', [0.6, 0.1, 0.7, 0.2]);

      // Alice's connection, claiming to be Bob.
      aliceConnection.outgoing.add(
        StrokeUndoMsg(roomId: room.id!, playerId: bob.id!, strokeId: 'b1'),
      );
      await settle();

      expect((await storedStrokes()).map((s) => s.strokeId), ['b1']);
      await aliceConnection.close();
      await bobConnection.close();
    });

    test('when the room is finished then strokes and undos are '
        'refused', () async {
      final connection = await clients.connect(alice.id!);
      await clients.draw(connection, alice.id!, 'a1', [0.1, 0.1, 0.2, 0.2]);

      await Room.db.updateRow(session, room.copyWith(status: 'FINISHED'));

      await clients.draw(connection, alice.id!, 'a2', [0.3, 0.3, 0.4, 0.4]);
      connection.outgoing.add(
        StrokeUndoMsg(roomId: room.id!, playerId: alice.id!, strokeId: 'a1'),
      );
      await settle();

      expect((await storedStrokes()).map((s) => s.strokeId), ['a1']);
      expect(connection.undos, isEmpty);

      await connection.close();
    });

    test('when a stroke leaves its region then it is clamped', () async {
      final connection = await clients.connect(alice.id!);
      // Alice's region is the left half; the second point is outside it.
      await clients.draw(connection, alice.id!, 'a1', [0.1, 0.1, 0.9, 0.2]);

      final stored = await storedStrokes();
      expect(stored.single.points, [0.1, 0.1, 0.5, 0.2]);
      await connection.close();
    });

    test('when the host sends a stroke then it is ignored', () async {
      final connection = await clients.connect(host.id!);
      await clients.draw(connection, host.id!, 'h1', [0.1, 0.1, 0.2, 0.2]);

      expect(await storedStrokes(), isEmpty);
      await connection.close();
    });
  });

  withServerpod('Given the room endpoint', (sessionBuilder, endpoints) {
    test('when starting a room with no drawing players then it is '
        'refused', () async {
      final room = await endpoints.room.createRoom(
        sessionBuilder,
        'host',
        1000,
        1000,
      );
      expect(
        await endpoints.room.startGame(
          sessionBuilder,
          room!.id!,
          room.hostId,
          60,
        ),
        isFalse,
      );
      final stored = await endpoints.room.getRoom(sessionBuilder, room.id!);
      expect(stored!.status, 'WAITING');
    });

    test('when a game is already playing then joining and starting are '
        'refused', () async {
      final room = await endpoints.room.createRoom(
        sessionBuilder,
        'host',
        1000,
        1000,
      );
      await endpoints.room.joinRoom(sessionBuilder, room!.roomCode, 'alice');

      expect(
        await endpoints.room.startGame(
          sessionBuilder,
          room.id!,
          room.hostId,
          60,
        ),
        isTrue,
      );
      expect(
        await endpoints.room.startGame(
          sessionBuilder,
          room.id!,
          room.hostId,
          60,
        ),
        isFalse,
      );
      expect(
        await endpoints.room.joinRoom(sessionBuilder, room.roomCode, 'late'),
        isNull,
      );
    });
  });

  group('Given persisted strokes', () {
    final room = Room(
      id: 1,
      roomCode: 'TEST01',
      hostId: 1,
      status: 'FINISHED',
      canvasWidth: 1000,
      canvasHeight: 800,
    );
    final players = [
      // The host draws nothing and has no region.
      Player(id: 1, roomId: 1, name: 'host'),
      Player(
        id: 2,
        roomId: 1,
        name: 'alice',
        regionX: 0,
        regionY: 0,
        regionWidth: 0.5,
        regionHeight: 1,
      ),
      Player(
        id: 3,
        roomId: 1,
        name: 'bob',
        regionX: 0.5,
        regionY: 0,
        regionWidth: 0.5,
        regionHeight: 1,
      ),
    ];

    Stroke stroke({
      required int id,
      required int playerId,
      required int sequence,
      bool isEraser = false,
      String colorInfo = '0xFFF44336',
    }) => Stroke(
      id: id,
      roomId: 1,
      playerId: playerId,
      strokeId: 's$id',
      points: [0.1, 0.1, 0.2, 0.25],
      colorInfo: colorInfo,
      strokeWidth: 0.005,
      isEraser: isEraser,
      sequence: sequence,
      timestamp: DateTime.utc(2026),
    );

    test('when the composite is generated then it is a unit-viewBox '
        'document', () {
      final svg = composeCanvasSvg(
        room: room,
        players: players,
        strokes: [stroke(id: 1, playerId: 2, sequence: 1)],
      );

      expect(svg, startsWith('<svg xmlns="http://www.w3.org/2000/svg"'));
      expect(svg, contains('viewBox="0 0 1 1"'));
      expect(svg, contains('width="1000" height="800"'));
      expect(svg, contains('stroke-linecap="round"'));
      expect(svg, contains('stroke-linejoin="round"'));
      expect(svg, contains('stroke="#f44336"'));
      expect(svg, contains('points="0.1,0.1 0.2,0.25"'));
      expect(svg, endsWith('</svg>'));
    });

    test('when several players drew then each gets one clipped group', () {
      final svg = composeCanvasSvg(
        room: room,
        players: players,
        strokes: [
          stroke(id: 1, playerId: 3, sequence: 1),
          stroke(id: 2, playerId: 2, sequence: 2),
        ],
      );

      // Ascending player id order, whatever order the strokes arrived in.
      expect(svg.indexOf('url(#clip2)'), lessThan(svg.indexOf('url(#clip3)')));
      expect(svg, contains('<clipPath id="clip2"'));
      expect(svg, contains('<clipPath id="clip3"'));
      // The host contributes no layer.
      expect(svg, isNot(contains('clip1')));
    });

    test('when a player erased then only their earlier strokes are '
        'masked', () {
      final svg = composeCanvasSvg(
        room: room,
        players: players,
        strokes: [
          stroke(id: 1, playerId: 2, sequence: 1),
          stroke(id: 2, playerId: 2, sequence: 2, isEraser: true),
          stroke(id: 3, playerId: 2, sequence: 3),
          stroke(id: 4, playerId: 3, sequence: 4),
        ],
      );

      expect(svg, contains('<mask id="mask2"'));
      // The mask wraps what was drawn before it and nothing after: the stroke
      // that follows the eraser is a sibling of the masked group.
      final layer = svg.substring(svg.indexOf('<g clip-path="url(#clip2)">'));
      final masked = layer.indexOf('<g mask="url(#mask2)">');
      final closed = layer.indexOf('</g>', masked);
      expect(layer.substring(masked, closed), contains('#f44336'));
      // Bob's layer carries no mask of Alice's eraser.
      final bobLayer = svg.substring(svg.indexOf('<g clip-path="url(#clip3)">'));
      expect(bobLayer, isNot(contains('mask')));
    });

    test('when nothing was drawn then the document is just the '
        'background', () {
      final svg = composeCanvasSvg(room: room, players: players, strokes: []);
      expect(svg, contains('fill="#ffffff"'));
      expect(svg, isNot(contains('<polyline')));
    });
  });
}
