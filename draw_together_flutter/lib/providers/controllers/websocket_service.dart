import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/serverpod_client.dart';
import 'package:draw_together_serverpod_client/draw_together_serverpod_client.dart';
import '../game_providers.dart';
import 'target_image_controller.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

/// The first backoff interval, doubling from here.
const Duration _initialRetryDelay = Duration(milliseconds: 500);

/// The cap on the backoff, so a server outage does not become a retry storm
/// and does not become a client that has given up either.
const Duration _maxRetryDelay = Duration(seconds: 8);

/// How many times a roster refresh is attempted before the failure is shown to
/// the player.
const int _rosterAttempts = 3;

/// The wait between roster attempts, multiplied by the attempt number.
const Duration _rosterRetryDelay = Duration(milliseconds: 400);

/// This client's end of the streaming connection.
///
/// Holds one attempt at a time: an outgoing controller, a subscription to what
/// the server sends back, and — when the stream ends — a timer for the next
/// attempt. The room and player it is subscribed as outlive any single attempt,
/// which is what a reconnect is reconstructed from.
class WebSocketService {
  final Ref ref;

  /// The room this client is in and the identity it subscribes as. Both are
  /// non-null exactly while reconnecting should be attempted.
  int? _roomId;
  int? _playerId;

  /// The current attempt's outgoing controller.
  ///
  /// Deliberately single-subscription, not a broadcast controller. The
  /// Serverpod client only attaches its listener after the websocket handshake
  /// and the open-stream round trip have both completed, which is well after
  /// the first `RoomSubscribeMsg` is added. A broadcast controller drops events
  /// that arrive with no listener attached, which silently discarded the
  /// subscribe message and left the connection subscribed to no room at all. A
  /// single-subscription controller buffers until the client listens.
  ///
  /// A closed controller cannot be reused, so this is per-attempt state rather
  /// than per-service state.
  StreamController<SerializableModel>? _outgoing;
  StreamSubscription<SerializableModel>? _incomingSubscription;

  Timer? _retryTimer;

  /// How many attempts have failed in a row, which is what the backoff grows
  /// with. Reset by a fresh `connect`.
  int _failedAttempts = 0;

  /// Sequences roster refreshes, so only the newest may write.
  ///
  /// Two refreshes are routinely in flight at once — the one on entering the
  /// room and the one a `PLAYER_JOINED` triggers — and their responses can land
  /// in either order. Without this, a slow older response overwrites a newer
  /// one and reverts the roster to a snapshot taken before the player it is
  /// missing had joined: the join is delivered and applied, and then silently
  /// undone. The retry loop below widens that window to seconds.
  int _rosterGeneration = 0;

  bool _disposed = false;

  WebSocketService(this.ref);

  /// Enters a room: opens the stream and keeps it open for as long as the
  /// client stays.
  Future<void> connect(int roomId, int playerId) async {
    _roomId = roomId;
    _playerId = playerId;
    _failedAttempts = 0;
    _retryTimer?.cancel();
    _closeAttempt();
    _open();
  }

  /// Leaves the room. No further attempt is made, which is the difference
  /// between a dropped connection and a departure.
  void disconnect() {
    _roomId = null;
    _playerId = null;
    _retryTimer?.cancel();
    _closeAttempt();
    _setStatus(ConnectionStatus.disconnected);
  }

