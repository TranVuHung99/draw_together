import 'stroke.dart';

/// Every stroke on the canvas, grouped by the player who drew it.
///
/// The grouping is the composition unit: each player's strokes become one
/// layer, clipped to that player's region, and the layers are composited in
/// ascending player id order. Within a group the order is the order strokes
/// were completed — a replay arrives in ascending server sequence and live
/// strokes append after it, so the group is in sequence order throughout.
class StrokeBoard {
  final Map<int, List<Stroke>> byPlayer;

  const StrokeBoard(this.byPlayer);

  static const StrokeBoard empty = StrokeBoard(<int, List<Stroke>>{});

  /// Layer owners, in composition order.
  List<int> get playerIds => byPlayer.keys.toList()..sort();

  List<Stroke> strokesOf(int playerId) => byPlayer[playerId] ?? const [];

  /// A player's most recent stroke — the one an undo would retract.
  Stroke? latestOf(int playerId) {
    final strokes = byPlayer[playerId];
    return (strokes == null || strokes.isEmpty) ? null : strokes.last;
  }

  Stroke? findById(int playerId, String strokeId) {
    for (final stroke in strokesOf(playerId)) {
      if (stroke.id == strokeId) return stroke;
    }
    return null;
  }

  int get length =>
      byPlayer.values.fold(0, (total, strokes) => total + strokes.length);

  /// Adds [stroke], replacing any stroke already stored under the same id, so
  /// a stroke that arrives twice — live and then again in a replay — is held
  /// once.
  StrokeBoard upsert(Stroke stroke) {
    final strokes = List<Stroke>.of(strokesOf(stroke.playerId));
    final index = strokes.indexWhere((s) => s.id == stroke.id);
    if (index == -1) {
      strokes.add(stroke);
    } else {
      strokes[index] = stroke;
    }
    return _with(stroke.playerId, strokes);
  }

  StrokeBoard remove(int playerId, String strokeId) {
    final strokes = List<Stroke>.of(strokesOf(playerId))
      ..removeWhere((s) => s.id == strokeId);
    return _with(playerId, strokes);
  }

  StrokeBoard _with(int playerId, List<Stroke> strokes) {
    final next = Map<int, List<Stroke>>.of(byPlayer);
    if (strokes.isEmpty) {
      next.remove(playerId);
    } else {
      next[playerId] = strokes;
    }
    return StrokeBoard(next);
  }
}
