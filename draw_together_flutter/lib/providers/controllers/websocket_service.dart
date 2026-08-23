import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/serverpod_client.dart';
import 'package:draw_together_serverpod_client/draw_together_serverpod_client.dart';
import '../game_providers.dart';
import 'target_image_controller.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

class WebSocketService {
  final Ref ref;
  bool _isListening = false;
  // Deliberately single-subscription, not a broadcast controller. The Serverpod
  // client only attaches its listener after the websocket handshake and the
  // open-stream round trip have both completed, which is well after `connect()`
  // adds the first `RoomSubscribeMsg`. A broadcast controller drops events that
  // arrive with no listener attached, which silently discarded the subscribe
  // message and left the connection subscribed to no room at all. A
  // single-subscription controller buffers until the client listens.
  final StreamController<SerializableModel> _outgoingController =
      StreamController<SerializableModel>();
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
    } else if (message is StrokeUndoMsg) {
      // The server confirms every undo, including the local player's own, so
      // this is the only place a stroke is retracted.
      ref.read(strokesProvider.notifier).handleUndo(message);
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
          // `endTime` and `remainingMs` are each other's opposite — the server
          // clears one as it sets the other — so both are applied from every
          // change rather than only the one the new status happens to use.
          ref
              .read(roomProvider.notifier)
              .set(
                room.copyWith(
                  status: message.status,
                  endTime: message.endTime,
                  remainingMs: message.remainingMs,
                ),
              );
          if (message.status == 'PLAYING') {
            // Regions are assigned as the game starts, so the local player and
            // the roster are both stale from this moment.
            _refreshPlayers(message.roomId);
            // The crop is cut from the same regions, so it is fetched here
            // too. A client that never sees this message fetches it on
            // entering the game screen instead.
            ref.read(targetImageControllerProvider).load();
          }
        }
      }
    } else if (message is FinalCanvasMsg) {
      ref.read(finalCanvasSvgProvider.notifier).set(message.svg);
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
