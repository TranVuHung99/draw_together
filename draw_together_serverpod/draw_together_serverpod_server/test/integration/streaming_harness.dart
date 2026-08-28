import 'dart:async';

import 'package:draw_together_serverpod_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

import 'test_tools/serverpod_test_tools.dart';

/// One connected client: what it sent, and what the server sent back.
class StreamConnection {
  final StreamController<SerializableModel> outgoing =
      StreamController<SerializableModel>();
  final List<SerializableModel> received = [];
  late final StreamSubscription<SerializableModel> subscription;

  List<StrokeSyncMsg> get strokes =>
      received.whereType<StrokeSyncMsg>().toList();
  List<StrokeUndoMsg> get undos => received.whereType<StrokeUndoMsg>().toList();
  List<StrokeRejectedMsg> get rejections =>
      received.whereType<StrokeRejectedMsg>().toList();
  List<GameStateChangeMsg> get stateChanges =>
      received.whereType<GameStateChangeMsg>().toList();

  /// The state changes that actually say where the room is. `PLAYER_JOINED` is
  /// a signal to reload the roster rather than a room status — the endpoint
  /// makes the same distinction when it decides what to cache — so it is not
  /// one of these.
  List<GameStateChangeMsg> get roomStates =>
      stateChanges.where((m) => m.status != 'PLAYER_JOINED').toList();
  List<FinalCanvasMsg> get composites =>
      received.whereType<FinalCanvasMsg>().toList();

  Future<void> close() async {
    await outgoing.close();
    await subscription.cancel();
  }
}

/// Lets the endpoint's message queue and the pub/sub channel settle.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 150));

StrokeSyncMsg strokeMsg({
  required int roomId,
  required int playerId,
  required String strokeId,
  required String action,
  required List<double> points,
  String colorInfo = '0xFFFF0000',
  double strokeWidth = 0.005,
  bool isEraser = false,
}) => StrokeSyncMsg(
  roomId: roomId,
  playerId: playerId,
  strokeId: strokeId,
  action: action,
  points: points,
  colorInfo: colorInfo,
  strokeWidth: strokeWidth,
  isEraser: isEraser,
  timestamp: DateTime.now(),
);

/// The clients of one room, driving the streaming endpoint the way the app
/// does: subscribe, then send a stroke as `start` and `end`.
class RoomClients {
  RoomClients(this.endpoints, this.sessionBuilder, this.roomId);

  final TestEndpoints endpoints;
  final TestSessionBuilder sessionBuilder;
  final int roomId;

  /// Opens a connection and subscribes it to the room, as a client does on
  /// entering the game or on reconnecting after a refresh.
  Future<StreamConnection> connect(int playerId) async {
    final connection = StreamConnection();
    connection.subscription = endpoints.gameStreaming
        .live(sessionBuilder, connection.outgoing.stream)
        .listen(connection.received.add);
    connection.outgoing.add(
      RoomSubscribeMsg(roomId: roomId, playerId: playerId),
    );
    await settle();
    return connection;
  }

  /// Sends one message of a stroke, so a stroke can be started and left open —
  /// which is what a pause or a disconnect mid-stroke looks like to the server.
  Future<void> sendStroke(
    StreamConnection connection,
    int playerId,
    String strokeId,
    String action,
    List<double> points, {
    bool isEraser = false,
    String colorInfo = '0xFFFF0000',
  }) async {
    connection.outgoing.add(
      strokeMsg(
        roomId: roomId,
        playerId: playerId,
        strokeId: strokeId,
        action: action,
        points: points,
        colorInfo: colorInfo,
        isEraser: isEraser,
      ),
    );
    await settle();
  }

  /// Draws one complete stroke and returns its id.
  Future<String> draw(
    StreamConnection connection,
    int playerId,
    String strokeId,
    List<double> points, {
    bool isEraser = false,
    String colorInfo = '0xFFFF0000',
  }) async {
    for (final action in ['start', 'end']) {
      connection.outgoing.add(
        strokeMsg(
          roomId: roomId,
          playerId: playerId,
          strokeId: strokeId,
          action: action,
          points: action == 'start' ? points.take(2).toList() : points,
          colorInfo: colorInfo,
          isEraser: isEraser,
        ),
      );
    }
    await settle();
    return strokeId;
  }

  Future<void> undo(
    StreamConnection connection,
    int playerId,
    String strokeId,
  ) async {
    connection.outgoing.add(
      StrokeUndoMsg(roomId: roomId, playerId: playerId, strokeId: strokeId),
    );
    await settle();
  }
}
