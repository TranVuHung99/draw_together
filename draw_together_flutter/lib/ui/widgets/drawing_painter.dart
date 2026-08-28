import 'package:flutter/material.dart';
import '../../models/canvas_viewport.dart';
import '../../models/stroke.dart';
import '../../models/stroke_board.dart';

/// Composes the canvas as one layer per drawing player and maps the result
/// through the viewport.
///
/// The composition happens in normalized canvas space: the viewport transform
/// is applied to the canvas first, and everything below is drawn in canvas
/// coordinates. Doing it the other way round would clip a draw-mode view
/// against a magnified region and compute the eraser mask at a different
/// resolution in each view; this way draw mode and the full-canvas views are
/// the same composed image at different magnifications.
///
/// Each player's strokes go into their own layer, clipped to their region, so
/// an eraser clears only its owner's work. The layers are composited in
/// ascending player id order. The host owns no region and no strokes, and so
/// contributes no layer.
///
/// Within a layer the order is: that player's confirmed strokes in sequence
/// order, then the local player's pending strokes in send order, then their
/// stroke in progress. The unconfirmed ones are painted inside the layer rather
/// than above the composite, which is what keeps an unconfirmed eraser confined
/// to its owner exactly as a confirmed one is.
class DrawingPainter extends CustomPainter {
  final StrokeBoard board;

  /// The region of each drawing player, in normalized canvas coordinates.
  final Map<int, Rect> regions;

  /// The local player's completed strokes awaiting the server's confirmation,
  /// in the order they were sent. They exist only on their author's client and
  /// never reach the final artifact, which is composed from persisted strokes.
  final List<Stroke> pendingStrokes;

  /// The local player's stroke in progress, painted into their own layer.
  final Stroke? currentStroke;

  final CanvasViewport viewport;
  final Color background;

  DrawingPainter({
    required this.board,
    required this.regions,
    required this.viewport,
    this.pendingStrokes = const [],
    this.currentStroke,
    this.background = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final destination = viewport.destination;

    canvas.save();
    canvas.clipRect(destination);

    // The background sits outside every layer, so an eraser clears strokes
    // down to it rather than punching a hole through it.
    canvas.drawRect(destination, Paint()..color = background);

    // From here on the canvas is in normalized coordinates.
    canvas.translate(destination.left, destination.top);
    canvas.scale(viewport.scaleX, viewport.scaleY);
    canvas.translate(-viewport.viewport.left, -viewport.viewport.top);

    for (final playerId in _layerOwners()) {
      final strokes = board.strokesOf(playerId);
      final pending = _pendingOf(playerId);
      final active = currentStroke?.playerId == playerId ? currentStroke : null;
      if (strokes.isEmpty && pending.isEmpty && active == null) continue;

      // A stroke owner always has a region; falling back to the whole canvas
      // covers only the moment before a stale roster catches up, and keeps the
      // eraser inside a layer even then.
      final region = regions[playerId] ?? CanvasViewport.fullCanvas;

      canvas.saveLayer(region, Paint());
      canvas.clipRect(region);
      // Strokes are held in the order they were completed, which is the
      // server's sequence order.
      for (final stroke in strokes) {
        canvas.drawPath(stroke.toPath(), stroke.paint);
      }
      // Then the ones the server has not confirmed yet, in send order, so the
      // layer reads as the player drew it. Confirming one moves it into the
      // board without changing how it looks.
      for (final stroke in pending) {
        canvas.drawPath(stroke.toPath(), stroke.paint);
      }
      if (active != null) {
        canvas.drawPath(active.toPath(), active.paint);
      }
      canvas.restore();
    }

    canvas.restore();
  }

  /// Every player with something to draw, in composition order.
  List<int> _layerOwners() {
    final owners = {...regions.keys, ...board.byPlayer.keys};
    for (final stroke in pendingStrokes) {
      owners.add(stroke.playerId);
    }
    final active = currentStroke?.playerId;
    if (active != null) owners.add(active);
    return owners.toList()..sort();
  }

  /// One player's pending strokes, in send order. In practice they all belong
  /// to the local player; filtering by owner is what keeps them in the right
  /// layer regardless.
  List<Stroke> _pendingOf(int playerId) => pendingStrokes
      .where((stroke) => stroke.playerId == playerId)
      .toList(growable: false);

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return oldDelegate.viewport != viewport ||
        oldDelegate.background != background ||
        !identical(oldDelegate.board, board) ||
        !identical(oldDelegate.regions, regions) ||
        !_samePending(oldDelegate.pendingStrokes, pendingStrokes) ||
        !identical(oldDelegate.currentStroke, currentStroke) ||
        // The stroke in progress is mutated in place, so its identity alone
        // does not tell us whether it grew.
        oldDelegate.currentStroke?.points.length !=
            currentStroke?.points.length;
  }

  /// Whether the pending set is unchanged.
  ///
  /// The list is rebuilt on every paint, so the *list's* identity says nothing;
  /// its members' does. A pending stroke is finished and never mutated
  /// afterwards, which is what makes member identity sufficient here where the
  /// stroke in progress needs its length checked as well.
  static bool _samePending(List<Stroke> a, List<Stroke> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }
}

/// Draws each drawing player's region as a labelled outline in that player's
/// own colour, so the host can name the owner of any rectangle at a glance.
///
/// This is not artwork. It is painted above the composed canvas and outside
/// [DrawingPainter]'s paint tree — whose output is what the server's SVG
/// mirrors requirement for requirement — so it appears on screen and in
/// neither the composite nor a PNG export.
class RegionOwnershipPainter extends CustomPainter {
  /// Each region in normalized canvas coordinates, with its owner's name and
  /// colour.
  final List<({Rect region, String name, Color color})> owners;
  final CanvasViewport viewport;

  RegionOwnershipPainter({required this.owners, required this.viewport});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(viewport.destination);

    for (final owner in owners) {
      final rect = viewport.toWidgetRect(owner.region);
      canvas.drawRect(
        rect.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = owner.color
          ..strokeWidth = 2,
      );

      final label = TextPainter(
        text: TextSpan(
          text: owner.name,
          style: TextStyle(
            color: owner.color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: rect.width - 8);

      // A chip behind the name, so it stays readable over whatever has been
      // drawn underneath it.
      final origin = Offset(rect.left + 4, rect.top + 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            origin.dx - 3,
            origin.dy - 2,
            label.width + 6,
            label.height + 4,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.8),
      );
      label.paint(canvas, origin);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RegionOwnershipPainter oldDelegate) {
    if (oldDelegate.viewport != viewport) return true;
    if (oldDelegate.owners.length != owners.length) return true;
    for (var i = 0; i < owners.length; i++) {
      final a = oldDelegate.owners[i];
      final b = owners[i];
      if (a.region != b.region || a.name != b.name || a.color != b.color) {
        return true;
      }
    }
    return false;
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
