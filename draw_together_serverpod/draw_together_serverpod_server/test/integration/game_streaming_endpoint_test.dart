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

    test('when a room has no strokes then no canvas is replayed', () async {
      final connection = await clients.connect(alice.id!);
      // The room's state still arrives — it is not part of the canvas.
      expect(connection.strokes, isEmpty);
      expect(connection.undos, isEmpty);
      await connection.close();
    });

    test('when a stroke is in progress then its sender does not receive the '
        'batches back', () async {
      final aliceConnection = await clients.connect(alice.id!);
      final bobConnection = await clients.connect(bob.id!);

      await clients.sendStroke(
        aliceConnection,
        alice.id!,
        'a1',
        'start',
        [0.1, 0.1],
      );
      await clients.sendStroke(
        aliceConnection,
        alice.id!,
        'a1',
        'update',
        [0.15, 0.15],
      );

      expect(aliceConnection.strokes, isEmpty);
      expect(bobConnection.strokes.map((s) => s.action), ['start', 'update']);

      await aliceConnection.close();
      await bobConnection.close();
    });

    test('when a stroke completes then its author receives the end back with '
        'the clamped points', () async {
      final aliceConnection = await clients.connect(alice.id!);
      final bobConnection = await clients.connect(bob.id!);

      // The second point is outside Alice's half, so the copy that comes back
      // is the server's, not the one she sent.
      await clients.draw(aliceConnection, alice.id!, 'a1', [0.1, 0.1, 0.9, 0.2]);

      // Receiving the `end` is what confirms the stroke to its author: the
      // `start` is still suppressed, so this is the only message she gets.
      expect(aliceConnection.strokes.map((s) => s.action), ['end']);
      expect(aliceConnection.strokes.single.strokeId, 'a1');
      expect(aliceConnection.strokes.single.points, [0.1, 0.1, 0.5, 0.2]);
      // Everyone else receives it too, unchanged.
      expect(bobConnection.strokes.map((s) => s.strokeId), ['a1', 'a1']);
      expect(bobConnection.strokes.last.points, [0.1, 0.1, 0.5, 0.2]);
      expect(aliceConnection.rejections, isEmpty);

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
      // The author is told, and told which rule refused it.
      expect(connection.rejections.map((r) => r.strokeId), ['a2']);
      expect(connection.rejections.single.reason, 'NOT_PLAYING');
      // The `start` for a2 got through on the cached status, so the refused
      // `end` retracts it rather than leaving a fragment on every client.
      expect(connection.undos.map((u) => u.strokeId), ['a2']);

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

    test('when the host sends a stroke then it is refused for having no '
        'region', () async {
      final connection = await clients.connect(host.id!);
      await clients.draw(connection, host.id!, 'h1', [0.1, 0.1, 0.2, 0.2]);

      expect(await storedStrokes(), isEmpty);
      expect(
        connection.rejections.map((r) => r.reason),
        // One for the `start`, one for the `end`.
        ['NO_REGION', 'NO_REGION'],
      );
      expect(connection.rejections.first.strokeId, 'h1');
      // Nothing was ever broadcast, so there is no fragment to retract.
      expect(connection.undos, isEmpty);
      await connection.close();
    });

    test('when a stroke names another player then it is refused as not the '
        'owner', () async {
      final aliceConnection = await clients.connect(alice.id!);
      final bobConnection = await clients.connect(bob.id!);

      // Alice's connection, claiming to be Bob.
      await clients.sendStroke(
        aliceConnection,
        bob.id!,
        'spoofed',
        'end',
        [0.6, 0.1, 0.7, 0.2],
      );

      expect(await storedStrokes(), isEmpty);
      expect(aliceConnection.rejections.single.reason, 'NOT_OWNER');
      expect(aliceConnection.rejections.single.strokeId, 'spoofed');
      // The rejection is addressed to one client: nothing reached the channel,
      // so Bob does not learn that a stroke naming him was refused.
      expect(bobConnection.rejections, isEmpty);
      expect(bobConnection.strokes, isEmpty);
      expect(bobConnection.undos, isEmpty);

      await aliceConnection.close();
      await bobConnection.close();
    });

    test('when the same stroke id occurs in another room then it is still '
        'stored', () async {
      // A stroke id identifies a stroke within its room, so a collision across
      // rooms must not silently discard the second one.
      final other = await Room.db.insertRow(
        session,
        Room(
          roomCode: 'TEST02',
          hostId: host.id!,
          status: 'PLAYING',
          canvasWidth: 1000,
          canvasHeight: 1000,
          endTime: DateTime.now().add(const Duration(minutes: 5)),
        ),
      );
      final carol = await Player.db.insertRow(
        session,
        Player(
          roomId: other.id!,
          name: 'carol',
          regionX: 0,
          regionY: 0,
          regionWidth: 1,
          regionHeight: 1,
        ),
      );

      final here = await clients.connect(alice.id!);
      await clients.draw(here, alice.id!, 'shared', [0.1, 0.1, 0.2, 0.2]);

      final elsewhere = RoomClients(endpoints, sessionBuilder, other.id!);
      final there = await elsewhere.connect(carol.id!);
      await elsewhere.draw(there, carol.id!, 'shared', [0.3, 0.3, 0.4, 0.4]);

      expect((await storedStrokes()).map((s) => s.strokeId), ['shared']);
      final otherRoomStrokes = await Stroke.db.find(
        session,
        where: (s) => s.roomId.equals(other.id!),
      );
      expect(otherRoomStrokes.map((s) => s.strokeId), ['shared']);
      expect(otherRoomStrokes.single.points, [0.3, 0.3, 0.4, 0.4]);

      await here.close();
      await there.close();
    });

    group('Given a client subscribing', () {
      test('when it subscribes then the room state arrives before the '
          'canvas', () async {
        final drawn = await clients.connect(alice.id!);
        await clients.draw(drawn, alice.id!, 'a1', [0.1, 0.1, 0.2, 0.2]);

        final connection = await clients.connect(bob.id!);

        // Room state first: a client should not paint a canvas before it knows
        // the rules the canvas is under.
        expect(connection.received.first, isA<GameStateChangeMsg>());
        expect(connection.roomStates.single.status, 'PLAYING');
        expect(connection.roomStates.single.endTime, isNotNull);
        expect(connection.strokes.map((s) => s.strokeId), ['a1']);

        await drawn.close();
        await connection.close();
      });

      test('when the room was paused while it was away then it learns the '
          'room is paused', () async {
        await endpoints.room.pauseGame(sessionBuilder, room.id!, host.id!);
        await settle();

        // A client that was not connected for the pause broadcast. Without the
        // state replay it would hold `PLAYING` forever: a drawable canvas
        // whose every stroke comes back refused.
        final connection = await clients.connect(alice.id!);

        expect(connection.roomStates.single.status, 'PAUSED');
        expect(connection.roomStates.single.remainingMs, isNotNull);
        // The deadline is cleared on pause, so the replayed state clears it too
        // rather than leaving the client counting down to a stale one.
        expect(connection.roomStates.single.endTime, isNull);

        await connection.close();
      });

      test('when the game started while it was away then it learns the game '
          'is playing', () async {
        // The waiting screen leaves only on `PLAYING`, so a client that misses
        // that broadcast sits out the whole round.
        final connection = await clients.connect(alice.id!);

        expect(connection.roomStates.single.status, 'PLAYING');
        expect(connection.roomStates.single.endTime, isNotNull);

        await connection.close();
      });

      test('when the room finished while it was away then it receives the '
          'state and the stored composite', () async {
        final drawn = await clients.connect(alice.id!);
        await clients.draw(drawn, alice.id!, 'a1', [0.1, 0.1, 0.2, 0.2]);
        await drawn.close();

        await endpoints.room.stopGame(sessionBuilder, room.id!, host.id!);
        await settle();

        // The composite is broadcast once, at the one instant every client in
        // the room is at risk together. It is stored so this client can still
        // be given it.
        final stored = await Room.db.findById(session, room.id!);
        expect(stored!.finalSvg, isNotNull);

        final connection = await clients.connect(alice.id!);

        expect(connection.roomStates.single.status, 'FINISHED');
        expect(connection.composites.single.svg, stored.finalSvg);
        // Navigation to the result is driven by the composite arriving, so
        // without it this client holds a game screen that never progresses.
        expect(connection.composites, hasLength(1));

        await connection.close();
      });

      test('when the room is still in progress then no composite is '
          'delivered', () async {
        final connection = await clients.connect(alice.id!);

        expect(connection.composites, isEmpty);
        expect(
          (await Room.db.findById(session, room.id!))!.finalSvg,
          isNull,
        );

        await connection.close();
      });
    });

    group('Given a stroke left open', () {
      test('when the room is paused mid-stroke then the fragment is retracted '
          'from everyone', () async {
        final aliceConnection = await clients.connect(alice.id!);
        final bobConnection = await clients.connect(bob.id!);

        // Alice starts a stroke; Bob has seen it start.
        await clients.sendStroke(
          aliceConnection,
          alice.id!,
          'open',
          'start',
          [0.1, 0.1],
        );
        expect(bobConnection.strokes.map((s) => s.action), ['start']);

        await endpoints.room.pauseGame(sessionBuilder, room.id!, host.id!);
        await settle();

        // The next message for that stroke is refused, and the fragment goes
        // with it.
        await clients.sendStroke(
          aliceConnection,
          alice.id!,
          'open',
          'end',
          [0.1, 0.1, 0.2, 0.2],
        );

        expect(await storedStrokes(), isEmpty);
        expect(aliceConnection.rejections.single.reason, 'NOT_PLAYING');
        // The retraction is a broadcast: it has to reach every client that saw
        // the stroke start, including its author.
        expect(aliceConnection.undos.map((u) => u.strokeId), ['open']);
        expect(bobConnection.undos.map((u) => u.strokeId), ['open']);

        // And a client arriving afterwards replays a canvas with no trace of
        // it, so all three agree: author, observer, and fresh joiner.
        final fresh = await clients.connect(bob.id!);
        expect(fresh.strokes, isEmpty);

        await fresh.close();
        await aliceConnection.close();
        await bobConnection.close();
      });

      test('when the room resumes and a late end arrives then nothing is '
          'stored and nothing is retracted twice', () async {
        final aliceConnection = await clients.connect(alice.id!);
        final bobConnection = await clients.connect(bob.id!);

        await clients.sendStroke(
          aliceConnection,
          alice.id!,
          'open',
          'start',
          [0.1, 0.1],
        );
        await endpoints.room.pauseGame(sessionBuilder, room.id!, host.id!);
        await settle();
        await clients.sendStroke(
          aliceConnection,
          alice.id!,
          'open',
          'update',
          [0.15, 0.15],
        );

        await endpoints.room.resumeGame(sessionBuilder, room.id!, host.id!);
        await settle();

        // The in-flight `end` arrives after the room is playing again. Without
        // the abandoned-id memory it would persist a stroke every client has
        // already been told to remove.
        await clients.sendStroke(
          aliceConnection,
          alice.id!,
          'open',
          'end',
          [0.1, 0.1, 0.2, 0.2],
        );

        expect(await storedStrokes(), isEmpty);
        expect(aliceConnection.undos.map((u) => u.strokeId), ['open']);
        expect(bobConnection.undos.map((u) => u.strokeId), ['open']);
        expect(
          aliceConnection.rejections.map((r) => r.reason),
          ['NOT_PLAYING', 'ABANDONED'],
        );

        await aliceConnection.close();
        await bobConnection.close();
      });

      test('when the connection ends mid-stroke then the fragment is '
          'retracted', () async {
        final aliceConnection = await clients.connect(alice.id!);
        final bobConnection = await clients.connect(bob.id!);

        await clients.sendStroke(
          aliceConnection,
          alice.id!,
          'open',
          'start',
          [0.1, 0.1],
        );
        expect(bobConnection.strokes.map((s) => s.action), ['start']);

        // Alice's connection goes away without an `end`.
        await aliceConnection.close();
        await settle();

        expect(await storedStrokes(), isEmpty);
        expect(bobConnection.undos.map((u) => u.strokeId), ['open']);

        await bobConnection.close();
      });

      test('when a stroke completed cleanly then a later refusal retracts '
          'nothing', () async {
        final aliceConnection = await clients.connect(alice.id!);
        final bobConnection = await clients.connect(bob.id!);

        await clients.draw(
          aliceConnection,
          alice.id!,
          'done',
          [0.1, 0.1, 0.2, 0.2],
        );

        await endpoints.room.pauseGame(sessionBuilder, room.id!, host.id!);
        await settle();

        // A new stroke, refused before anything was broadcast for it.
        await clients.sendStroke(
          aliceConnection,
          alice.id!,
          'next',
          'start',
          [0.3, 0.3],
        );

        expect((await storedStrokes()).map((s) => s.strokeId), ['done']);
        expect(aliceConnection.rejections.single.strokeId, 'next');
        // The completed stroke is persisted, so there is no open stroke and
        // nothing to take back.
        expect(aliceConnection.undos, isEmpty);
        expect(bobConnection.undos, isEmpty);

        await aliceConnection.close();
        await bobConnection.close();
      });
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
