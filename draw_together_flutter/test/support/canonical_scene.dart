import 'dart:io';

import 'package:draw_together_flutter/models/stroke.dart';
import 'package:draw_together_flutter/models/stroke_board.dart';
import 'package:flutter/material.dart';

/// The client's half of the scene behind `test_fixtures/final_composite.svg`.
///
/// The server's half is
/// `draw_together_serverpod_server/test/canonical_scene.dart`, and the fixture
/// is the artifact its generator produced from it. Painting this scene and
/// rendering that fixture must give the same picture — that is what makes the
/// final composite the canvas players watched being drawn.

const canvasWidth = 1000.0;
const canvasHeight = 1000.0;

const aliceId = 2;
const bobId = 3;

const canonicalRegions = <int, Rect>{
  aliceId: Rect.fromLTWH(0, 0, 0.5, 1),
  bobId: Rect.fromLTWH(0.5, 0, 0.5, 1),
};

/// In the order they were completed, which is ascending server sequence.
StrokeBoard canonicalBoard() {
  var board = StrokeBoard.empty;
  for (final stroke in [
    _stroke(aliceId, 's1', const [Offset(0.05, 0.30), Offset(0.45, 0.30)],
        const Color(0xFFF44336)),
    // Clamped at Alice's boundary by the endpoint before it was stored.
    _stroke(aliceId, 's2', const [Offset(0.20, 0.30), Offset(0.50, 0.30)],
        const Color(0xFFF44336), width: 0.10, isEraser: true),
    // Drawn after the eraser, so it survives it.
    _stroke(aliceId, 's3', const [Offset(0.05, 0.60), Offset(0.45, 0.60)],
        const Color(0xFF4CAF50)),
    _stroke(bobId, 's4', const [Offset(0.55, 0.30), Offset(0.95, 0.30)],
        const Color(0xFF2196F3)),
  ]) {
    board = board.upsert(stroke);
  }
  return board;
}

Stroke _stroke(
  int playerId,
  String id,
  List<Offset> points,
  Color color, {
  double width = 0.06,
  bool isEraser = false,
}) => Stroke(
  id: id,
  playerId: playerId,
  points: List.of(points),
  color: color,
  strokeWidth: width,
  isEraser: isEraser,
);

/// The document the server generated for this scene, as it was committed.
String canonicalSvg() =>
    File('../test_fixtures/final_composite.svg').readAsStringSync().trim();
