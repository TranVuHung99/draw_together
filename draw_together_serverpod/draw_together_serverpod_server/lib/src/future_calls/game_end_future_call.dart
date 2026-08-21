import 'package:serverpod/serverpod.dart';

import '../composition/canvas_svg.dart';
import '../generated/protocol.dart';

/// The server's own clock for the end of a game.
///
/// `RoomEndpoint.startGame` schedules [finalizeRoom] at the room's `endTime`,
/// so the game ends whether or not any client is still connected and whatever
/// a client's clock says.
class GameEndFutureCall extends FutureCall {
  /// Closes the room and publishes the composite.
  ///
  /// The status is written and broadcast before the strokes are read, which is
  /// what stops a stroke or an undo from landing while the composite is being
  /// built.
  Future<void> finalizeRoom(Session session, int roomId) async {
    final room = await Room.db.findById(session, roomId);
    if (room == null) {
      session.log(
        'Skipped finalizing room $roomId: the room no longer exists',
        level: LogLevel.warning,
      );
      return;
    }
    // A room already finished is not finished twice.
    if (room.status == 'FINISHED') return;

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
