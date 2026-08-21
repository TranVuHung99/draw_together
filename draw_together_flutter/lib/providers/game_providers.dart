import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// The generated `Stroke` is the server's table row; the canvas works with the
// local painting model of the same name.
import 'package:draw_together_serverpod_client/draw_together_serverpod_client.dart'
    hide Stroke;
import '../models/canvas_viewport.dart';
import '../models/stroke.dart';
import '../models/stroke_board.dart';

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

/// The region of every drawing player, keyed by player id. A player without a
/// region — the host — is absent, and so contributes no layer to the canvas.
final playerRegionsProvider = Provider<Map<int, Rect>>((ref) {
  final regions = <int, Rect>{};
  for (final player in ref.watch(playersProvider)) {
    final region = regionOf(player);
    if (player.id != null && region != null) regions[player.id!] = region;
  }
  return regions;
});

/// Whether drawing input is accepted. All three conditions fail independently:
/// the host never has a region, a spectating player is not in draw mode, and
/// everyone fails the status check before the game starts. The status check is
/// also what locks the canvas once the game is `FINISHED`, in draw mode as
/// much as in spectate mode.
final canDrawProvider = Provider<bool>((ref) {
  final inDrawMode = !ref.watch(viewGlobalCanvasProvider);
  final hasRegion = ref.watch(localRegionProvider) != null;
  final isPlaying = ref.watch(roomProvider)?.status == 'PLAYING';
  return inDrawMode && hasRegion && isPlaying;
});

/// Seconds left on the server's deadline, or null when there is no deadline.
///
/// Derived from `Room.endTime` so a client joining mid-game shows the time that
/// is actually left. Purely presentational: nothing is finalized when it
/// reaches zero.
int? remainingSeconds(Room? room) {
  final endTime = room?.endTime;
  if (endTime == null) return null;
  final seconds = endTime.difference(DateTime.now()).inSeconds;
  return seconds < 0 ? 0 : seconds;
}

/// Every stroke on the canvas, grouped by the player who drew it.
class StrokesNotifier extends Notifier<StrokeBoard> {
  @override
  StrokeBoard build() => StrokeBoard.empty;

  void handleStrokeSync(StrokeSyncMsg msg) {
    // Points arrive already normalized; the viewport transform is applied to
    // the canvas at paint time, never to the geometry.
    final points = offsetsFromFlat(msg.points);

    if (msg.action == 'update') {
      // An in-progress stroke grows in place; only its owner's layer repaints.
      final stroke = state.findById(msg.playerId, msg.strokeId);
      if (stroke == null) return;
      stroke.addAll(points);
      // Re-wrapping the board is what tells listeners the canvas changed.
      state = StrokeBoard(state.byPlayer);
      return;
    }

    final existing = state.findById(msg.playerId, msg.strokeId);

    if (msg.action == 'end') {
      // A completed stroke carries its whole point list, whether it arrives
      // live or in a replay, so it replaces whatever was accumulated.
      state = state.upsert(
        (existing ?? _strokeFrom(msg, points)).withPoints(points),
      );
      return;
    }

    if (msg.action == 'start' && existing == null) {
      state = state.upsert(_strokeFrom(msg, points));
    }
  }

  /// Removes a stroke the server has confirmed retracted.
  void handleUndo(StrokeUndoMsg msg) {
    state = state.remove(msg.playerId, msg.strokeId);
  }

  /// Records the local player's own completed stroke, which the server does
  /// not echo back to them.
  void addStroke(Stroke newStroke) {
    state = state.upsert(newStroke);
  }

  void clear() {
    state = StrokeBoard.empty;
  }

  Stroke _strokeFrom(StrokeSyncMsg msg, List<Offset> points) => Stroke(
    id: msg.strokeId,
    playerId: msg.playerId,
    points: points,
    color: Color(int.tryParse(msg.colorInfo) ?? 0xFF000000),
    strokeWidth: msg.strokeWidth,
    isEraser: msg.isEraser,
  );
}

final strokesProvider = NotifierProvider<StrokesNotifier, StrokeBoard>(
  StrokesNotifier.new,
);

/// Whether the local player is part-way through a stroke. Undo is unavailable
/// while one is open, rather than having to reason about what it would target.
class StrokeInProgressNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final strokeInProgressProvider =
    NotifierProvider<StrokeInProgressNotifier, bool>(
      StrokeInProgressNotifier.new,
    );

/// The local player's most recent stroke — what an undo would retract, and
/// null when they have nothing to undo.
final undoableStrokeProvider = Provider<Stroke?>((ref) {
  final playerId = ref.watch(currentPlayerProvider)?.id;
  if (playerId == null) return null;
  return ref.watch(strokesProvider).latestOf(playerId);
});

/// The final composite, as the SVG document the server generated. Null until
/// the game ends.
class FinalCanvasSvgNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? svg) => state = svg;
}

final finalCanvasSvgProvider = NotifierProvider<FinalCanvasSvgNotifier, String?>(
  FinalCanvasSvgNotifier.new,
);
