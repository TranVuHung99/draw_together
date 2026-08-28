import 'package:draw_together_flutter/models/canvas_viewport.dart';
import 'package:draw_together_flutter/models/stroke.dart';
import 'package:draw_together_flutter/models/stroke_board.dart';
import 'package:draw_together_flutter/ui/widgets/drawing_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/rendered_canvas.dart';

/// Verifies how an unconfirmed stroke composes: inside its owner's clipped
/// layer, after that player's confirmed strokes and before the stroke under the
/// pen, so an unconfirmed eraser is confined to its owner exactly as a
/// confirmed one is, and confirming a stroke does not change how it looks.

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

DrawingPainter painterOf({
  List<Stroke> confirmed = const [],
  List<Stroke> pending = const [],
  Stroke? current,
  required CanvasViewport viewport,
}) => DrawingPainter(
  board: boardOf(confirmed),
  regions: regions,
  pendingStrokes: pending,
  currentStroke: current,
  viewport: viewport,
);

CanvasViewport fullCanvasView(double side) => CanvasViewport.fit(
  viewport: CanvasViewport.fullCanvas,
  available: Size(side, side),
  canvasAspectRatio: 1,
);

Future<RenderedCanvas> render(DrawingPainter painter, double side) =>
    RenderedCanvas.ofPainter(painter, Size(side, side));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Given a pending stroke', () {
    test('when it crosses the owner\'s confirmed strokes then it paints last '
        'within that layer', () async {
      final viewport = fullCanvasView(400);
      final rendered = await render(
        painterOf(
          confirmed: [line(alice, 'a1', 0.3, 0.05, 0.45)],
          pending: [line(alice, 'p1', 0.3, 0.05, 0.45, color: green)],
          viewport: viewport,
        ),
        400,
      );

      expectColor(
        rendered.atCanvasPoint(viewport, const Offset(0.25, 0.3)),
        green,
      );
    });

    test('when several are pending then they paint in send order', () async {
      final viewport = fullCanvasView(400);

      final greenLast = await render(
        painterOf(
          pending: [
            line(alice, 'p1', 0.3, 0.05, 0.45),
            line(alice, 'p2', 0.3, 0.05, 0.45, color: green),
          ],
          viewport: viewport,
        ),
        400,
      );
      final redLast = await render(
        painterOf(
          pending: [
            line(alice, 'p1', 0.3, 0.05, 0.45, color: green),
            line(alice, 'p2', 0.3, 0.05, 0.45),
          ],
          viewport: viewport,
        ),
        400,
      );

      expectColor(
        greenLast.atCanvasPoint(viewport, const Offset(0.25, 0.3)),
        green,
      );
      expectColor(
        redLast.atCanvasPoint(viewport, const Offset(0.25, 0.3)),
        red,
      );
    });

    test('when the stroke under the pen crosses it then the pen paints on top',
        () async {
      final viewport = fullCanvasView(400);
      final rendered = await render(
        painterOf(
          pending: [line(alice, 'p1', 0.3, 0.05, 0.45)],
          current: line(alice, 'live', 0.3, 0.05, 0.45, color: green),
          viewport: viewport,
        ),
        400,
      );

      expectColor(
        rendered.atCanvasPoint(viewport, const Offset(0.25, 0.3)),
        green,
      );
    });

    test('when it runs past the region edge then it is clipped to its owner',
        () async {
      final viewport = fullCanvasView(400);
      // A stroke whose geometry reaches well into Bob's half — what a stale
      // local region produces before the server's clamped copy comes back.
      final rendered = await render(
        painterOf(
          confirmed: [line(bob, 'b1', 0.3, 0.65, 0.95, color: blue)],
          pending: [line(alice, 'p1', 0.3, 0.05, 0.95)],
          viewport: viewport,
        ),
        400,
      );

      Color at(double x) => rendered.atCanvasPoint(viewport, Offset(x, 0.3));

      // Inside Alice's region it is drawn.
      expectColor(at(0.25), red);
      expectColor(at(0.48), red);
      // Past the boundary it stops: the background shows through where its
      // geometry reaches into Bob's half, and Bob's own work is unaffected.
      expectColor(at(0.55), white);
      expectColor(at(0.80), blue);
    });

    test('when it is an eraser crossing the boundary then the neighbour is '
        'untouched', () async {
      final viewport = fullCanvasView(400);
      final rendered = await render(
        painterOf(
          confirmed: [
            line(alice, 'a1', 0.3, 0.05, 0.45),
            line(bob, 'b1', 0.3, 0.55, 0.95, color: blue),
          ],
          pending: [
            line(alice, 'p1', 0.3, 0.20, 0.80, width: 0.10, isEraser: true),
          ],
          viewport: viewport,
        ),
        400,
      );

      Color at(double x) => rendered.atCanvasPoint(viewport, Offset(x, 0.3));

      // Ahead of the eraser Alice's line survives; under it she is erased down
      // to an opaque background, not a transparent hole.
      expectColor(at(0.10), red);
      expectColor(at(0.35), white);
      expect(at(0.35).a, 1.0);
      // Bob's half is untouched even where the eraser's geometry reaches.
      expectColor(at(0.60), blue);
      expectColor(at(0.90), blue);
    });

    test('when it is confirmed then the canvas is unchanged', () async {
      final viewport = fullCanvasView(400);
      final stroke = line(alice, 'p1', 0.3, 0.05, 0.45, color: green);

      final whilePending = await render(
        painterOf(
          confirmed: [line(alice, 'a1', 0.5, 0.05, 0.45)],
          pending: [stroke],
          viewport: viewport,
        ),
        400,
      );
      final onceConfirmed = await render(
        painterOf(
          confirmed: [line(alice, 'a1', 0.5, 0.05, 0.45), stroke],
          viewport: viewport,
        ),
        400,
      );

      expect(whilePending.fractionDifferingFrom(onceConfirmed), 0);
    });

    test('when a player has only pending strokes then their layer is still '
        'composed', () async {
      final viewport = fullCanvasView(400);
      final rendered = await render(
        painterOf(
          pending: [line(alice, 'p1', 0.3, 0.05, 0.95)],
          viewport: viewport,
        ),
        400,
      );

      // Drawn, and still clipped to its owner's region.
      expectColor(rendered.atCanvasPoint(viewport, const Offset(0.25, 0.3)), red);
      expectColor(
        rendered.atCanvasPoint(viewport, const Offset(0.70, 0.3)),
        white,
      );
    });
  });

  group('Given the painter is asked whether to repaint', () {
    final viewport = fullCanvasView(400);
    final first = line(alice, 'p1', 0.3, 0.05, 0.45);
    final second = line(alice, 'p2', 0.4, 0.05, 0.45);

    test('when the pending set is unchanged then it does not repaint', () {
      final board = boardOf([line(alice, 'a1', 0.5, 0.05, 0.45)]);
      // A fresh list of the same strokes on every build: the list's identity
      // says nothing, so the members' has to be what is compared.
      final before = DrawingPainter(
        board: board,
        regions: regions,
        pendingStrokes: [first],
        viewport: viewport,
      );
      final after = DrawingPainter(
        board: board,
        regions: regions,
        pendingStrokes: [first],
        viewport: viewport,
      );

      expect(after.shouldRepaint(before), isFalse);
    });

    test('when a stroke becomes pending then it repaints', () {
      final board = boardOf([line(alice, 'a1', 0.5, 0.05, 0.45)]);
      final before = DrawingPainter(
        board: board,
        regions: regions,
        viewport: viewport,
      );
      final after = DrawingPainter(
        board: board,
        regions: regions,
        pendingStrokes: [first],
        viewport: viewport,
      );

      expect(after.shouldRepaint(before), isTrue);
    });

    test('when a pending stroke is replaced by another then it repaints', () {
      final board = boardOf([line(alice, 'a1', 0.5, 0.05, 0.45)]);
      final before = DrawingPainter(
        board: board,
        regions: regions,
        pendingStrokes: [first],
        viewport: viewport,
      );
      final after = DrawingPainter(
        board: board,
        regions: regions,
        pendingStrokes: [second],
        viewport: viewport,
      );

      expect(after.shouldRepaint(before), isTrue);
    });
  });
}
