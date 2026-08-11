import 'package:flutter/material.dart';
import '../../models/canvas_viewport.dart';
import '../../models/stroke.dart';

/// Paints every stroke through a single viewport.
///
/// Strokes are stored in normalized canvas coordinates, so this is the one
/// place that turns them into widget pixels. Anything outside the viewport is
/// clipped away, which is what keeps other players' work off a draw-mode view.
class DrawingPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? currentStroke;
  final CanvasViewport viewport;
  final Color background;

  DrawingPainter({
    required this.strokes,
    required this.viewport,
    this.currentStroke,
    this.background = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final destination = viewport.destination;

    canvas.save();
    canvas.clipRect(destination);

    // The background sits outside the layer below, so an eraser clears strokes
    // down to it rather than punching a hole through it.
    canvas.drawRect(destination, Paint()..color = background);

    // Save the layer so BlendMode.clear works properly for erasing
    canvas.saveLayer(destination, Paint());

    for (final stroke in strokes) {
      canvas.drawPath(stroke.toPath(viewport), stroke.paint);
    }

    final active = currentStroke;
    if (active != null) {
      canvas.drawPath(active.toPath(viewport), active.paint);
    }

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return oldDelegate.viewport != viewport ||
        oldDelegate.background != background ||
        !identical(oldDelegate.strokes, strokes) ||
        !identical(oldDelegate.currentStroke, currentStroke) ||
        // The stroke in progress is mutated in place, so its identity alone
        // does not tell us whether it grew.
        oldDelegate.currentStroke?.points.length !=
            currentStroke?.points.length;
  }
}

/// One player's region, as the full-canvas views outline it.
class RegionOutline {
  /// The region in normalized canvas coordinates.
  final Rect region;

  /// Whether it belongs to the local player.
  final bool isOwn;

  const RegionOutline({required this.region, required this.isOwn});
}

/// Outlines the assigned regions on a full-canvas view so the partition is
/// visible. Unassigned grid cells have no outline — they are not regions.
class RegionOutlinePainter extends CustomPainter {
  final List<RegionOutline> outlines;
  final CanvasViewport viewport;

  RegionOutlinePainter({required this.outlines, required this.viewport});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(viewport.destination);

    for (final outline in outlines) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..color = outline.isOwn ? Colors.blueAccent : Colors.grey.shade400
        ..strokeWidth = outline.isOwn ? 3 : 1;
      canvas.drawRect(viewport.toWidgetRect(outline.region), paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RegionOutlinePainter oldDelegate) {
    return oldDelegate.viewport != viewport ||
        !_sameOutlines(oldDelegate.outlines, outlines);
  }

  static bool _sameOutlines(List<RegionOutline> a, List<RegionOutline> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].region != b[i].region || a[i].isOwn != b[i].isOwn) return false;
    }
    return true;
  }
}
