import 'package:draw_together_flutter/providers/game_providers.dart';
import 'package:draw_together_serverpod_client/draw_together_serverpod_client.dart'
    hide Stroke;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies when drawing input is accepted. The same derivation hides the
/// toolbar in `game_screen.dart`, so a canvas that refuses input has no tools
/// on show either.

const hostId = 1;
const aliceId = 2;

Room roomWith(String status) => Room(
  id: 1,
  roomCode: 'TEST01',
  hostId: hostId,
  status: status,
  canvasWidth: 1000,
  canvasHeight: 1000,
  endTime: DateTime.now().add(const Duration(seconds: 30)),
);

/// A drawing player, with the region the server assigned at start.
final alice = Player(
  id: aliceId,
  roomId: 1,
  name: 'alice',
  regionX: 0,
  regionY: 0,
  regionWidth: 0.5,
  regionHeight: 1,
);

/// The host observes and controls, and so never holds a region.
final host = Player(id: hostId, roomId: 1, name: 'host');

bool canDraw({
  required String status,
  required Player player,
  bool spectating = false,
  ConnectionStatus connection = ConnectionStatus.connected,
}) {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(roomProvider.notifier).set(roomWith(status));
  container.read(currentPlayerProvider.notifier).set(player);
  container.read(viewGlobalCanvasProvider.notifier).set(spectating);
  container.read(connectionStatusProvider.notifier).set(connection);
  return container.read(canDrawProvider);
}

void main() {
  test('when the game is playing then a drawing player in draw mode may draw',
      () {
    expect(canDraw(status: 'PLAYING', player: alice), isTrue);
  });

  test('when the game is finished then the canvas is locked in either view '
      'mode', () {
    expect(canDraw(status: 'FINISHED', player: alice), isFalse);
    expect(
      canDraw(status: 'FINISHED', player: alice, spectating: true),
      isFalse,
    );
  });

  test('when the game has not started then no one may draw', () {
    expect(canDraw(status: 'WAITING', player: alice), isFalse);
  });

  test('when the player is spectating then input is refused', () {
    expect(canDraw(status: 'PLAYING', player: alice, spectating: true), isFalse);
  });

  test('when the game is paused then the canvas is locked in either view mode',
      () {
    // The server refuses writes outside PLAYING too; this is the
    // presentational half of the same rule, and it is what hides the toolbar.
    expect(canDraw(status: 'PAUSED', player: alice), isFalse);
    expect(canDraw(status: 'PAUSED', player: alice, spectating: true), isFalse);
  });

  test('when the player is the host then input is refused throughout', () {
    for (final status in ['WAITING', 'PLAYING', 'PAUSED', 'FINISHED']) {
      expect(canDraw(status: status, player: host), isFalse, reason: status);
    }
  });

  test('when there is no connection then input is refused even while playing',
      () {
    // `sendMessage` drops a message on a closed controller without a word,
    // which is one of the ways strokes went missing, so input is refused up
    // front instead.
    for (final connection in [
      ConnectionStatus.reconnecting,
      ConnectionStatus.disconnected,
    ]) {
      expect(
        canDraw(status: 'PLAYING', player: alice, connection: connection),
        isFalse,
        reason: connection.name,
      );
    }
  });

  test('when nothing has connected yet then input is refused', () {
    // Nothing is connected before `WebSocketService.connect` runs, so the
    // default must not be an optimistic guess.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(roomProvider.notifier).set(roomWith('PLAYING'));
    container.read(currentPlayerProvider.notifier).set(alice);
    expect(container.read(canDrawProvider), isFalse);
  });

  test('when the connection is re-established then input is accepted again',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(roomProvider.notifier).set(roomWith('PLAYING'));
    container.read(currentPlayerProvider.notifier).set(alice);

    final status = container.read(connectionStatusProvider.notifier);
    status.set(ConnectionStatus.reconnecting);
    expect(container.read(canDrawProvider), isFalse);
    status.set(ConnectionStatus.connected);
    expect(container.read(canDrawProvider), isTrue);
  });

  group('Given a countdown', () {
    Room room({
      required String status,
      Duration? until,
      int? remainingMs,
    }) => Room(
      id: 1,
      roomCode: 'TEST01',
      hostId: hostId,
      status: status,
      canvasWidth: 1000,
      canvasHeight: 1000,
      endTime: until == null ? null : DateTime.now().add(until),
      remainingMs: remainingMs,
    );

    test('when the room is playing then it tracks the server deadline', () {
      expect(
        remainingSeconds(room(status: 'PLAYING', until: const Duration(seconds: 42))),
        closeTo(42, 1),
      );
    });

    test('when the room is paused then it reads the banked remainder and '
        'ignores any deadline', () {
      // The server clears endTime on pause; a client holding a stale one must
      // not count down to it.
      expect(
        remainingSeconds(
          room(
            status: 'PAUSED',
            until: const Duration(seconds: 5),
            remainingMs: 42000,
          ),
        ),
        42,
      );
    });

    test('when the room is paused then the value does not move with the clock',
        () async {
      final paused = room(status: 'PAUSED', remainingMs: 42000);
      final first = remainingSeconds(paused);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(remainingSeconds(paused), first);
      expect(first, 42);
    });

    test('when there is neither a deadline nor a remainder then there is no '
        'countdown', () {
      expect(remainingSeconds(room(status: 'WAITING')), isNull);
      expect(remainingSeconds(room(status: 'PAUSED')), isNull);
      expect(remainingSeconds(null), isNull);
    });

    test('when a deadline has already passed then it reads zero rather than '
        'a negative', () {
      expect(
        remainingSeconds(
          room(status: 'PLAYING', until: const Duration(seconds: -5)),
        ),
        0,
      );
    });
  });
}
