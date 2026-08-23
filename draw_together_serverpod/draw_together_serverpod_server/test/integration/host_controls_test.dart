import 'package:draw_together_serverpod_server/src/composition/canvas_svg.dart';
import 'package:draw_together_serverpod_server/src/endpoints/room_endpoint.dart';
import 'package:draw_together_serverpod_server/src/future_calls/game_end_future_call.dart';
import 'package:draw_together_serverpod_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'streaming_harness.dart';
import 'test_tools/serverpod_test_tools.dart';

/// The host's session controls, driven through the real endpoints: who may
/// call them, what pausing does to the clock, and what a stopped game produces
/// compared with one that ran out.
void main() {
  withServerpod('Given a running game with two drawers', (
    sessionBuilder,
    endpoints,
  ) {
    late Session session;
    late RoomClients clients;
    late Room room;
    late int hostId;
    late List<Player> drawers;

    List<double> insideRegion(Player player) {
      final centreX = player.regionX! + player.regionWidth! / 2;
      final centreY = player.regionY! + player.regionHeight! / 2;
      return [centreX - 0.02, centreY, centreX + 0.02, centreY];
    }

    Future<Room> reload() async =>
        (await endpoints.room.getRoom(sessionBuilder, room.id!))!;

    Future<List<Stroke>> storedStrokes() => Stroke.db.find(
      session,
      where: (s) => s.roomId.equals(room.id!),
      orderBy: (s) => s.sequence,
    );

    /// Moves the room's deadline into the past, which is what a scheduled call
    /// firing on time actually finds.
    Future<void> expireDeadline() async {
      final current = await reload();
      await Room.db.updateRow(
        session,
        current.copyWith(
          endTime: DateTime.now().subtract(const Duration(seconds: 1)),
        ),
      );
    }

    /// A lobby of one host and two drawers, not yet started.
    Future<void> openLobby() async {
      room = (await endpoints.room.createRoom(
        sessionBuilder,
        'host',
        1000,
        500,
      ))!;
      hostId = room.hostId;
      for (final name in ['alice', 'bob']) {
        await endpoints.room.joinRoom(sessionBuilder, room.roomCode, name);
      }
    }

    Future<void> start({int durationSeconds = 120}) async {
      expect(
        await endpoints.room.startGame(
          sessionBuilder,
          room.id!,
          hostId,
          durationSeconds,
        ),
        isTrue,
      );
      room = await reload();
      final players = await endpoints.room.getPlayersInRoom(
        sessionBuilder,
        room.id!,
      );
      drawers = players.where((p) => p.id != hostId).toList();
      clients = RoomClients(endpoints, sessionBuilder, room.id!);
    }

    setUp(() async {
      session = sessionBuilder.build();
      await openLobby();
    });

    group('when the caller is not the host', () {
      test('then every session command is refused and nothing is broadcast',
          () async {
        await start();
        final alice = drawers.first;
        final connection = await clients.connect(alice.id!);
        final before = await reload();

        expect(
          await endpoints.room.pauseGame(sessionBuilder, room.id!, alice.id!),
          isFalse,
        );
        expect(
          await endpoints.room.resumeGame(sessionBuilder, room.id!, alice.id!),
          isFalse,
        );
        expect(
          await endpoints.room.stopGame(sessionBuilder, room.id!, alice.id!),
          isFalse,
        );
        await settle();

        final after = await reload();
        expect(after.status, before.status);
        expect(after.endTime, before.endTime);
        expect(after.remainingMs, isNull);
        expect(connection.stateChanges, isEmpty);

        await connection.close();
      });

      test('then a non-host cannot start the game either', () async {
        final players = await endpoints.room.getPlayersInRoom(
          sessionBuilder,
          room.id!,
        );
        final alice = players.firstWhere((p) => p.id != hostId);

        expect(
          await endpoints.room.startGame(
            sessionBuilder,
            room.id!,
            alice.id!,
            60,
          ),
          isFalse,
        );
        expect((await reload()).status, 'WAITING');
      });

      test('then the host of a different room is refused too', () async {
        final other = (await endpoints.room.createRoom(
          sessionBuilder,
          'other host',
          1000,
          500,
        ))!;

        expect(
          await endpoints.room.startGame(
            sessionBuilder,
            room.id!,
            other.hostId,
            60,
          ),
          isFalse,
        );
        expect((await reload()).status, 'WAITING');
        expect(
          (await endpoints.room.getRoom(sessionBuilder, other.id!))!.status,
          'WAITING',
        );
      });
    });

    group('when the host chooses the duration', () {
      test('then the deadline is that duration rather than a default',
          () async {
        final before = DateTime.now();
        await start(durationSeconds: 180);

        final endTime = (await reload()).endTime!;
        expect(
          endTime.difference(before).inSeconds,
          closeTo(180, 5),
        );
      });

      test('then a duration outside the supported range is refused', () async {
        for (final seconds in [minRoundSeconds - 1, maxRoundSeconds + 1, 0]) {
          expect(
            await endpoints.room.startGame(
              sessionBuilder,
              room.id!,
              hostId,
              seconds,
            ),
            isFalse,
            reason: '$seconds seconds',
          );
          expect((await reload()).status, 'WAITING');
        }
      });
    });

    group('when the host pauses', () {
      test('then the remainder is banked, the deadline is cleared, and every '
          'client is told', () async {
        await start(durationSeconds: 120);
        final connection = await clients.connect(drawers.first.id!);

        expect(
          await endpoints.room.pauseGame(sessionBuilder, room.id!, hostId),
          isTrue,
        );
        await settle();

        final paused = await reload();
        expect(paused.status, 'PAUSED');
        expect(paused.endTime, isNull);
        expect(paused.pausedAt, isNotNull);
        expect(paused.remainingMs, closeTo(120000, 5000));

        final change = connection.stateChanges
            .where((m) => m.status == 'PAUSED')
            .single;
        expect(change.endTime, isNull);
        expect(change.remainingMs, paused.remainingMs);

        await connection.close();
      });

      test('then a stroke and an undo are neither persisted nor rebroadcast',
          () async {
        await start();
        final alice = drawers.first;
        final bob = drawers[1];
        final aliceConnection = await clients.connect(alice.id!);
        final bobConnection = await clients.connect(bob.id!);

        await clients.draw(
          aliceConnection,
          alice.id!,
          'before-pause',
          insideRegion(alice),
        );
        final beforePause = (await storedStrokes()).map((s) => s.strokeId);
        final seenByBob = bobConnection.strokes.length;

        await endpoints.room.pauseGame(sessionBuilder, room.id!, hostId);
        await settle();

        await clients.draw(
          aliceConnection,
          alice.id!,
          'while-paused',
          insideRegion(alice),
        );
        await clients.undo(aliceConnection, alice.id!, 'before-pause');

        // Nothing written, nothing removed, and no partial stroke on anyone
        // else's screen — the guard covers `start` and `update` as well as the
        // completed `end`.
        expect((await storedStrokes()).map((s) => s.strokeId), beforePause);
        expect(bobConnection.strokes, hasLength(seenByBob));
        expect(bobConnection.undos, isEmpty);

        await aliceConnection.close();
        await bobConnection.close();
      });

      test('then the original deadline firing changes nothing and broadcasts '
          'nothing', () async {
        await start();
        final connection = await clients.connect(drawers.first.id!);
        await endpoints.room.pauseGame(sessionBuilder, room.id!, hostId);
        await settle();
        final afterPause = await reload();

        // The schedule may already have been picked up when the pause landed;
        // the room row, not the schedule, decides.
        await GameEndFutureCall().finalizeRoom(session, room.id!);
        await settle();

        final after = await reload();
        expect(after.status, 'PAUSED');
        expect(after.remainingMs, afterPause.remainingMs);
        expect(connection.composites, isEmpty);
        expect(
          connection.stateChanges.where((m) => m.status == 'FINISHED'),
          isEmpty,
        );

        await connection.close();
      });

      test('then pausing a game that is not playing is refused', () async {
        // WAITING.
        expect(
          await endpoints.room.pauseGame(sessionBuilder, room.id!, hostId),
          isFalse,
        );

        await start();
        await endpoints.room.pauseGame(sessionBuilder, room.id!, hostId);
        // Already PAUSED.
        expect(
          await endpoints.room.pauseGame(sessionBuilder, room.id!, hostId),
          isFalse,
        );

        await endpoints.room.stopGame(sessionBuilder, room.id!, hostId);
        // FINISHED.
        expect(
          await endpoints.room.pauseGame(sessionBuilder, room.id!, hostId),
          isFalse,
        );
        expect((await reload()).status, 'FINISHED');
      });
    });

    group('when the host resumes', () {
      test('then a 120s round paused at 30s leaves exactly 90s', () async {
        await start(durationSeconds: 120);

        // Thirty seconds of the round have gone by. Moving the deadline is how
        // the passage of time is stated without waiting for it.
        final running = await reload();
        await Room.db.updateRow(
          session,
          running.copyWith(
            endTime: DateTime.now().add(const Duration(seconds: 90)),
          ),
        );

        await endpoints.room.pauseGame(sessionBuilder, room.id!, hostId);
        expect((await reload()).remainingMs, closeTo(90000, 2000));

        final atResume = DateTime.now();
        expect(
          await endpoints.room.resumeGame(sessionBuilder, room.id!, hostId),
          isTrue,
        );

        final resumed = await reload();
        expect(resumed.status, 'PLAYING');
        expect(resumed.pausedAt, isNull);
        expect(resumed.remainingMs, isNull);
        expect(
          resumed.endTime!.difference(atResume).inMilliseconds,
          closeTo(90000, 2000),
        );
      });

      test('then the new deadline is broadcast and drawing is accepted again',
          () async {
        await start();
        final alice = drawers.first;
        final connection = await clients.connect(alice.id!);

        await endpoints.room.pauseGame(sessionBuilder, room.id!, hostId);
        await settle();
        await endpoints.room.resumeGame(sessionBuilder, room.id!, hostId);
        await settle();

        final playing = connection.stateChanges
            .where((m) => m.status == 'PLAYING')
            .last;
        expect(playing.endTime, isNotNull);

        await clients.draw(
          connection,
          alice.id!,
          'after-resume',
          insideRegion(alice),
        );
        expect(
          (await storedStrokes()).map((s) => s.strokeId),
          contains('after-resume'),
        );

        await connection.close();
      });

      test('then resuming a game that is not paused is refused', () async {
        expect(
          await endpoints.room.resumeGame(sessionBuilder, room.id!, hostId),
          isFalse,
        );
        await start();
        expect(
          await endpoints.room.resumeGame(sessionBuilder, room.id!, hostId),
          isFalse,
        );
        expect((await reload()).status, 'PLAYING');
      });

      test('then a call that fires against the later deadline reschedules '
          'rather than finalizing', () async {
        await start();
        final connection = await clients.connect(drawers.first.id!);
        await endpoints.room.pauseGame(sessionBuilder, room.id!, hostId);
        await endpoints.room.resumeGame(sessionBuilder, room.id!, hostId);
        await settle();

        await GameEndFutureCall().finalizeRoom(session, room.id!);
        await settle();

        expect((await reload()).status, 'PLAYING');
        expect(connection.composites, isEmpty);

        await connection.close();
      });
    });

    group('when the host stops early', () {
      test('then the broadcast order and the composite match an expired '
          'game', () async {
        await start();
        final alice = drawers.first;
        final connection = await clients.connect(alice.id!);
        await clients.draw(connection, alice.id!, 's1', insideRegion(alice));

        final atStop = await storedStrokes();
        expect(
          await endpoints.room.stopGame(sessionBuilder, room.id!, hostId),
          isTrue,
        );
        await settle();

        final finished = await reload();
        expect(finished.status, 'FINISHED');

        final stateChange = connection.stateChanges
            .where((m) => m.status == 'FINISHED')
            .single;
        expect(connection.composites, hasLength(1));
        // GameStateChangeMsg(FINISHED) lands before FinalCanvasMsg, exactly as
        // when the deadline expires.
        expect(
          connection.received.indexOf(stateChange),
          lessThan(connection.received.indexOf(connection.composites.single)),
        );
        expect(
          connection.composites.single.svg,
          composeCanvasSvg(
            room: finished,
            players: await endpoints.room.getPlayersInRoom(
              sessionBuilder,
              room.id!,
            ),
            strokes: atStop,
          ),
        );

        await connection.close();
      });

      test('then stopping a paused game finalizes it too', () async {
        await start();
        final connection = await clients.connect(drawers.first.id!);
        await endpoints.room.pauseGame(sessionBuilder, room.id!, hostId);
        await settle();

        expect(
          await endpoints.room.stopGame(sessionBuilder, room.id!, hostId),
          isTrue,
        );
        await settle();

        expect((await reload()).status, 'FINISHED');
        expect(connection.composites, hasLength(1));

        await connection.close();
      });

      test('then the original deadline passing afterwards changes nothing',
          () async {
        await start();
        final connection = await clients.connect(drawers.first.id!);
        await endpoints.room.stopGame(sessionBuilder, room.id!, hostId);
        await settle();

        // The cancelled call firing anyway, against a deadline that has since
        // passed: the room is FINISHED, so nothing further happens.
        await expireDeadline();
        await GameEndFutureCall().finalizeRoom(session, room.id!);
        await settle();

        expect((await reload()).status, 'FINISHED');
        expect(connection.composites, hasLength(1));
        expect(
          connection.stateChanges.where((m) => m.status == 'FINISHED'),
          hasLength(1),
        );

        await connection.close();
      });

      test('then stopping a game that is not running is refused', () async {
        expect(
          await endpoints.room.stopGame(sessionBuilder, room.id!, hostId),
          isFalse,
        );
        expect((await reload()).status, 'WAITING');

        await start();
        await endpoints.room.stopGame(sessionBuilder, room.id!, hostId);
        expect(
          await endpoints.room.stopGame(sessionBuilder, room.id!, hostId),
          isFalse,
        );
        expect((await reload()).status, 'FINISHED');
      });
    });
  });
}
