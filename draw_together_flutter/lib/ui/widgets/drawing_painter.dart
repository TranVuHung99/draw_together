import 'package:flutter/material.dart';
import '../../models/stroke.dart';

class DrawingPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? currentStroke;

  DrawingPainter({required this.strokes, this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    // Save the layer so BlendMode.clear works properly for erasing
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    for (final stroke in strokes) {
      canvas.drawPath(stroke.path, stroke.paint);
    }

    if (currentStroke != null) {
      canvas.drawPath(currentStroke!.path, currentStroke!.paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentStroke != currentStroke;
  }
}