  void _open() {
    final roomId = _roomId;
    final playerId = _playerId;
    if (_disposed || roomId == null || playerId == null) return;

    final outgoing = StreamController<SerializableModel>();
    _outgoing = outgoing;

    _incomingSubscription = client.gameStreaming
        .live(outgoing.stream)
        .listen(
          _handleIncomingMessage,
          onDone: () => _handleStreamEnded(outgoing, null),
          onError: (Object error, StackTrace stackTrace) =>
              _handleStreamEnded(outgoing, error),
          cancelOnError: false,
        );

    // The replay that follows is the whole truth, so everything held locally
    // goes first. The board can contain strokes the server never accepted, and
    // `StrokeBoard.upsert` can add or replace a stroke but never remove one, so
    // a replay merged into stale state could not delete them. An unconfirmed
    // stroke is dropped rather than re-sent: losing one to a dead socket is an
    // acceptable outcome, believing you still have it is not.
    ref.read(strokesProvider.notifier).clear();
    ref.read(pendingStrokesProvider.notifier).clear();

    // Optimistic: the stream carries no "open" event, so a connection counts as
    // up from the moment it is opened and comes down when it ends or errors. A
    // failed attempt corrects this within a round trip.
    _setStatus(ConnectionStatus.connected);

    // The playerId is what lets the server keep this client's own in-progress
    // strokes from being echoed back to it, and what it verifies a stroke's
    // claimed author against.
    debugPrint('Subscribing to room $roomId as player $playerId');
    outgoing.add(RoomSubscribeMsg(roomId: roomId, playerId: playerId));
  }

  /// The stream ended, by completion or by error. Schedules the next attempt
  /// while the client is still in a room.
  void _handleStreamEnded(
    StreamController<SerializableModel> attempt,
    Object? error,
  ) {
    // A late event from a superseded attempt must not disturb the live one, and
    // an error followed by a done must not schedule two retries.
    if (!identical(_outgoing, attempt)) return;
    if (error != null) debugPrint('Streaming connection failed: $error');

    _closeAttempt();

    if (_disposed || _roomId == null) {
      _setStatus(ConnectionStatus.disconnected);
      return;
    }

    _setStatus(ConnectionStatus.reconnecting);
    _scheduleRetry();
  }

