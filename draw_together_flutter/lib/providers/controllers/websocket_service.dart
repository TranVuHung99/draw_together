import 'dart:async';
import 'package:flutter/foundation.dart';
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

  Future<void> connect(int roomId, int playerId) async {
    if (!_isListening) {
      // Initialize the bidirectional stream
      final incomingStream = client.gameStreaming.live(
        _outgoingController.stream,
      );

      // Listen to incoming messages globally
      _incomingSubscription = incomingStream.listen(_handleIncomingMessage);
      _isListening = true;
    }

    // Subscribe to the specific room's channel. The playerId lets the server
    // keep this client's own strokes from being echoed back to it.
    _outgoingController.add(
      RoomSubscribeMsg(roomId: roomId, playerId: playerId),
    );
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
          if (message.status == 'PLAYING') {
            // Regions are assigned as the game starts, so the local player and
            // the roster are both stale from this moment.
            _refreshPlayers(message.roomId);
          }
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
    } catch (e) {
      debugPrint('Error fetching players: $e');
    }
  }

  void dispose() {
    _incomingSubscription?.cancel();
    _outgoingController.close();
    _isListening = false;
  }
}
