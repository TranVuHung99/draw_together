import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:draw_together_serverpod_client/draw_together_serverpod_client.dart';
import '../models/stroke.dart';

// Provides the current active room
class RoomNotifier extends Notifier<Room?> {
  @override
  Room? build() => null;
  void set(Room? room) => state = room;
}

final roomProvider = NotifierProvider<RoomNotifier, Room?>(RoomNotifier.new);

// Provides the list of current players in the room
class PlayersNotifier extends Notifier<List<Player>> {
  @override
  List<Player> build() => [];
  void set(List<Player> players) => state = players;
}

final playersProvider = NotifierProvider<PlayersNotifier, List<Player>>(
  PlayersNotifier.new,
);

// Provides the current active player's info
class CurrentPlayerNotifier extends Notifier<Player?> {
  @override
  Player? build() => null;
  void set(Player? player) => state = player;
}

final currentPlayerProvider = NotifierProvider<CurrentPlayerNotifier, Player?>(
  CurrentPlayerNotifier.new,
);

// Provides the current game view mode (true = global canvas, false = local region)
class ViewGlobalCanvasNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  void set(bool val) => state = val;
}

final viewGlobalCanvasProvider =
    NotifierProvider<ViewGlobalCanvasNotifier, bool>(
      ViewGlobalCanvasNotifier.new,
    );

// Provides the list of all strokes
class StrokesNotifier extends Notifier<List<Stroke>> {
  @override
  List<Stroke> build() => [];

  void handleStrokeSync(StrokeSyncMsg msg) {
    if (msg.action == 'start') {
      final paint = Paint()
        ..color = Color(int.parse(msg.colorInfo))
        ..strokeWidth = msg.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode = msg.isEraser ? BlendMode.clear : BlendMode.srcOver;

      final path = Path();
      if (msg.points.length >= 2) {
        path.moveTo(msg.points[0], msg.points[1]);
      }

      state = [
        ...state,
        Stroke(
          id: msg.strokeId,
          playerId: msg.playerId,
          path: path,
          paint: paint,
          isEraser: msg.isEraser,
        ),
      ];
    } else if (msg.action == 'update' || msg.action == 'end') {
      // Find the stroke and append points
      final strokeIndex = state.indexWhere((s) => s.id == msg.strokeId);
      if (strokeIndex == -1) return;

      final stroke = state[strokeIndex];
      for (int i = 0; i < msg.points.length; i += 2) {
        if (i + 1 < msg.points.length) {
          stroke.path.lineTo(msg.points[i], msg.points[i + 1]);
        }
      }

      // We trigger a state update by re-assigning the list so listeners rebuild
      state = [...state];
    }
  }

  // Batch insert
  void addStrokes(List<Stroke> newStrokes) {
    state = [...state, ...newStrokes];
  }

  void addStroke(Stroke newStroke) {
    state = [...state, newStroke];
  }

  void clear() {
    state = [];
  }
}

final strokesProvider = NotifierProvider<StrokesNotifier, List<Stroke>>(
  StrokesNotifier.new,
);

// Final merged canvas provided by host at game end
class FinalImageBase64Notifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? b64) => state = b64;
}

final finalImageBase64Provider =
    NotifierProvider<FinalImageBase64Notifier, String?>(
      FinalImageBase64Notifier.new,
    );
