import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:draw_together_serverpod_client/draw_together_serverpod_client.dart';
import '../models/canvas_viewport.dart';
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

/// A drawing player's view mode: `false` is draw mode, which shows only their
/// own region and takes input; `true` is spectate mode, which shows the whole
/// live canvas read-only. Draw mode is the default on entering the game.
///
/// The host has no mode switch — with no region, every derivation below falls
/// through to the full canvas anyway.
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

/// A player's assigned region in normalized canvas space, or null when they do
/// not draw (the host) or the game has not started yet.
Rect? regionOf(Player? player) {
  final x = player?.regionX;
  final y = player?.regionY;
  final width = player?.regionWidth;
  final height = player?.regionHeight;
  if (x == null || y == null || width == null || height == null) return null;
  return Rect.fromLTWH(x, y, width, height);
}

/// Whether the local player is the host of the current room.
final isHostProvider = Provider<bool>((ref) {
  final room = ref.watch(roomProvider);
  final player = ref.watch(currentPlayerProvider);
  return room != null && player != null && room.hostId == player.id;
});

/// The local player's own region, read once here rather than by checking the
/// four nullable fields at each use.
final localRegionProvider = Provider<Rect?>(
  (ref) => regionOf(ref.watch(currentPlayerProvider)),
);

/// The normalized rect the local view shows.
final viewportRectProvider = Provider<Rect>((ref) {
  final region = ref.watch(localRegionProvider);
  final spectating = ref.watch(viewGlobalCanvasProvider);
  if (spectating || region == null) return CanvasViewport.fullCanvas;
  return region;
});

/// Whether drawing input is accepted. All three conditions fail independently:
/// the host never has a region, a spectating player is not in draw mode, and
/// everyone fails the status check before the game starts and after it ends.
final canDrawProvider = Provider<bool>((ref) {
  final inDrawMode = !ref.watch(viewGlobalCanvasProvider);
  final hasRegion = ref.watch(localRegionProvider) != null;
  final isPlaying = ref.watch(roomProvider)?.status == 'PLAYING';
  return inDrawMode && hasRegion && isPlaying;
});

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

      state = [
        ...state,
        Stroke(
          id: msg.strokeId,
          playerId: msg.playerId,
          // Points arrive already normalized; they are mapped to widget space
          // at paint time.
          points: offsetsFromFlat(msg.points),
          paint: paint,
          isEraser: msg.isEraser,
        ),
      ];
    } else if (msg.action == 'update' || msg.action == 'end') {
      // Find the stroke and append points
      final strokeIndex = state.indexWhere((s) => s.id == msg.strokeId);
      if (strokeIndex == -1) return;

      state[strokeIndex].addAll(offsetsFromFlat(msg.points));

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
