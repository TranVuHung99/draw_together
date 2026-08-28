import 'package:draw_together_serverpod_server/src/composition/canvas_svg.dart';
import 'package:draw_together_serverpod_server/src/future_calls/game_end_future_call.dart';
import 'package:draw_together_serverpod_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'streaming_harness.dart';
import 'test_tools/serverpod_test_tools.dart';

/// Drives a whole game through the real endpoints — lobby, start, three clients
/// drawing, undo, and the server's own deadline — rather than reaching into the
/// database to set the scene. What each client received over its stream is the
/// same thing a browser window would have painted.
void main() {
  withServerpod('Given a game played by three drawers', (
    sessionBuilder,
    endpoints,
  ) {
    late Session session;
    late RoomClients clients;
    late Room room;
    late Player host;
    late List<Player> drawers;

    /// A short stroke inside [player]'s own region, wherever the partition put
    /// it, so nothing is clamped.
    List<double> insideRegion(Player player) {
      final centreX = player.regionX! + player.regionWidth! / 2;
      final centreY = player.regionY! + player.regionHeight! / 2;
      return [centreX - 0.02, centreY, centreX + 0.02, centreY];
    }

    Future<List<Stroke>> storedStrokes() => Stroke.db.find(
      session,
      where: (s) => s.roomId.equals(room.id!),
      orderBy: (s) => s.sequence,
    );

    /// Moves the room's deadline into the past, which is the state the
    /// scheduled call finds when it fires on time. The room row is the
    /// authority on whether the clock has run out, so a call arriving against
    /// a deadline still in the future reschedules rather than finalizing.
    Future<void> expireDeadline() async {
      final current = (await Room.db.findById(session, room.id!))!;
      await Room.db.updateRow(
        session,
        current.copyWith(
          endTime: DateTime.now().subtract(const Duration(seconds: 1)),
        ),
      );
    }

    setUp(() async {
      session = sessionBuilder.build();

      room = (await endpoints.room.createRoom(
        sessionBuilder,
        'host',
        1000,
        1000,
      ))!;

      for (final name in ['alice', 'bob', 'carol']) {
        expect(
          await endpoints.room.joinRoom(sessionBuilder, room.roomCode, name),
          isNotNull,
          reason: '$name joined while the room was still waiting',
        );
      }

      expect(
        await endpoints.room.startGame(
          sessionBuilder,
          room.id!,
          room.hostId,
          60,
        ),
        isTrue,
      );

      room = (await endpoints.room.getRoom(sessionBuilder, room.id!))!;
      final players = await endpoints.room.getPlayersInRoom(
        sessionBuilder,
        room.id!,
      );
      host = players.firstWhere((p) => p.id == room.hostId);
      drawers = players.where((p) => p.id != room.hostId).toList();

      clients = RoomClients(endpoints, sessionBuilder, room.id!);
    });

    test('when the lobby fills and the game starts then only the drawers get '
        'regions and no one else can join', () async {
      expect(room.status, 'PLAYING');
      expect(room.endTime, isNotNull);
      expect(drawers, hasLength(3));
      // The host observes and controls, so it never gets a region.
      expect(host.regionX, isNull);
      expect(host.regionWidth, isNull);
      for (final drawer in drawers) {
        expect(drawer.regionWidth, isNotNull, reason: drawer.name);
        expect(drawer.regionHeight, isNotNull, reason: drawer.name);
      }

      // A fourth window opening now is turned away: the room is PLAYING.
      expect(
        await endpoints.room.joinRoom(sessionBuilder, room.roomCode, 'late'),
        isNull,
      );
    });

    test('when each drawer draws then every other client receives it and it is '
        'persisted once', () async {
      final connections = <int, StreamConnection>{
        for (final drawer in drawers) drawer.id!: await clients.connect(drawer.id!),
      };
      final hostConnection = await clients.connect(host.id!);

      for (final drawer in drawers) {
        await clients.draw(
          connections[drawer.id!]!,
          drawer.id!,
          'stroke-${drawer.id}',
          insideRegion(drawer),
          colorInfo: drawer.colorInfo ?? '0xFF000000',
        );
      }

      // Every stroke landed exactly once, in the order they were drawn.
      final stored = await storedStrokes();
      expect(
        stored.map((s) => s.strokeId),
        drawers.map((d) => 'stroke-${d.id}'),
      );
      expect(stored.map((s) => s.points), drawers.map(insideRegion));

      // Each drawer sees all three completed strokes, their own included: the
      // echoed `end` carries the server's clamped copy and is what confirms it.
      // Only their own in-progress batches are held back, so their own stroke
      // arrives once where the others arrive twice.
      for (final drawer in drawers) {
        final received = connections[drawer.id!]!.strokes;
        expect(
          received.map((s) => s.strokeId).toSet(),
          drawers.map((other) => 'stroke-${other.id}').toSet(),
          reason: 'as seen by ${drawer.name}',
        );
        final own = received.where((s) => s.strokeId == 'stroke-${drawer.id}');
        expect(
          own.map((s) => s.action),
          ['end'],
          reason: '${drawer.name} receives only the end of their own stroke',
        );
        expect(
          own.single.points,
          insideRegion(drawer),
          reason: "${drawer.name}'s confirmation carries the server's points",
        );
      }

      // The host draws nothing, so nothing is suppressed for it.
      expect(
        hostConnection.strokes.map((s) => s.strokeId).toSet(),
        drawers.map((d) => 'stroke-${d.id}').toSet(),
      );

      for (final connection in connections.values) {
        await connection.close();
      }
      await hostConnection.close();
    });

    test('when the host reloads mid-game then its observer view is replayed in '
        'full', () async {
      final connections = <int, StreamConnection>{};
      for (final drawer in drawers) {
        final connection = await clients.connect(drawer.id!);
        connections[drawer.id!] = connection;
        await clients.draw(
          connection,
          drawer.id!,
          'stroke-${drawer.id}',
          insideRegion(drawer),
        );
      }

      // The host closing its window and coming back is a fresh subscribe.
      final reloaded = await clients.connect(host.id!);
      expect(
        reloaded.strokes.map((s) => s.strokeId),
        drawers.map((d) => 'stroke-${d.id}'),
      );
      expect(reloaded.strokes.every((s) => s.action == 'end'), isTrue);
      expect(
        reloaded.strokes.map((s) => s.points),
        drawers.map(insideRegion),
      );

      await reloaded.close();
      for (final connection in connections.values) {
        await connection.close();
      }
    });

    test('when a player undoes repeatedly then their own strokes go in reverse '
        'order and no one else\'s move', () async {
      final alice = drawers.first;
      final bob = drawers[1];
      final aliceConnection = await clients.connect(alice.id!);
      final bobConnection = await clients.connect(bob.id!);

      for (final index in [1, 2, 3]) {
        await clients.draw(
          aliceConnection,
          alice.id!,
          'a$index',
          insideRegion(alice),
        );
      }
      await clients.draw(bobConnection, bob.id!, 'b1', insideRegion(bob));

      for (final expected in ['a3', 'a2', 'a1']) {
        await clients.undo(aliceConnection, alice.id!, expected);
      }

      // Only Bob's stroke is left, and both clients were told about each
      // removal, newest first.
      expect((await storedStrokes()).map((s) => s.strokeId), ['b1']);
      expect(aliceConnection.undos.map((u) => u.strokeId), [
        'a3',
        'a2',
        'a1',
      ]);
      expect(bobConnection.undos.map((u) => u.strokeId), ['a3', 'a2', 'a1']);

      await aliceConnection.close();
      await bobConnection.close();
    });

    test('when the deadline passes with the host gone then the game still '
        'finalizes and the composite matches the persisted canvas', () async {
      final connections = <int, StreamConnection>{};
      for (final drawer in drawers) {
        final connection = await clients.connect(drawer.id!);
        connections[drawer.id!] = connection;
        await clients.draw(
          connection,
          drawer.id!,
          'stroke-${drawer.id}',
          insideRegion(drawer),
        );
      }

      // The host was connected and then closed its window before the deadline.
      final hostConnection = await clients.connect(host.id!);
      await hostConnection.close();

      final atDeadline = await storedStrokes();
      await expireDeadline();
      await GameEndFutureCall().finalizeRoom(session, room.id!);
      await settle();

      expect(
        (await endpoints.room.getRoom(sessionBuilder, room.id!))!.status,
        'FINISHED',
      );

      final expectedSvg = composeCanvasSvg(
        room: (await endpoints.room.getRoom(sessionBuilder, room.id!))!,
        players: await endpoints.room.getPlayersInRoom(
          sessionBuilder,
          room.id!,
        ),
        strokes: atDeadline,
      );

      for (final drawer in drawers) {
        final connection = connections[drawer.id!]!;
        final finished = connection.stateChanges
            .where((m) => m.status == 'FINISHED')
            .toList();
        expect(finished, hasLength(1), reason: drawer.name);
        expect(connection.composites, hasLength(1), reason: drawer.name);
        // The status lands before the composite, so no client is still
        // accepting input when the picture arrives.
        expect(
          connection.received.indexOf(finished.single),
          lessThan(connection.received.indexOf(connection.composites.single)),
          reason: drawer.name,
        );
        // The composite is the canvas as it stood at the deadline.
        expect(connection.composites.single.svg, expectedSvg);
      }

      // And the canvas is closed: nothing drawn or undone after the deadline
      // changes it.
      final alice = drawers.first;
      await clients.draw(
        connections[alice.id!]!,
        alice.id!,
        'too-late',
        insideRegion(alice),
      );
      await clients.undo(connections[alice.id!]!, alice.id!, 'stroke-${alice.id}');
      expect(
        (await storedStrokes()).map((s) => s.strokeId),
        atDeadline.map((s) => s.strokeId),
      );

      for (final connection in connections.values) {
        await connection.close();
      }
    });

    test('when a room is finalized twice then the composite is published '
        'once', () async {
      final connection = await clients.connect(drawers.first.id!);

      await expireDeadline();
      await GameEndFutureCall().finalizeRoom(session, room.id!);
      await settle();
      await GameEndFutureCall().finalizeRoom(session, room.id!);
      await settle();

      expect(connection.composites, hasLength(1));
      await connection.close();
    });
  });
}
