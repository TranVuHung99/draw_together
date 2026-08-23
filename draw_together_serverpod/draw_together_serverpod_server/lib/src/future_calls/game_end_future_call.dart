import 'package:serverpod/serverpod.dart';

import '../composition/canvas_svg.dart';
import '../generated/future_calls.dart';
import '../generated/protocol.dart';

/// The server's own clock for the end of a game.
///
/// `RoomEndpoint.startGame` schedules [finalizeRoom] at the room's `endTime`,
/// so the game ends whether or not any client is still connected and whatever
/// a client's clock says.
///
/// The persisted room row, not the schedule, is the authority on whether a
/// game is over. A pause landing microseconds after a scheduled call has
/// already been picked up would otherwise end the game the host just froze;
/// re-reading the room here removes that race rather than narrowing it, and
/// makes the call idempotent under retries and duplicate schedules.
class GameEndFutureCall extends FutureCall {
  /// Closes the room and publishes the composite.
  ///
  /// The status is written and broadcast before the strokes are read, which is
  /// what stops a stroke or an undo from landing while the composite is being
  /// built.
  ///
  /// [ignoreDeadline] waives the "has the clock run out" question, and only
  /// that question: with it set, a room that is `PAUSED` — and so has no
  /// deadline at all — finalizes too. It is what a host stopping early
  /// asserts, and it is the reason a stopped game and an expired one are the
  /// same code path rather than two implementations that have to be kept
  /// agreeing. A scheduled call never sets it.
  Future<void> finalizeRoom(
    Session session,
    int roomId, {
    bool ignoreDeadline = false,
  }) async {
    final room = await Room.db.findById(session, roomId);
    if (room == null) {
      session.log(
        'Skipped finalizing room $roomId: the room no longer exists',
        level: LogLevel.warning,
      );
      return;
    }

    // A scheduled call only ends a game from PLAYING. That covers a room
    // already FINISHED, so it is not finished twice, and a room that has since
    // been PAUSED, whose deadline was cancelled with it. A host stopping early
    // is ending a paused game deliberately, so that case takes PAUSED too.
    final endable = ignoreDeadline
        ? const {'PLAYING', 'PAUSED'}
        : const {'PLAYING'};
    if (!endable.contains(room.status)) {
      session.log(
        'Skipped finalizing room $roomId: its status is ${room.status}',
      );
      return;
    }

    if (!ignoreDeadline) {
      final endTime = room.endTime;
      if (endTime == null) return;
      if (endTime.toUtc().isAfter(DateTime.now().toUtc())) {
        // The deadline moved later — a pause and resume, most likely. The row
        // is the authority, so this call defers to it instead of finalizing.
        await session.serverpod.futureCalls
            .callAtTime(endTime.toUtc(), identifier: 'game_end_$roomId')
            .gameEnd
            .finalizeRoom(roomId);
        session.log(
          'Rescheduled the end of room $roomId for its later deadline',
        );
        return;
      }
    }

    final finished = room.copyWith(status: 'FINISHED');
    await Room.db.updateRow(session, finished);

    await session.messages.postMessage(
      'room_$roomId',
      GameStateChangeMsg(
        roomId: roomId,
        status: 'FINISHED',
        endTime: room.endTime,
      ),
    );

    final players = await Player.db.find(
      session,
      where: (p) => p.roomId.equals(roomId),
      orderBy: (p) => p.id,
    );
    final strokes = await Stroke.db.find(
      session,
      where: (s) => s.roomId.equals(roomId),
      orderBy: (s) => s.sequence,
    );

    await session.messages.postMessage(
      'room_$roomId',
      FinalCanvasMsg(
        roomId: roomId,
        svg: composeCanvasSvg(
          room: finished,
          players: players,
          strokes: strokes,
        ),
      ),
    );

    session.log(
      'Finalized room $roomId from ${strokes.length} persisted stroke(s)',
    );
  }
}
