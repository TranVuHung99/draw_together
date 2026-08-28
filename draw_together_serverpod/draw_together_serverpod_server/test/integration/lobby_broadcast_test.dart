import 'package:draw_together_serverpod_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'streaming_harness.dart';
import 'test_tools/serverpod_test_tools.dart';

/// The lobby, driven the way the app drives it: everyone subscribes while the
/// room is still WAITING, and the roster and the start of the game reach them
/// as broadcasts.
///
/// The existing streaming tests all connect to a room that is already PLAYING,
/// so this sequence — subscribe first, transition afterwards — is not covered
/// by them.
void main() {
  withServerpod('Given a lobby everyone is already subscribed to', (
    sessionBuilder,
    endpoints,
  ) {
    late Room room;
    late int hostId;
    late RoomClients clients;

    setUp(() async {
      room = (await endpoints.room.createRoom(
        sessionBuilder,
        'host',
        1000,
        500,
      ))!;
      hostId = room.hostId;
      clients = RoomClients(endpoints, sessionBuilder, room.id!);
    });

    test('when a third player joins then every subscriber is told', () async {
      final alice = (await endpoints.room.joinRoom(
        sessionBuilder,
        room.roomCode,
        'alice',
      ))!;

      // Host and alice are both sitting in the waiting room.
      final hostConnection = await clients.connect(hostId);
      final aliceConnection = await clients.connect(alice.id!);

      final hostBefore = hostConnection.stateChanges.length;
      final aliceBefore = aliceConnection.stateChanges.length;

      await endpoints.room.joinRoom(sessionBuilder, room.roomCode, 'bob');
      await settle();

      final hostJoins = hostConnection.stateChanges
          .skip(hostBefore)
          .where((m) => m.status == 'PLAYER_JOINED');
      final aliceJoins = aliceConnection.stateChanges
          .skip(aliceBefore)
          .where((m) => m.status == 'PLAYER_JOINED');

      expect(hostJoins, hasLength(1), reason: 'the host was not told');
      expect(aliceJoins, hasLength(1), reason: 'alice was not told');

      await hostConnection.close();
      await aliceConnection.close();
    });

    test('when a client subscribes then it is told to load the roster', () async {
      final alice = (await endpoints.room.joinRoom(
        sessionBuilder,
        room.roomCode,
        'alice',
      ))!;

      final connection = await clients.connect(alice.id!);

      // Without this the client has to fetch the roster on its own initiative,
      // alongside its subscribe rather than after it.
      expect(
        connection.stateChanges.where((m) => m.status == 'PLAYER_JOINED'),
        hasLength(1),
      );

      await connection.close();
    });

    test('when the game starts then every subscriber is told', () async {
      final alice = (await endpoints.room.joinRoom(
        sessionBuilder,
        room.roomCode,
        'alice',
      ))!;

      final hostConnection = await clients.connect(hostId);
      final aliceConnection = await clients.connect(alice.id!);

      final hostBefore = hostConnection.stateChanges.length;
      final aliceBefore = aliceConnection.stateChanges.length;

      expect(
        await endpoints.room.startGame(sessionBuilder, room.id!, hostId, 120),
        isTrue,
      );
      await settle();

      final hostPlaying = hostConnection.stateChanges
          .skip(hostBefore)
          .where((m) => m.status == 'PLAYING');
      final alicePlaying = aliceConnection.stateChanges
          .skip(aliceBefore)
          .where((m) => m.status == 'PLAYING');

      expect(hostPlaying, hasLength(1), reason: 'the host was not told');
      expect(alicePlaying, hasLength(1), reason: 'alice was not told');

      await hostConnection.close();
      await aliceConnection.close();
    });
  });
}
