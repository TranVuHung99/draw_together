import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/serverpod_client.dart';
import '../game_providers.dart';

final roomControllerProvider = Provider<RoomController>((ref) {
  return RoomController(ref);
});

class RoomController {
  final Ref ref;

  RoomController(this.ref);

  Future<bool> createRoom(
    String playerName,
    double canvasWidth,
    double canvasHeight,
  ) async {
    try {
      final room = await client.room.createRoom(
        playerName,
        canvasWidth,
        canvasHeight,
      );
      if (room != null) {
        ref.read(roomProvider.notifier).set(room);

        final hostId = room.hostId;
        final hostPlayer = await client.room.getPlayer(hostId);

        if (hostPlayer != null) {
          ref.read(currentPlayerProvider.notifier).set(hostPlayer);
          ref.read(playersProvider.notifier).set([hostPlayer]);
        }
      }
    } catch (e) {
      debugPrint('Error creating room: $e');
      return false;
    }
    return true;
  }

  Future<bool> joinRoom(String roomCode, String playerName) async {
    try {
      final joinedPlayer = await client.room.joinRoom(roomCode, playerName);
      if (joinedPlayer != null) {
        ref.read(currentPlayerProvider.notifier).set(joinedPlayer);

        // Fetch the full room details to keep the client state updated
        final room = await client.room.getRoom(joinedPlayer.roomId);
        if (room != null) {
          ref.read(roomProvider.notifier).set(room);
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error joining room: $e');
    }
    return false;
  }
}
