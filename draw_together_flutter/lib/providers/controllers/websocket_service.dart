import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/serverpod_client.dart';
import 'package:draw_together_serverpod_client/draw_together_serverpod_client.dart';
import '../game_providers.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

class WebSocketService {
  final Ref ref;
  bool _isListening = false;
  final StreamController<SerializableModel> _outgoingController =
      StreamController<SerializableModel>.broadcast();
  StreamSubscription? _incomingSubscription;

  WebSocketService(this.ref);

  Future<void> connect(int roomId) async {
    if (!_isListening) {
      // Initialize the bidirectional stream
      final incomingStream = client.gameStreaming.live(
        _outgoingController.stream,
      );

      // Listen to incoming messages globally
      _incomingSubscription = incomingStream.listen(_handleIncomingMessage);
      _isListening = true;
    }

    // Subscribe to the specific room's channel
    _outgoingController.add(RoomSubscribeMsg(roomId: roomId));
  }

  void _handleIncomingMessage(SerializableModel message) {
    if (message is StrokeSyncMsg) {
      ref.read(strokesProvider.notifier).handleStrokeSync(message);
    } else if (message is GameStateChangeMsg) {
      // A change in room game state or new player joined

      // Update Room status
      final room = ref.read(roomProvider);
      if (room != null && room.id == message.roomId) {
        if (message.status == 'PLAYER_JOINED') {
          // We could refetch players or just know a change happened.
          // Easiest is to trigger a refresh via RoomController.
          _refreshPlayers(message.roomId);
        } else {
          ref
              .read(roomProvider.notifier)
              .set(
                room.copyWith(status: message.status, endTime: message.endTime),
              );
        }
      }
    } else if (message is FinalCanvasMsg) {
      ref.read(finalImageBase64Provider.notifier).set(message.base64Image);
      // Ensure local room state reflects finished
      final room = ref.read(roomProvider);
      if (room != null) {
        ref.read(roomProvider.notifier).set(room.copyWith(status: 'FINISHED'));
      }
    }
  }

  void sendMessage(SerializableModel msg) {
    if (!_outgoingController.isClosed) {
      _outgoingController.add(msg);
    }
  }

  Future<void> _refreshPlayers(int roomId) async {
    try {
      final players = await client.room.getPlayersInRoom(roomId);
      ref.read(playersProvider.notifier).set(players);
    } catch (e) {
      print('Error fetching players: $e');
    }
  }

  void dispose() {
    _incomingSubscription?.cancel();
    _outgoingController.close();
    _isListening = false;
  }
}
