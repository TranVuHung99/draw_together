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
  /// Completed strokes are persisted, and replayed to a client as it
  /// subscribes, so a reconnecting or late-joining client sees the full canvas.
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

    // The room's last known status. Every write re-reads the room row rather
    // than trusting this, but it keeps the per-batch messages of an in-progress
    // stroke off the database.
    String? roomStatus;

    // Live channel messages land here while a subscription is replaying the
    // room's persisted strokes; null means the replay is over and messages go
    // straight out.
    List<SerializableModel>? replayBuffer;

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
      // The canvas is partitioned as the game starts, which makes any region
      // cached before this moment stale.
      if (message is GameStateChangeMsg) {
        if (message.status == 'PLAYING') regionLoaded = false;
        if (message.status == 'PLAYING' || message.status == 'FINISHED') {
          roomStatus = message.status;
        }
      }

      // Echo suppression: a player never receives their own live stroke back.
      // It applies to `StrokeSyncMsg` alone — an undo is confirmed by the
      // server, so its originator has to receive it too.
      if (message is StrokeSyncMsg && message.playerId == playerId) return;

      if (!out.isClosed) out.add(message);
    }

    /// The wire form of a persisted stroke: a completed stroke carrying its
    /// whole point list, which is exactly what a live `end` message is, so the
    /// client's receive path needs no special case for a replay.
    StrokeSyncMsg replayMessageFor(Stroke stroke) => StrokeSyncMsg(
      roomId: stroke.roomId,
      playerId: stroke.playerId,
      strokeId: stroke.strokeId,
      action: 'end',
      points: stroke.points,
      colorInfo: stroke.colorInfo,
      strokeWidth: stroke.strokeWidth,
      isEraser: stroke.isEraser,
      timestamp: stroke.timestamp,
    );

    Future<void> subscribe(RoomSubscribeMsg message) async {
      // Await the cancel, so the old channel cannot feed `out` alongside the
      // new one for even a moment.
      await channelSubscription?.cancel();
      channelSubscription = null;

      roomId = message.roomId;
      playerId = message.playerId;
      await loadRegion();
      roomStatus = (await Room.db.findById(session, message.roomId))?.status;

      // Subscribe first and buffer, then query, then drain: subscribing after
      // the query would drop a stroke landing in the gap, and querying after
      // subscribing without a buffer would deliver one out of order.
      final buffer = <SerializableModel>[];
      replayBuffer = buffer;

      channelSubscription = session.messages
          .createStream<SerializableModel>('room_${message.roomId}')
          .listen(
            (channelMessage) {
              final pending = replayBuffer;
              if (pending != null) {
                pending.add(channelMessage);
                return;
              }
              forward(channelMessage);
            },
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

      final stored = await Stroke.db.find(
        session,
        where: (s) => s.roomId.equals(message.roomId),
        orderBy: (s) => s.sequence,
      );

      final replayed = <String>{};
      for (final stroke in stored) {
        replayed.add(stroke.strokeId);
        // Replay bypasses `forward` deliberately: a reconnecting player needs
        // their own strokes back, so echo suppression must not apply here.
        if (!out.isClosed) out.add(replayMessageFor(stroke));
      }

      replayBuffer = null;
      for (final buffered in buffer) {
        // A stroke completed while the query was running appears both in the
        // replay and in the buffer. Dropping every buffered message for an
        // already-replayed stroke is what makes the delivery exactly-once.
        if (buffered is StrokeSyncMsg && replayed.contains(buffered.strokeId)) {
          continue;
        }
        forward(buffered);
      }

      session.log(
        'Player ${message.playerId} subscribed to room_${message.roomId}, '
        'replayed ${stored.length} stroke(s)',
      );
    }

    /// Writes a completed stroke, keyed on `strokeId` so a duplicated `end`
    /// message writes a single row.
    Future<void> persist(StrokeSyncMsg message) async {
      final existing = await Stroke.db.findFirstRow(
        session,
        where: (s) => s.strokeId.equals(message.strokeId),
      );
      if (existing != null) return;

      // The server assigns paint order; client clocks are not trustworthy
      // enough to order by timestamp.
      final latest = await Stroke.db.findFirstRow(
        session,
        where: (s) => s.roomId.equals(message.roomId),
        orderBy: (s) => s.sequence,
        orderDescending: true,
      );

      await Stroke.db.insertRow(
        session,
        Stroke(
          roomId: message.roomId,
          playerId: message.playerId,
          strokeId: message.strokeId,
          points: message.points,
          colorInfo: message.colorInfo,
          strokeWidth: message.strokeWidth,
          isEraser: message.isEraser,
          sequence: (latest?.sequence ?? 0) + 1,
          timestamp: message.timestamp,
        ),
      );
    }

    Future<void> handleStroke(int currentRoomId, StrokeSyncMsg message) async {
      if (message.playerId != playerId) {
        session.log(
          'Discarded a stroke from player ${message.playerId} on a '
          'connection subscribed as player $playerId',
          level: LogLevel.warning,
        );
        return;
      }

      // Once the game is over the canvas is closed: nothing is written and
      // nothing is rebroadcast.
      if (roomStatus == 'FINISHED') return;

      if (!regionLoaded) await loadRegion();
      final playerRegion = region;
      // No region means this player does not draw.
      if (playerRegion == null) return;

      final clamped = message.copyWith(
        points: playerRegion.clampPoints(message.points),
      );

      if (message.action == 'end') {
        // `start` and `update` are purely ephemeral: an in-progress stroke
        // interrupted by a disconnect is not worth a row.
        final room = await Room.db.findById(session, currentRoomId);
        roomStatus = room?.status;
        if (room == null || room.status == 'FINISHED') return;
        await persist(clamped);
      }

      await session.messages.postMessage('room_$currentRoomId', clamped);
    }

    Future<void> handleUndo(int currentRoomId, StrokeUndoMsg message) async {
      final currentPlayerId = playerId;
      if (currentPlayerId == null) return;

      if (message.playerId != currentPlayerId) {
        session.log(
          'Discarded an undo from player ${message.playerId} on a '
          'connection subscribed as player $currentPlayerId',
          level: LogLevel.warning,
        );
        return;
      }

      final room = await Room.db.findById(session, currentRoomId);
      roomStatus = room?.status;
      if (room == null || room.status == 'FINISHED') return;

      // Ownership is decided by the stored row, never by the request: this
      // reads the requesting player's own latest stroke and refuses unless the
      // named stroke is that one. A stroke belonging to someone else, or an
      // older stroke of their own, therefore matches nothing.
      final latest = await Stroke.db.findFirstRow(
        session,
        where: (s) =>
            s.roomId.equals(currentRoomId) &
            s.playerId.equals(currentPlayerId),
        orderBy: (s) => s.sequence,
        orderDescending: true,
      );
      if (latest == null || latest.strokeId != message.strokeId) return;

      await Stroke.db.deleteRow(session, latest);

      // Broadcast to the whole room including the originator, which is what
      // makes the server the single authority on what was removed.
      await session.messages.postMessage(
        'room_$currentRoomId',
        StrokeUndoMsg(
          roomId: currentRoomId,
          playerId: currentPlayerId,
          strokeId: latest.strokeId,
        ),
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
        await handleStroke(currentRoomId, message);
      } else if (message is StrokeUndoMsg) {
        await handleUndo(currentRoomId, message);
      }
      // The final composite is generated and broadcast by the server when the
      // deadline passes, so a client cannot post one.
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
