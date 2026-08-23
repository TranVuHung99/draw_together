import 'dart:typed_data';
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
/// also what locks the canvas once the game is `FINISHED` or `PAUSED`, in draw
/// mode as much as in spectate mode.
///
/// This is presentational. The server refuses writes outside `PLAYING` too,
/// and that refusal is the enforcement.
final canDrawProvider = Provider<bool>((ref) {
  final inDrawMode = !ref.watch(viewGlobalCanvasProvider);
  final hasRegion = ref.watch(localRegionProvider) != null;
  final isPlaying = ref.watch(roomProvider)?.status == 'PLAYING';
  return inDrawMode && hasRegion && isPlaying;
});

/// Whether the game is frozen. Every client shows this, not just the host, so
/// the state is never ambiguous to a player whose canvas has gone read-only.
final isPausedProvider = Provider<bool>(
  (ref) => ref.watch(roomProvider)?.status == 'PAUSED',
);

/// Seconds left on the server's deadline, or null when there is no deadline.
///
/// While `PLAYING` this is derived from `Room.endTime`, so a client joining
/// mid-game shows the time that is actually left. While `PAUSED` there is no
/// deadline to derive from — the server cancelled it — so it reads the banked
/// remainder instead, and the display freezes without the ticker stopping.
///
/// Purely presentational either way: nothing is finalized when it reaches zero.
int? remainingSeconds(Room? room) {
  if (room?.status == 'PAUSED') {
    final remainingMs = room?.remainingMs;
    if (remainingMs == null) return null;
    return remainingMs < 0 ? 0 : remainingMs ~/ 1000;
  }

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

/// The reference this client is entitled to see: the host the whole target, a
/// drawing player their own crop.
///
/// It is fetched by endpoint call rather than received on the room channel —
/// the channel is a broadcast, so a per-player crop posted there would reach
/// everyone. A failed fetch is a state of its own rather than an absent image,
/// so the game stays playable and the thumbnail can offer a retry.
class TargetImageState {
  /// The PNG bytes, or null while loading, on failure, or when the room has no
  /// target at all.
  final Uint8List? bytes;
  final bool loading;
  final bool failed;

  const TargetImageState({this.bytes, this.loading = false, this.failed = false});

  /// Before any fetch has been attempted: no image, and nothing went wrong.
  static const none = TargetImageState();

  bool get hasImage => bytes != null;
}

class TargetImageNotifier extends Notifier<TargetImageState> {
  @override
  TargetImageState build() => TargetImageState.none;

  void loading() => state = const TargetImageState(loading: true);
  void failed() => state = const TargetImageState(failed: true);

  /// A successful fetch. Null bytes mean the room simply has no target, which
  /// is not a failure — the round plays exactly as it did before targets
  /// existed.
  void set(Uint8List? bytes) => state = TargetImageState(bytes: bytes);

  void clear() => state = TargetImageState.none;
}

final targetImageProvider =
    NotifierProvider<TargetImageNotifier, TargetImageState>(
      TargetImageNotifier.new,
    );

/// The whole target, revealed on the result screen once the round is over.
///
/// Separate from [targetImageProvider] because they are different pictures for
/// everyone but the host: a drawing player held only their own crop while
/// playing, and this is the first time they see the rest.
class RevealedTargetNotifier extends Notifier<Uint8List?> {
  @override
  Uint8List? build() => null;
  void set(Uint8List? bytes) => state = bytes;
}

final revealedTargetProvider =
    NotifierProvider<RevealedTargetNotifier, Uint8List?>(
      RevealedTargetNotifier.new,
    );

/// One drawing player's region, as the host's ownership overlay labels it.
class RegionOwner {
  final Rect region;
  final String name;
  final Color color;

  const RegionOwner({
    required this.region,
    required this.name,
    required this.color,
  });
}

/// Who owns which region, for the host's overlay. The host has no region of
/// its own and so is absent, and a roster refresh rebuilds this rather than
/// leaving stale rectangles on screen.
final regionOwnersProvider = Provider<List<RegionOwner>>((ref) {
  final owners = <RegionOwner>[];
  for (final player in ref.watch(playersProvider)) {
    final region = regionOf(player);
    if (region == null) continue;
    owners.add(
      RegionOwner(
        region: region,
        name: player.name,
        color: Color(int.tryParse(player.colorInfo ?? '') ?? 0xFF000000),
      ),
    );
  }
  return owners;
});

/// Whether the host has the ownership overlay switched on. It is only ever
/// shown on the full canvas and only to the host; this is the toggle on top of
/// those conditions.
class ShowOwnershipNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
}

final showOwnershipProvider = NotifierProvider<ShowOwnershipNotifier, bool>(
  ShowOwnershipNotifier.new,
);

/// Whether the ownership overlay is on screen: host-only, full-canvas only,
/// and switched on. A spectating drawing player sees an anonymous canvas, so
/// they cannot work out the whole picture from who is next to them.
final showOwnershipOverlayProvider = Provider<bool>((ref) {
  if (!ref.watch(isHostProvider)) return false;
  if (!ref.watch(showOwnershipProvider)) return false;
  return ref.watch(viewportRectProvider) == CanvasViewport.fullCanvas;
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
