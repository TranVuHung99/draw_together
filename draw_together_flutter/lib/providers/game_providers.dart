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

/// The state of this client's streaming connection.
///
/// `reconnecting` and `disconnected` are both "no live connection"; they differ
/// in whether another attempt is coming, which is the part worth telling the
/// player.
enum ConnectionStatus { connected, reconnecting, disconnected }

/// Whether this client has a live stream to the server.
///
/// Nothing has connected before `WebSocketService.connect` runs, so the initial
/// state is `disconnected` rather than an optimistic guess.
class ConnectionStatusNotifier extends Notifier<ConnectionStatus> {
  @override
  ConnectionStatus build() => ConnectionStatus.disconnected;
  void set(ConnectionStatus status) => state = status;
}

final connectionStatusProvider =
    NotifierProvider<ConnectionStatusNotifier, ConnectionStatus>(
      ConnectionStatusNotifier.new,
    );

/// Whether there is a live connection to draw over.
final isConnectedProvider = Provider<bool>(
  (ref) => ref.watch(connectionStatusProvider) == ConnectionStatus.connected,
);

/// Whether drawing input is accepted. All four conditions fail independently:
/// the host never has a region, a spectating player is not in draw mode,
/// everyone fails the status check before the game starts, and nobody may draw
/// into a dead socket. The status check is also what locks the canvas once the
/// game is `FINISHED` or `PAUSED`, in draw mode as much as in spectate mode.
///
/// The connection condition is not presentational in the way the others are.
/// `sendMessage` drops a message on a closed controller without a word, which
/// is one of the ways strokes went missing, so input is refused up front
/// instead.
final canDrawProvider = Provider<bool>((ref) {
  final inDrawMode = !ref.watch(viewGlobalCanvasProvider);
  final hasRegion = ref.watch(localRegionProvider) != null;
  final isPlaying = ref.watch(roomProvider)?.status == 'PLAYING';
  final isConnected = ref.watch(isConnectedProvider);
  return inDrawMode && hasRegion && isPlaying && isConnected;
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
      // An `end` for the local player's own stroke is its confirmation: the
      // server's clamped copy has just entered the board, so the pending copy
      // is done with. Keying on the stroke id alone is enough — only the local
      // player's strokes are ever pending, and ids are random.
      ref.read(pendingStrokesProvider.notifier).remove(msg.strokeId);
      return;
    }

    if (msg.action == 'start' && existing == null) {
      state = state.upsert(_strokeFrom(msg, points));
    }
  }

  /// Removes a stroke the server has confirmed retracted.
  ///
  /// The server sends this for a real undo and for a stroke it has abandoned —
  /// one refused mid-stroke, or left open by a dropped connection — so it has
  /// to reach the pending store as well as the board. A pending stroke has no
  /// entry in the board, and a confirmed one has no entry in pending, so only
  /// one of the two removals ever does anything.
  void handleUndo(StrokeUndoMsg msg) {
    state = state.remove(msg.playerId, msg.strokeId);
    ref.read(pendingStrokesProvider.notifier).remove(msg.strokeId);
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

/// The local player's completed strokes that the server has not confirmed yet,
/// keyed by stroke id, in the order they were sent.
///
/// Deliberately outside [StrokeBoard]. The board means "the composed artwork,
/// in server sequence order": it is what [undoableStrokeProvider] reads, what
/// the painter composites, and what a replay reconstructs. Admitting an
/// unconfirmed stroke into it is what let the client offer an undo for a stroke
/// the server had never heard of, so keeping the two apart makes that guarantee
/// structural rather than a rule to remember.
///
/// A stroke leaves here by confirmation, rejection, retraction, or the canvas
/// reset that precedes a replay — and by nothing else.
class PendingStrokesNotifier extends Notifier<Map<String, Stroke>> {
  @override
  Map<String, Stroke> build() => const {};

  /// Holds a stroke whose `end` has been sent. Insertion order is send order,
  /// which is the order the painter draws them in.
  void add(Stroke stroke) {
    state = {...state, stroke.id: stroke};
  }

  void remove(String strokeId) {
    if (!state.containsKey(strokeId)) return;
    state = {...state}..remove(strokeId);
  }

  void clear() {
    if (state.isEmpty) return;
    state = const {};
  }
}

final pendingStrokesProvider =
    NotifierProvider<PendingStrokesNotifier, Map<String, Stroke>>(
      PendingStrokesNotifier.new,
    );

/// Whether any stroke of the local player's is awaiting confirmation.
final hasPendingStrokesProvider = Provider<bool>(
  (ref) => ref.watch(pendingStrokesProvider).isNotEmpty,
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

/// Whether the undo control is offered. There is no sound answer to "what
/// would this retract" while a stroke is under the pen, and none either while a
/// finished stroke is still waiting for the server to confirm it.
final canUndoProvider = Provider<bool>((ref) {
  if (ref.watch(strokeInProgressProvider)) return false;
  if (ref.watch(hasPendingStrokesProvider)) return false;
  return ref.watch(undoableStrokeProvider) != null;
});

/// The local player's most recent *confirmed* stroke — what an undo would
/// retract, and null when they have nothing to undo.
///
/// It reads the board and nothing else, so a pending stroke can never become
/// the undo target and an undo request can never name a stroke the server does
/// not hold.
final undoableStrokeProvider = Provider<Stroke?>((ref) {
  final playerId = ref.watch(currentPlayerProvider)?.id;
  if (playerId == null) return null;
  return ref.watch(strokesProvider).latestOf(playerId);
});

/// A stroke the server refused, and which rule refused it.
class StrokeRejection {
  final String strokeId;

  /// `NOT_PLAYING`, `NO_REGION`, `NOT_OWNER`, or `ABANDONED`.
  final String reason;

  const StrokeRejection({required this.strokeId, required this.reason});

  /// What to tell the player, or null when there is nothing worth saying.
  ///
  /// `ABANDONED` is silent on purpose: the server retracts a stroke before it
  /// starts refusing messages for it, so the stroke has already come off this
  /// canvas and a second notice would only explain the same event twice.
  String? get message => switch (reason) {
    'NOT_PLAYING' => 'That stroke was not accepted — the game is not running.',
    'NO_REGION' => 'That stroke was not accepted — you have no region to draw '
        'in.',
    'NOT_OWNER' => 'That stroke was not accepted — it named another player.',
    'ABANDONED' => null,
    _ => 'That stroke was not accepted.',
  };
}

/// The last refusal the server sent, for the game screen to show. Every
/// rejection is a new instance, so two identical refusals are two notices.
class StrokeRejectionNotifier extends Notifier<StrokeRejection?> {
  @override
  StrokeRejection? build() => null;
  void set(StrokeRejection? rejection) => state = rejection;
}

final strokeRejectionProvider =
    NotifierProvider<StrokeRejectionNotifier, StrokeRejection?>(
      StrokeRejectionNotifier.new,
    );

/// Whether the roster could not be refreshed after repeated attempts.
///
/// A drawing player whose roster is stale has no region, which locks the canvas
/// with nothing on screen to explain why. This is what puts the explanation
/// there.
class RosterRefreshFailedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool failed) => state = failed;
}

final rosterRefreshFailedProvider =
    NotifierProvider<RosterRefreshFailedNotifier, bool>(
      RosterRefreshFailedNotifier.new,
    );

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