  /// Exponential backoff with jitter: 500 ms doubling to a cap of 8 s, each
  /// wait a random point in the upper half of its interval so that a room full
  /// of clients does not retry in lockstep.
  void _scheduleRetry() {
    final capped = min(
      _initialRetryDelay.inMilliseconds * (1 << min(_failedAttempts, 4)),
      _maxRetryDelay.inMilliseconds,
    );
    final half = capped ~/ 2;
    final delay = half + Random().nextInt(half + 1);
    _failedAttempts++;

    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(milliseconds: delay), _open);
  }

  /// Tears down the current attempt, leaving the room and player intact.
  void _closeAttempt() {
    _incomingSubscription?.cancel();
    _incomingSubscription = null;
    final outgoing = _outgoing;
    _outgoing = null;
    outgoing?.close();
  }

  void _setStatus(ConnectionStatus status) {
    if (_disposed) return;
    ref.read(connectionStatusProvider.notifier).set(status);
  }

  void _handleIncomingMessage(SerializableModel message) {
    if (message is StrokeSyncMsg) {
      // An `end` naming the local player is that stroke's confirmation: the
      // server's clamped copy enters the board and the pending copy is
      // dropped. Handled in one place because a confirmed own stroke, a remote
      // stroke and a replayed one are the same message.
      ref.read(strokesProvider.notifier).handleStrokeSync(message);
    } else if (message is StrokeRejectedMsg) {
      // Addressed to this client alone: the server writes it to this stream
      // rather than the room channel, so nobody else learns the stroke was
      // refused.
      ref.read(pendingStrokesProvider.notifier).remove(message.strokeId);
      ref
          .read(strokeRejectionProvider.notifier)
          .set(
            StrokeRejection(strokeId: message.strokeId, reason: message.reason),
          );
    } else if (message is StrokeUndoMsg) {
      // The server confirms every undo, including the local player's own, and
      // uses the same message to retract a stroke it has abandoned, so this is
      // the only place a stroke is removed.
      ref.read(strokesProvider.notifier).handleUndo(message);
    } else if (message is GameStateChangeMsg) {
      // A change in room game state or new player joined

      // Update Room status
      final room = ref.read(roomProvider);
      if (room == null || room.id != message.roomId) {
        // Dropping this silently is how a client sits in a lobby that has
        // already started: the message arrived and was discarded because the
        // local room was missing or was some other room.
        debugPrint(
          'Dropped ${message.status} for room ${message.roomId}: '
          'local room is ${room?.id}',
        );
        return;
      }

      if (message.status == 'PLAYER_JOINED') {
        // A signal to reload the roster rather than a room status. The server
        // sends one on subscribe too, from a point where it cannot race the
        // client's own view of who is in the room.
        refreshPlayers(message.roomId);
      } else {
        // `endTime` and `remainingMs` are each other's opposite — the server
        // clears one as it sets the other — so both are applied from every
        // change rather than only the one the new status happens to use.
        ref
            .read(roomProvider.notifier)
            .set(
              room.copyWith(
                status: message.status,
                endTime: message.endTime,
                remainingMs: message.remainingMs,
              ),
            );
        if (message.status == 'PLAYING') {
          // Regions are assigned as the game starts, so the local player and
          // the roster are both stale from this moment.
          refreshPlayers(message.roomId);
          // The crop is cut from the same regions, so it is fetched here
          // too. A client that never sees this message fetches it on
          // entering the game screen instead.
          ref.read(targetImageControllerProvider).load();
        }
      }
    } else if (message is FinalCanvasMsg) {
      ref.read(finalCanvasSvgProvider.notifier).set(message.svg);
      // Ensure local room state reflects finished
      final room = ref.read(roomProvider);
      if (room != null) {
        ref.read(roomProvider.notifier).set(room.copyWith(status: 'FINISHED'));
      }
    }
  }

  void sendMessage(SerializableModel msg) {
    final outgoing = _outgoing;
    if (outgoing == null || outgoing.isClosed) return;
    outgoing.add(msg);
  }

  /// Refreshes the roster, retrying a bounded number of times before telling
  /// the player it could not be done.
  ///
  /// A refresh that fails silently is how a client ends up locked out of
  /// drawing: it holds no region, so `canDrawProvider` closes the canvas and
  /// nothing on screen explains why. Worse, it may hold a *stale* region and
  /// clamp to a rectangle the server no longer agrees with.
  ///
  /// A superseded refresh abandons its result rather than writing it. This is
  /// the only writer to the roster that can have several calls in flight, and
  /// an older response landing last is how a joined player disappears again —
  /// or, once the game starts, how a client ends up holding a roster with no
  /// regions in it and a canvas that will not accept input.
  Future<void> refreshPlayers(int roomId) async {
    final generation = ++_rosterGeneration;
    bool superseded() => _disposed || generation != _rosterGeneration;

    for (var attempt = 1; attempt <= _rosterAttempts; attempt++) {
      if (superseded()) return;
      try {
        final players = await client.room.getPlayersInRoom(roomId);
        if (superseded()) return;
        ref.read(playersProvider.notifier).set(players);

        // Keep the local player in step with the roster, so its region is not
        // read from a stale copy.
        final current = ref.read(currentPlayerProvider);
        if (current != null) {
          final updated = players.firstWhere(
            (p) => p.id == current.id,
            orElse: () => current,
          );
          ref.read(currentPlayerProvider.notifier).set(updated);
        }
        ref.read(rosterRefreshFailedProvider.notifier).set(false);
        return;
      } catch (e) {
        debugPrint('Error fetching players (attempt $attempt): $e');
        if (attempt < _rosterAttempts) {
          await Future<void>.delayed(_rosterRetryDelay * attempt);
        }
      }
    }

    // A superseded refresh does not report its own failure either: a newer one
    // is the authority on whether the roster is reachable.
    if (superseded()) return;
    ref.read(rosterRefreshFailedProvider.notifier).set(true);
  }

  void dispose() {
    _disposed = true;
    _roomId = null;
    _playerId = null;
    _retryTimer?.cancel();
    _closeAttempt();
  }
}
