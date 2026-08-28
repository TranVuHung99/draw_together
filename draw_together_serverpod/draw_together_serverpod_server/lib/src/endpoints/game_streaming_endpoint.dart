import 'dart:async';
import 'dart:collection';

import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';

/// How many retracted stroke ids a connection remembers. A client draws one
/// stroke at a time, so only the last few can plausibly still be in flight;
/// bounding it keeps a long session from growing the set without limit.
const int _abandonedStrokeMemory = 8;

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

    // The stroke this connection currently has open: set when a `start` is
    // accepted, cleared when an `end` is accepted. It is what a refusal has to
    // retract, because a `start` has already put the stroke on every other
    // client's canvas.
    //
    // Per-connection rather than per-player: the same player on two
    // connections tracks two open strokes independently, which is already true
    // of the cached region and room status.
    String? openStrokeId;

    // Stroke ids this connection has retracted, most recent last. A retracted
    // stroke stays retracted, so a message that arrives for one afterwards is
    // refused rather than persisted.
    final abandonedStrokeIds = Queue<String>();

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
        // PLAYER_JOINED is a refresh signal rather than a room status, so it
        // is the one state change that must not be written down as one.
        if (message.status != 'PLAYER_JOINED') {
          roomStatus = message.status;
        }
      }

      // Echo suppression: a player never receives their own *in-progress*
      // stroke back. A completed one is different — the `end` carries the
      // server's clamped, persisted copy, and receiving it is what confirms the
      // stroke to its author, so it goes back to everyone including them. An
      // undo is server-confirmed for the same reason and is never suppressed.
      if (message is StrokeSyncMsg &&
          message.playerId == playerId &&
          (message.action == 'start' || message.action == 'update')) {
        return;
      }

      if (!out.isClosed) out.add(message);
    }

    /// Refuses one stroke out loud, to its author and to nobody else.
    ///
    /// The room's channel is a broadcast, so this is written straight to this
    /// connection's own stream: telling the channel would tell the whole room
    /// that a particular player's stroke was refused.
    void reject(int currentRoomId, String strokeId, String reason) {
      final currentPlayerId = playerId;
      if (currentPlayerId == null || out.isClosed) return;
      out.add(
        StrokeRejectedMsg(
          roomId: currentRoomId,
          // The connection's own player, not the message's: this is addressed
          // to whoever is holding the stroke, and on a `NOT_OWNER` refusal the
          // message's `playerId` is precisely the field not to be trusted.
          playerId: currentPlayerId,
          strokeId: strokeId,
          reason: reason,
        ),
      );
    }

    /// Retracts this connection's open stroke when [strokeId] names it, so a
    /// refusal never leaves other clients holding the fragment they were sent
    /// the `start` for.
    ///
    /// Reuses `StrokeUndoMsg`, which already means "remove this stroke id",
    /// is already exempt from echo suppression, and is already handled by every
    /// client. Retraction happens once: the id is recorded as abandoned, so a
    /// later message for it is refused without a second broadcast.
    Future<void> retractIfOpen(int currentRoomId, String strokeId) async {
      final currentPlayerId = playerId;
      if (currentPlayerId == null) return;
      if (openStrokeId != strokeId) return;

      openStrokeId = null;
      abandonedStrokeIds.addLast(strokeId);
      while (abandonedStrokeIds.length > _abandonedStrokeMemory) {
        abandonedStrokeIds.removeFirst();
      }

      await session.messages.postMessage(
        'room_$currentRoomId',
        StrokeUndoMsg(
          roomId: currentRoomId,
          playerId: currentPlayerId,
          strokeId: strokeId,
        ),
      );
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

      // Re-subscribing abandons whatever this connection had open in the room
      // it is leaving, so that room is not left holding a fragment.
      final previousRoomId = roomId;
      final previousOpenStrokeId = openStrokeId;
      if (previousRoomId != null && previousOpenStrokeId != null) {
        await retractIfOpen(previousRoomId, previousOpenStrokeId);
      }

      roomId = message.roomId;
      playerId = message.playerId;
      await loadRegion();
      final room = await Room.db.findById(session, message.roomId);
      roomStatus = room?.status;

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

      // The room's state, before its canvas. Status reaches clients only as a
      // broadcast, and nothing on a client re-reads it, so one that was not
      // connected at the instant of a transition never learns of it: it waits
      // out a round it was meant to play, or holds a finished game that can
      // never progress. Sending the row's current state on every subscribe is
      // what makes a client's state derived from the room rather than from the
      // transitions it happened to witness.
      //
      // It is a statement of where the room is, not a transition, and the
      // client's handler never treated it as anything else — applying it twice
      // is applying it once.
      if (room != null && !out.isClosed) {
        out.add(
          GameStateChangeMsg(
            roomId: room.id!,
            status: room.status,
            endTime: room.endTime,
            remainingMs: room.remainingMs,
          ),
        );

        // Navigating to the result is driven by the composite arriving, so a
        // finished room has to hand over the document it stored as well as its
        // status.
        final svg = room.finalSvg;
        if (svg != null) {
          out.add(FinalCanvasMsg(roomId: room.id!, svg: svg));
        }
      }

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

    /// Writes a completed stroke, keyed on room and `strokeId` so a duplicated
    /// `end` message writes a single row.
    ///
    /// A stroke id identifies a stroke within its room, so the check is scoped
    /// by room too: matching on the id alone would silently discard a stroke
    /// whose id happened to occur in another room.
    Future<void> persist(StrokeSyncMsg message) async {
      final existing = await Stroke.db.findFirstRow(
        session,
        where: (s) =>
            s.roomId.equals(message.roomId) &
            s.strokeId.equals(message.strokeId),
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

    /// Refuses [message], telling its author why and retracting the stroke from
    /// everyone who has already seen it start.
    Future<void> refuse(
      int currentRoomId,
      StrokeSyncMsg message,
      String reason,
    ) async {
      reject(currentRoomId, message.strokeId, reason);
      await retractIfOpen(currentRoomId, message.strokeId);
    }

    Future<void> handleStroke(int currentRoomId, StrokeSyncMsg message) async {
      if (message.playerId != playerId) {
        session.log(
          'Discarded a stroke from player ${message.playerId} on a '
          'connection subscribed as player $playerId',
          level: LogLevel.warning,
        );
        await refuse(currentRoomId, message, 'NOT_OWNER');
        return;
      }

      // A retracted stroke stays retracted. Without this, pause → refuse and
      // retract → host resumes → the in-flight `end` arrives would persist a
      // stroke every client has already been told to remove. `refuse` is not
      // used here: the retraction has already gone out and must not go out
      // twice.
      if (abandonedStrokeIds.contains(message.strokeId)) {
        reject(currentRoomId, message.strokeId, 'ABANDONED');
        return;
      }

      // The canvas is open only while the game is running. Stating it as
      // "accept only when PLAYING" rather than "refuse when FINISHED" covers
      // WAITING and PAUSED in the same rule, and it applies to the ephemeral
      // `start` and `update` batches too, so a paused game leaves no partial
      // stroke on anyone else's screen.
      if (roomStatus != 'PLAYING') {
        await refuse(currentRoomId, message, 'NOT_PLAYING');
        return;
      }

      if (!regionLoaded) await loadRegion();
      final playerRegion = region;
      // No region means this player does not draw.
      if (playerRegion == null) {
        await refuse(currentRoomId, message, 'NO_REGION');
        return;
      }

      final clamped = message.copyWith(
        points: playerRegion.clampPoints(message.points),
      );

      if (message.action == 'end') {
        // `start` and `update` are purely ephemeral: an in-progress stroke
        // interrupted by a disconnect is not worth a row. A completed one is,
        // so its write re-reads the room rather than trusting the cache.
        final room = await Room.db.findById(session, currentRoomId);
        roomStatus = room?.status;
        if (room == null || room.status != 'PLAYING') {
          await refuse(currentRoomId, message, 'NOT_PLAYING');
          return;
        }
        await persist(clamped);
      }

      await session.messages.postMessage('room_$currentRoomId', clamped);

      // What this connection has open, recorded after the broadcast that made
      // it visible elsewhere. An accepted `end` closes the stroke: it is
      // persisted, so there is nothing left for a later refusal to retract.
      if (message.action == 'start') {
        openStrokeId = message.strokeId;
      } else if (message.action == 'end' && openStrokeId == message.strokeId) {
        openStrokeId = null;
      }
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

      // An undo is a write like any other, so it is held to the same rule: it
      // is accepted only while the game is running.
      final room = await Room.db.findById(session, currentRoomId);
      roomStatus = room?.status;
      if (room == null || room.status != 'PLAYING') return;

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
      // A connection that dies mid-stroke has already broadcast the `start`,
      // so the room is holding a fragment that will never be completed. It is
      // retracted here, before anything is torn down, for the same reason a
      // refusal retracts one: no client should be left with a stroke the
      // database will never have.
      final finalRoomId = roomId;
      final unfinishedStrokeId = openStrokeId;
      if (finalRoomId != null && unfinishedStrokeId != null) {
        try {
          await retractIfOpen(finalRoomId, unfinishedStrokeId);
        } catch (e, stackTrace) {
          session.log(
            'Failed to retract stroke $unfinishedStrokeId left open by a '
            'closing connection',
            level: LogLevel.error,
            exception: e,
            stackTrace: stackTrace,
          );
        }
      }

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
