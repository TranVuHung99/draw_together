import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';

class GameStreamingEndpoint extends Endpoint {
  @override
  bool get requireLogin => false;

  Stream<SerializableModel> live(
    Session session,
    Stream<SerializableModel> incomingStream,
  ) async* {
    int? currentRoomId;

    await for (var message in incomingStream) {
      if (message is RoomSubscribeMsg) {
        currentRoomId = message.roomId;
        session.messages.addListener('room_$currentRoomId', (msg) {
          // How to send back from listener?
          // We can't easily yield from a listener callback in a generic async* unless we use a StreamController.
        });
        print('Session subscribed to room_$currentRoomId');
      } else if (message is StrokeSyncMsg && currentRoomId != null) {
        await session.messages.postMessage('room_$currentRoomId', message);
      } else if (message is FinalCanvasMsg && currentRoomId != null) {
        await session.messages.postMessage('room_$currentRoomId', message);
      }
    }
  }
}
