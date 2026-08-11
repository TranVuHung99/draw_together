import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The local drawing tool settings.
///
/// These live outside the canvas widget because the toolbar is a sibling of the
/// canvas, not a child of it.
class DrawingTool {
  final Color color;
  final double strokeWidth;
  final bool isEraser;

  const DrawingTool({
    this.color = const Color(0xFF000000),
    this.strokeWidth = 5.0,
    this.isEraser = false,
  });

  DrawingTool copyWith({Color? color, double? strokeWidth, bool? isEraser}) =>
      DrawingTool(
        color: color ?? this.color,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        isEraser: isEraser ?? this.isEraser,
      );

  /// The wire form of [color], as `StrokeSyncMsg.colorInfo` carries it.
  String get colorInfo =>
      '0x${color.toARGB32().toRadixString(16).padLeft(8, '0')}';
}

class DrawingToolNotifier extends Notifier<DrawingTool> {
  @override
  DrawingTool build() => const DrawingTool();

  void setColor(Color color) =>
      // Picking a colour means you want to draw, not erase.
      state = state.copyWith(color: color, isEraser: false);

  void setStrokeWidth(double width) =>
      state = state.copyWith(strokeWidth: width);

  void setEraser(bool isEraser) => state = state.copyWith(isEraser: isEraser);
}

final drawingToolProvider = NotifierProvider<DrawingToolNotifier, DrawingTool>(
  DrawingToolNotifier.new,
);
