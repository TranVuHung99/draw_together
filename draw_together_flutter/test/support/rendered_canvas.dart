import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:draw_together_flutter/models/canvas_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A painter's output, rasterized so individual pixels can be read back.
///
/// The composition rules in `DrawingPainter` — layer per player, clip to
/// region, eraser confined to its own layer — are only observable in the
/// composed image, so verifying them means sampling the pixels rather than
/// inspecting the canvas calls.
class RenderedCanvas {
  final int width;
  final int height;
  final ByteData _rgba;

  const RenderedCanvas(this.width, this.height, this._rgba);

  /// Rasterizes [painter] at [size].
  static Future<RenderedCanvas> ofPainter(
    CustomPainter painter,
    Size size,
  ) async {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), size);
    return ofPicture(recorder.endRecording(), size);
  }

  /// Rasterizes an already-recorded [picture] at [size].
  static Future<RenderedCanvas> ofPicture(ui.Picture picture, Size size) async {
    final image = await picture.toImage(
      size.width.round(),
      size.height.round(),
    );
    picture.dispose();
    try {
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) throw StateError('The rasterizer produced no pixels');
      return RenderedCanvas(image.width, image.height, rgba);
    } finally {
      image.dispose();
    }
  }

  Color pixel(int x, int y) {
    final offset = (y * width + x) * 4;
    return Color.fromARGB(
      _rgba.getUint8(offset + 3),
      _rgba.getUint8(offset),
      _rgba.getUint8(offset + 1),
      _rgba.getUint8(offset + 2),
    );
  }

  /// The colour at a normalized canvas point, as [viewport] places it.
  ///
  /// Sampling by canvas point rather than by pixel is what lets two views at
  /// different magnifications be compared: the same artwork coordinate is
  /// looked up in each.
  Color atCanvasPoint(CanvasViewport viewport, Offset point) {
    final widgetPoint = viewport.toWidget(point);
    return pixel(
      widgetPoint.dx.floor().clamp(0, width - 1),
      widgetPoint.dy.floor().clamp(0, height - 1),
    );
  }

  /// The share of pixels where [other] differs from this by more than
  /// [tolerance] on any channel.
  ///
  /// Two rasterizers never agree exactly at stroke edges, so a comparison of
  /// whole images has to be about how much disagrees, not whether any does.
  double fractionDifferingFrom(RenderedCanvas other, {int tolerance = 16}) {
    expect(other.width, width);
    expect(other.height, height);

    var differing = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!_close(pixel(x, y), other.pixel(x, y), tolerance)) differing++;
      }
    }
    return differing / (width * height);
  }

  static bool _close(Color a, Color b, int tolerance) {
    int diff(double x, double y) => ((x - y).abs() * 255).round();
    return diff(a.a, b.a) <= tolerance &&
        diff(a.r, b.r) <= tolerance &&
        diff(a.g, b.g) <= tolerance &&
        diff(a.b, b.b) <= tolerance;
  }
}

/// Asserts a sampled pixel is [expected], allowing for antialiasing.
void expectColor(
  Color actual,
  Color expected, {
  int tolerance = 4,
  String? reason,
}) {
  expect(
    RenderedCanvas._close(actual, expected, tolerance),
    isTrue,
    reason: ['expected $expected, got $actual', ?reason].join(' — '),
  );
}
