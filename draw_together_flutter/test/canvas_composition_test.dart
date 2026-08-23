import 'package:draw_together_flutter/models/canvas_viewport.dart';
import 'package:draw_together_flutter/models/stroke.dart';
import 'package:draw_together_flutter/models/stroke_board.dart';
import 'package:draw_together_flutter/ui/widgets/drawing_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/rendered_canvas.dart';

/// Verifies the layered composition from design D5 against the composed image
/// rather than against the painter's calls: an eraser confined to its owner's
/// layer, sequence order within a layer, and draw mode agreeing with the
/// full-canvas view.

const alice = 2;
const bob = 3;

const regions = <int, Rect>{
  alice: Rect.fromLTWH(0, 0, 0.5, 1),
  bob: Rect.fromLTWH(0.5, 0, 0.5, 1),
};

const red = Color(0xFFF44336);
const green = Color(0xFF4CAF50);
const blue = Color(0xFF2196F3);
const white = Color(0xFFFFFFFF);

Stroke line(
  int playerId,
  String id,
  double y,
  double fromX,
  double toX, {
  Color color = red,
  double width = 0.06,
  bool isEraser = false,
}) => Stroke(
  id: id,
  playerId: playerId,
  points: [Offset(fromX, y), Offset(toX, y)],
  color: color,
  strokeWidth: width,
  isEraser: isEraser,
);

StrokeBoard boardOf(List<Stroke> strokes) {
  var board = StrokeBoard.empty;
  for (final stroke in strokes) {
    board = board.upsert(stroke);
  }
  return board;
}

DrawingPainter painterOf(List<Stroke> strokes, CanvasViewport viewport) =>
    DrawingPainter(
      board: boardOf(strokes),
      regions: regions,
      viewport: viewport,
    );

/// The whole canvas letterboxed into a square area.
CanvasViewport fullCanvasView(double side) => CanvasViewport.fit(
  viewport: CanvasViewport.fullCanvas,
  available: Size(side, side),
  canvasAspectRatio: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Given two players drawing side by side', () {
    // Alice draws across her half, Bob across his, then Alice erases along a
    // line that runs well past the boundary between them.
    final strokes = [
      line(alice, 'a1', 0.3, 0.05, 0.45),
      line(bob, 'b1', 0.3, 0.55, 0.95, color: blue),
      line(alice, 'a2', 0.3, 0.20, 0.80, width: 0.10, isEraser: true),
    ];

    test('when a player erases then only their own strokes are removed and '
        'the background survives', () async {
      final viewport = fullCanvasView(400);
      final rendered = await RenderedCanvas.ofPainter(
        painterOf(strokes, viewport),
        const Size(400, 400),
      );

      Color at(double x, double y) =>
          rendered.atCanvasPoint(viewport, Offset(x, y));

      // Ahead of where the eraser started, Alice's line is intact.
      expectColor(at(0.10, 0.3), red);
      // Under the eraser her line is gone, down to the canvas background — an
      // opaque white, not a transparent hole.
      expectColor(at(0.35, 0.3), white);
      expect(at(0.35, 0.3).a, 1.0);
      // Bob's half is untouched, including the part the eraser passed over.
      expectColor(at(0.60, 0.3), blue);
      expectColor(at(0.90, 0.3), blue);
    });

    test('when the eraser crosses the boundary then it stops at the region '
        'edge', () async {
      final viewport = fullCanvasView(400);
      final rendered = await RenderedCanvas.ofPainter(
        painterOf(strokes, viewport),
        const Size(400, 400),
      );

      // Just inside Alice's region the eraser took effect; just outside it,
      // Bob's own layer is unaffected even though the eraser's geometry
      // reaches there.
      expectColor(rendered.atCanvasPoint(viewport, const Offset(0.48, 0.3)), white);
      expectColor(rendered.atCanvasPoint(viewport, const Offset(0.60, 0.3)), blue);
    });

    test('when draw mode and the full canvas are compared then they show the '
        'same composition', () async {
      final full = fullCanvasView(400);
      final drawMode = CanvasViewport.fit(
        viewport: regions[alice]!,
        available: const Size(600, 1200),
        canvasAspectRatio: 1,
      );

      // Alice's region is 200 px wide on the full canvas and 600 px wide in
      // draw mode: the same image at three times the magnification.
      expect(drawMode.scaleX, closeTo(full.scaleX * 3, 0.001));

      final fullRender = await RenderedCanvas.ofPainter(
        painterOf(strokes, full),
        const Size(400, 400),
      );
      final drawRender = await RenderedCanvas.ofPainter(
        painterOf(strokes, drawMode),
        const Size(600, 1200),
      );

      // Sampled by canvas coordinate, so the lookup is magnification-agnostic.
      // The probes sit inside a stroke or inside the background rather than on
      // an edge, where antialiasing legitimately differs with magnification.
      const probes = [
        Offset(0.10, 0.3), // Alice's line, before the eraser
        Offset(0.35, 0.3), // erased back to the background
        Offset(0.45, 0.3), // erased, near her region's edge
        Offset(0.25, 0.7), // untouched background
        Offset(0.005, 0.3), // beyond where her line starts
      ];
      for (final probe in probes) {
        expectColor(
          drawRender.atCanvasPoint(drawMode, probe),
          fullRender.atCanvasPoint(full, probe),
          tolerance: 8,
          reason: 'at $probe',
        );
      }
    });
  });

  group('Given one player drawing repeatedly', () {
    test('when strokes overlap then the later sequence paints on top',
        () async {
      final viewport = fullCanvasView(400);

      final redThenGreen = await RenderedCanvas.ofPainter(
        painterOf([
          line(alice, 'a1', 0.5, 0.05, 0.45),
          line(alice, 'a2', 0.5, 0.05, 0.45, color: green),
        ], viewport),
        const Size(400, 400),
      );
      final greenThenRed = await RenderedCanvas.ofPainter(
        painterOf([
          line(alice, 'a1', 0.5, 0.05, 0.45, color: green),
          line(alice, 'a2', 0.5, 0.05, 0.45),
        ], viewport),
        const Size(400, 400),
      );

      expectColor(
        redThenGreen.atCanvasPoint(viewport, const Offset(0.25, 0.5)),
        green,
      );
      expectColor(
        greenThenRed.atCanvasPoint(viewport, const Offset(0.25, 0.5)),
        red,
      );
    });

    test('when a stroke follows an eraser then it survives', () async {
      final viewport = fullCanvasView(400);
      final rendered = await RenderedCanvas.ofPainter(
        painterOf([
          line(alice, 'a1', 0.3, 0.05, 0.45),
          line(alice, 'a2', 0.3, 0.05, 0.45, width: 0.10, isEraser: true),
          line(alice, 'a3', 0.3, 0.05, 0.45, color: green),
        ], viewport),
        const Size(400, 400),
      );

      expectColor(
        rendered.atCanvasPoint(viewport, const Offset(0.25, 0.3)),
        green,
      );
    });
  });

  test('when only the host is in the room then no layer is composed', () async {
    const host = 1;
    final viewport = fullCanvasView(200);
    final rendered = await RenderedCanvas.ofPainter(
      DrawingPainter(
        board: StrokeBoard.empty,
        regions: const {},
        viewport: viewport,
      ),
      const Size(200, 200),
    );

    expectColor(rendered.atCanvasPoint(viewport, const Offset(0.5, 0.5)), white);
    expect(regions.containsKey(host), isFalse);
  });
}
