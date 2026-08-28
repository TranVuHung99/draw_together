import 'dart:ui';

import 'package:draw_together_flutter/models/stroke.dart';
import 'package:draw_together_flutter/providers/game_providers.dart';
import 'package:draw_together_serverpod_client/draw_together_serverpod_client.dart'
    hide Stroke;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the commit protocol for a player's own stroke: pending between
/// pen-up and the server's echoed `end`, confirmed by that echo carrying the
/// server's clamped points, and removed by a rejection, a retraction, or the
/// reset that precedes a replay.
///
/// Undo is checked here too, because the whole point of holding pending strokes
/// outside the board is that an undo can never name one.

const roomId = 1;
const aliceId = 2;
const bobId = 3;

/// Alice's region: the left half of the canvas.
final alice = Player(
  id: aliceId,
  roomId: roomId,
  name: 'alice',
  regionX: 0,
  regionY: 0,
  regionWidth: 0.5,
  regionHeight: 1,
);

Stroke localStroke(String id, List<Offset> points) => Stroke(
  id: id,
  playerId: aliceId,
  points: points,
  color: const Color(0xFFF44336),
  strokeWidth: 0.01,
  isEraser: false,
);

/// The `end` message the server echoes back, carrying its own clamped points.
StrokeSyncMsg serverEnd(
  String strokeId, {
  int playerId = aliceId,
  required List<double> points,
  String colorInfo = '0xFFF44336',
  double strokeWidth = 0.01,
  bool isEraser = false,
}) => StrokeSyncMsg(
  roomId: roomId,
  playerId: playerId,
  strokeId: strokeId,
  action: 'end',
  points: points,
  colorInfo: colorInfo,
  strokeWidth: strokeWidth,
  isEraser: isEraser,
  timestamp: DateTime.now(),
);

/// A container holding a room mid-game with alice as the local player.
ProviderContainer containerForAlice() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(currentPlayerProvider.notifier).set(alice);
  container.read(playersProvider.notifier).set([alice]);
  container.read(connectionStatusProvider.notifier).set(
    ConnectionStatus.connected,
  );
  return container;
}

