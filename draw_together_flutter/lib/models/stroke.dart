import 'dart:ui';

import 'canvas_viewport.dart';

/// A single line, held as normalized canvas points (0.0 - 1.0) rather than as a
/// pre-built [Path].
///
/// Keeping the geometry resolution-independent is what lets the same stroke be
/// painted through any viewport: switching view mode or resizing the window
/// rebuilds paths at paint time instead of invalidating every stroke.
class Stroke {
  final String id;
  final int playerId;

  /// Normalized canvas points, in the order they were drawn.
  final List<Offset> points;

  final Paint paint;
  final bool isEraser;

  Stroke({
    required this.id,
    required this.playerId,
    required this.points,
    required this.paint,
    required this.isEraser,
  });

  void add(Offset point) => points.add(point);

  void addAll(Iterable<Offset> newPoints) => points.addAll(newPoints);

  /// The widget-space path for [viewport].
  Path toPath(CanvasViewport viewport) {
    final path = Path();
    if (points.isEmpty) return path;

    final first = viewport.toWidget(points.first);
    path.moveTo(first.dx, first.dy);

    if (points.length == 1) {
      // A tap without a drag still leaves a dot.
      path.lineTo(first.dx, first.dy);
      return path;
    }

    for (var i = 1; i < points.length; i++) {
      final point = viewport.toWidget(points[i]);
      path.lineTo(point.dx, point.dy);
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
