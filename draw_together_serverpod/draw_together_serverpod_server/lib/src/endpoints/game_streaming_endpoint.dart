import 'dart:async';

import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';

class GameStreamingEndpoint extends Endpoint {
  @override
  bool get requireLogin => false;

  /// Bridges one client to its room's pub/sub channel.
  ///
  /// Incoming messages are republished to `room_<id>`; everything posted to
  /// that channel is forwarded back out to this client, minus its own strokes.
  Stream<SerializableModel> live(
    Session session,
    Stream<SerializableModel> incomingStream,
  ) async* {
    final out = StreamController<SerializableModel>();

    int? roomId;
    int? playerId;
    _Region? region;
    // Regions are assigned when the game starts, so a region read before then
    // is legitimately null and must not be cached as the final answer.
    var regionLoaded = false;

    StreamSubscription<SerializableModel>? channelSubscription;
    StreamSubscription<SerializableModel>? incomingSubscription;

    Future<void> loadRegion() async {
      regionLoaded = true;
      region = null;
      final id = playerId;
      if (id == null) return;
      region = _Region.of(await Player.db.findById(session, id));
    }

    void forward(SerializableModel message) {
      // Echo suppression: a player never receives their own stroke back.
      if (message is StrokeSyncMsg && message.playerId == playerId) return;

      // The canvas is partitioned as the game starts, which makes any region
      // cached before this moment stale.
      if (message is GameStateChangeMsg && message.status == 'PLAYING') {
        regionLoaded = false;
      }

      if (!out.isClosed) out.add(message);
    }

    Future<void> subscribe(RoomSubscribeMsg message) async {
      // Await the cancel, so the old channel cannot feed `out` alongside the
      // new one for even a moment.
      await channelSubscription?.cancel();
      channelSubscription = null;

      roomId = message.roomId;
      playerId = message.playerId;
      await loadRegion();

      channelSubscription = session.messages
          .createStream<SerializableModel>('room_${message.roomId}')
          .listen(
            forward,
            onError: (Object e, StackTrace stackTrace) {
              // A value that cannot be delivered as a SerializableModel is
              // dropped; it must not tear down this client's stream.
              session.log(
                'Dropped an undeliverable message on room_${message.roomId}',
                level: LogLevel.warning,
                exception: e,
                stackTrace: stackTrace,
              );
            },
            cancelOnError: false,
          );

      session.log(
        'Player ${message.playerId} subscribed to room_${message.roomId}',
      );
    }

    Future<void> handleIncoming(SerializableModel message) async {
      if (message is RoomSubscribeMsg) {
        await subscribe(message);
        return;
      }

      final currentRoomId = roomId;
      if (currentRoomId == null) return;

      if (message is StrokeSyncMsg) {
        if (message.playerId != playerId) {
          session.log(
            'Discarded a stroke from player ${message.playerId} on a '
            'connection subscribed as player $playerId',
            level: LogLevel.warning,
          );
          return;
        }

        if (!regionLoaded) await loadRegion();
        final playerRegion = region;
        // No region means this player does not draw.
        if (playerRegion == null) return;

        await session.messages.postMessage(
          'room_$currentRoomId',
          message.copyWith(points: playerRegion.clampPoints(message.points)),
        );
      } else if (message is FinalCanvasMsg) {
        await session.messages.postMessage('room_$currentRoomId', message);
      }
    }

    // Handling is chained onto a queue so messages are processed in the order
    // they arrive, even though handling is asynchronous.
    var queue = Future<void>.value();

    incomingSubscription = incomingStream.listen(
      (message) {
        queue = queue.then((_) => handleIncoming(message)).catchError((
          Object e,
          StackTrace stackTrace,
        ) {
          session.log(
            'Failed to handle an incoming message',
            level: LogLevel.error,
            exception: e,
            stackTrace: stackTrace,
          );
        });
      },
      onError: (Object e, StackTrace stackTrace) {
        session.log(
          'Error on the incoming stream',
          level: LogLevel.error,
          exception: e,
          stackTrace: stackTrace,
        );
      },
      onDone: () {
        queue.whenComplete(() {
          if (!out.isClosed) out.close();
        });
      },
      cancelOnError: false,
    );

    try {
      yield* out.stream;
    } finally {
      await channelSubscription?.cancel();
      await incomingSubscription.cancel();
      if (!out.isClosed) await out.close();
    }
  }
}

/// A player's assigned region, in normalized canvas coordinates (0.0 - 1.0).
class _Region {
  final double left;
  final double top;
  final double width;
  final double height;

  const _Region(this.left, this.top, this.width, this.height);

  static _Region? of(Player? player) {
    final x = player?.regionX;
    final y = player?.regionY;
    final width = player?.regionWidth;
    final height = player?.regionHeight;
    if (x == null || y == null || width == null || height == null) return null;
    return _Region(x, y, width, height);
  }

  /// Clamps each (x, y) pair to the region. Stray points are pulled to the
  /// boundary rather than dropped, so the stroke stays continuous.
  List<double> clampPoints(List<double> points) {
    final clamped = List<double>.of(points);
    for (var i = 0; i + 1 < clamped.length; i += 2) {
      clamped[i] = clamped[i].clamp(left, left + width).toDouble();
      clamped[i + 1] = clamped[i + 1].clamp(top, top + height).toDouble();
    }
    return clamped;
  }
}