void main() {
  group('Given a stroke that has just been finished', () {
    test('when the end has been sent then the stroke is pending and not in '
        'the board', () {
      final container = containerForAlice();
      container.read(pendingStrokesProvider.notifier).add(
        localStroke('s1', const [Offset(0.1, 0.1), Offset(0.2, 0.2)]),
      );

      expect(container.read(pendingStrokesProvider).keys, ['s1']);
      expect(container.read(strokesProvider).length, 0);
      // Not offered as the player's latest stroke either, which is what keeps
      // it from becoming an undo target.
      expect(container.read(undoableStrokeProvider), isNull);
    });

    test('when a second stroke begins before the first is confirmed then both '
        'are held', () {
      final container = containerForAlice();
      final pending = container.read(pendingStrokesProvider.notifier);
      pending.add(localStroke('s1', const [Offset(0.1, 0.1)]));
      pending.add(localStroke('s2', const [Offset(0.2, 0.2)]));

      // Insertion order is send order, which is the order they are painted in.
      expect(container.read(pendingStrokesProvider).keys, ['s1', 's2']);
    });

    test('when the undo control is asked for then it is unavailable', () {
      final container = containerForAlice();
      // An earlier confirmed stroke exists, so "nothing to undo" is not what
      // is being measured here.
      container.read(strokesProvider.notifier).handleStrokeSync(
        serverEnd('confirmed', points: const [0.1, 0.1, 0.2, 0.2]),
      );
      expect(container.read(canUndoProvider), isTrue);

      container.read(pendingStrokesProvider.notifier).add(
        localStroke('s1', const [Offset(0.3, 0.3)]),
      );
      expect(container.read(canUndoProvider), isFalse);
    });

    test('when a stroke is under the pen then undo is unavailable', () {
      final container = containerForAlice();
      container.read(strokesProvider.notifier).handleStrokeSync(
        serverEnd('confirmed', points: const [0.1, 0.1, 0.2, 0.2]),
      );
      container.read(strokeInProgressProvider.notifier).set(true);
      expect(container.read(canUndoProvider), isFalse);
    });
  });

  group('Given the server confirms the stroke', () {
    test('when the echoed end arrives then the stroke moves into the board '
        'exactly once', () {
      final container = containerForAlice();
      container.read(pendingStrokesProvider.notifier).add(
        localStroke('s1', const [Offset(0.1, 0.1), Offset(0.2, 0.2)]),
      );

      container.read(strokesProvider.notifier).handleStrokeSync(
        serverEnd('s1', points: const [0.1, 0.1, 0.2, 0.2]),
      );

      expect(container.read(pendingStrokesProvider), isEmpty);
      expect(container.read(strokesProvider).strokesOf(aliceId).length, 1);
      expect(container.read(undoableStrokeProvider)?.id, 's1');
    });

    test('when the server clamped the points differently then the board takes '
        'the server geometry', () {
      final container = containerForAlice();
      // The client clamped to a stale region and let the stroke run past x=0.5;
      // the server clamped it to the region it actually assigned.
      container.read(pendingStrokesProvider.notifier).add(
        localStroke('s1', const [Offset(0.1, 0.1), Offset(0.9, 0.1)]),
      );

      container.read(strokesProvider.notifier).handleStrokeSync(
        serverEnd('s1', points: const [0.1, 0.1, 0.5, 0.1]),
      );

      final stored = container.read(strokesProvider).findById(aliceId, 's1');
      expect(stored?.points, const [Offset(0.1, 0.1), Offset(0.5, 0.1)]);
      expect(container.read(pendingStrokesProvider), isEmpty);
    });

    test('when the confirmation arrives then undo becomes available and '
        'targets it', () {
      final container = containerForAlice();
      container.read(pendingStrokesProvider.notifier).add(
        localStroke('s1', const [Offset(0.1, 0.1)]),
      );
      expect(container.read(canUndoProvider), isFalse);

      container.read(strokesProvider.notifier).handleStrokeSync(
        serverEnd('s1', points: const [0.1, 0.1]),
      );

      expect(container.read(canUndoProvider), isTrue);
      expect(container.read(undoableStrokeProvider)?.id, 's1');
    });

    test('when another player completes a stroke then nothing local is '
        'disturbed', () {
      final container = containerForAlice();
      container.read(pendingStrokesProvider.notifier).add(
        localStroke('mine', const [Offset(0.1, 0.1)]),
      );

      container.read(strokesProvider.notifier).handleStrokeSync(
        serverEnd('theirs', playerId: bobId, points: const [0.6, 0.1, 0.7, 0.1]),
      );

      expect(container.read(pendingStrokesProvider).keys, ['mine']);
      expect(container.read(strokesProvider).strokesOf(bobId).length, 1);
    });
  });

  group('Given the server refuses the stroke', () {
    test('when a rejection arrives then the stroke leaves the pending state',
        () {
      final container = containerForAlice();
      container.read(pendingStrokesProvider.notifier).add(
        localStroke('s1', const [Offset(0.1, 0.1)]),
      );

      // What `websocket_service` does on a `StrokeRejectedMsg`.
      container.read(pendingStrokesProvider.notifier).remove('s1');
      container.read(strokeRejectionProvider.notifier).set(
        const StrokeRejection(strokeId: 's1', reason: 'NOT_PLAYING'),
      );

      expect(container.read(pendingStrokesProvider), isEmpty);
      expect(container.read(strokesProvider).length, 0);
    });

    test('when the reason is NOT_PLAYING then the player is told the game is '
        'not running', () {
      expect(
        const StrokeRejection(strokeId: 's1', reason: 'NOT_PLAYING').message,
        contains('not running'),
      );
    });

    test('when each reason is surfaced then it says something true', () {
      expect(
        const StrokeRejection(strokeId: 's1', reason: 'NO_REGION').message,
        contains('region'),
      );
      expect(
        const StrokeRejection(strokeId: 's1', reason: 'NOT_OWNER').message,
        contains('another player'),
      );
      // The retraction has already taken the stroke off this canvas, so a
      // second notice would explain the same event twice.
      expect(
        const StrokeRejection(strokeId: 's1', reason: 'ABANDONED').message,
        isNull,
      );
    });

    test('when a rejection leaves an earlier confirmed stroke then undo '
        'targets that one', () {
      final container = containerForAlice();
      container.read(strokesProvider.notifier).handleStrokeSync(
        serverEnd('older', points: const [0.1, 0.1]),
      );
      container.read(pendingStrokesProvider.notifier).add(
        localStroke('refused', const [Offset(0.2, 0.2)]),
      );
      expect(container.read(canUndoProvider), isFalse);

      container.read(pendingStrokesProvider.notifier).remove('refused');

      expect(container.read(canUndoProvider), isTrue);
      expect(container.read(undoableStrokeProvider)?.id, 'older');
    });
  });

  group('Given the server retracts a stroke', () {
    test('when the retraction names a pending stroke then it is removed', () {
      final container = containerForAlice();
      container.read(pendingStrokesProvider.notifier).add(
        localStroke('s1', const [Offset(0.1, 0.1)]),
      );

      container.read(strokesProvider.notifier).handleUndo(
        StrokeUndoMsg(roomId: roomId, playerId: aliceId, strokeId: 's1'),
      );

      expect(container.read(pendingStrokesProvider), isEmpty);
      expect(container.read(strokesProvider).length, 0);
    });

    test('when the retraction names a confirmed stroke then it leaves the '
        'board', () {
      final container = containerForAlice();
      container.read(strokesProvider.notifier).handleStrokeSync(
        serverEnd('s1', points: const [0.1, 0.1]),
      );

      container.read(strokesProvider.notifier).handleUndo(
        StrokeUndoMsg(roomId: roomId, playerId: aliceId, strokeId: 's1'),
      );

      expect(container.read(strokesProvider).length, 0);
      expect(container.read(undoableStrokeProvider), isNull);
    });

    test('when the retraction names a stroke this client never had then '
        'nothing happens', () {
      final container = containerForAlice();
      container.read(strokesProvider.notifier).handleStrokeSync(
        serverEnd('mine', points: const [0.1, 0.1]),
      );

      container.read(strokesProvider.notifier).handleUndo(
        StrokeUndoMsg(roomId: roomId, playerId: bobId, strokeId: 'unknown'),
      );

      expect(container.read(strokesProvider).strokesOf(aliceId).length, 1);
    });

    test('when repeated undos arrive then they walk backwards through the '
        "player's own strokes", () {
      final container = containerForAlice();
      final strokes = container.read(strokesProvider.notifier);
      for (final id in ['first', 'second', 'third']) {
        strokes.handleStrokeSync(serverEnd(id, points: const [0.1, 0.1]));
      }
      // A stroke of bob's, which no undo of alice's may touch.
      strokes.handleStrokeSync(
        serverEnd('bobs', playerId: bobId, points: const [0.6, 0.1]),
      );

      final undone = <String>[];
      for (var i = 0; i < 3; i++) {
        final target = container.read(undoableStrokeProvider)!;
        undone.add(target.id);
        strokes.handleUndo(
          StrokeUndoMsg(
            roomId: roomId,
            playerId: aliceId,
            strokeId: target.id,
          ),
        );
      }

      expect(undone, ['third', 'second', 'first']);
      expect(container.read(undoableStrokeProvider), isNull);
      expect(container.read(strokesProvider).strokesOf(bobId).length, 1);
    });
  });

  group('Given the client reconnects', () {
    test('when the canvas is reset then an unconfirmed stroke does not survive',
        () {
      final container = containerForAlice();
      container.read(strokesProvider.notifier).handleStrokeSync(
        serverEnd('persisted', points: const [0.1, 0.1]),
      );
      container.read(pendingStrokesProvider.notifier).add(
        localStroke('lost', const [Offset(0.2, 0.2)]),
      );

      // What `WebSocketService` does before re-sending `RoomSubscribeMsg`.
      container.read(strokesProvider.notifier).clear();
      container.read(pendingStrokesProvider.notifier).clear();

      expect(container.read(strokesProvider).length, 0);
      expect(container.read(pendingStrokesProvider), isEmpty);

      // The replay is the whole truth: only what the server holds comes back.
      container.read(strokesProvider.notifier).handleStrokeSync(
        serverEnd('persisted', points: const [0.1, 0.1]),
      );

      expect(container.read(strokesProvider).length, 1);
      expect(container.read(strokesProvider).findById(aliceId, 'lost'), isNull);
    });

    test('when the client held a stroke the server never accepted then the '
        'replay removes it', () {
      final container = containerForAlice();
      // An orphan: a stroke in the board with no row behind it. A replay merged
      // into local state could never delete it, because `upsert` only ever adds
      // or replaces.
      container.read(strokesProvider.notifier).handleStrokeSync(
        serverEnd('orphan', points: const [0.1, 0.1]),
      );

      container.read(strokesProvider.notifier).clear();
      container.read(pendingStrokesProvider.notifier).clear();
      container.read(strokesProvider.notifier).handleStrokeSync(
        serverEnd('real', points: const [0.3, 0.3]),
      );

      expect(container.read(strokesProvider).length, 1);
      expect(container.read(strokesProvider).findById(aliceId, 'orphan'), isNull);
    });
  });
}
