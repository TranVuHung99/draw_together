import 'dart:ui';

/// A single line, held as normalized canvas points (0.0 - 1.0) rather than as a
/// pre-built [Path].
///
/// Keeping the geometry resolution-independent is what lets the same stroke be
/// painted through any viewport: switching view mode or resizing the window
/// rebuilds paths at paint time instead of invalidating every stroke.
///
/// [strokeWidth] is normalized the same way — a fraction of the canvas width,
/// not widget pixels — so a stroke keeps its size relative to the artwork in
/// every view, and the server's SVG can use the same number in its unit
/// `viewBox`.
class Stroke {
  final String id;
  final int playerId;

  /// Normalized canvas points, in the order they were drawn.
  final List<Offset> points;

  final Color color;

  /// Width as a fraction of the canvas width.
  final double strokeWidth;

  final bool isEraser;

  Stroke({
    required this.id,
    required this.playerId,
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.isEraser,
  });

  /// The paint for this stroke, in normalized canvas space.
  ///
  /// An eraser clears within its own player's layer, which is what keeps it off
  /// a neighbour's work and off the canvas background.
  late final Paint paint = Paint()
    ..color = color
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke
    ..blendMode = isEraser ? BlendMode.clear : BlendMode.srcOver;

  void add(Offset point) => points.add(point);

  void addAll(Iterable<Offset> newPoints) => points.addAll(newPoints);

  /// A copy carrying [newPoints] instead — used when a completed stroke arrives
  /// with its whole point list and replaces what was accumulated live.
  Stroke withPoints(List<Offset> newPoints) => Stroke(
    id: id,
    playerId: playerId,
    points: newPoints,
    color: color,
    strokeWidth: strokeWidth,
    isEraser: isEraser,
  );

  /// The path in normalized canvas space. The viewport transform is applied to
  /// the canvas, not to the geometry, so composition happens in canvas space.
  Path toPath() {
    final path = Path();
    if (points.isEmpty) return path;

    path.moveTo(points.first.dx, points.first.dy);

    if (points.length == 1) {
      // A tap without a drag still leaves a dot.
      path.lineTo(points.first.dx, points.first.dy);
      return path;
    }

    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    return path;
  }
}

/// Reads a flat `[x1, y1, x2, y2, ...]` wire list into points.
List<Offset> offsetsFromFlat(List<double> flat) {
  final points = <Offset>[];
  for (var i = 0; i + 1 < flat.length; i += 2) {
    points.add(Offset(flat[i], flat[i + 1]));
  }
  return points;
}

/// Writes points back out to the flat `[x1, y1, x2, y2, ...]` wire form.
List<double> flatFromOffsets(Iterable<Offset> points) {
  final flat = <double>[];
  for (final point in points) {
    flat.addAll([point.dx, point.dy]);
  }
  return flat;
}
