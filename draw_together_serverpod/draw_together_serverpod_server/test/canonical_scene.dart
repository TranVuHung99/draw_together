import 'package:draw_together_serverpod_server/src/generated/protocol.dart';

/// The scene behind `test_fixtures/final_composite.svg`.
///
/// The same scene is built with the client's painting model in
/// `draw_together_flutter/test/support/canonical_scene.dart`, and the two
/// renderings are compared there. Keeping one description per side and one
/// fixture between them is what makes the comparison meaningful: if the
/// generator drifts, the fixture assertion here fails; if the fixture and the
/// live canvas drift apart, the comparison there fails.
///
/// It exercises every composition rule at once — two players with adjacent
/// regions, an eraser that ran past its owner's boundary before the server
/// clamped it, and a stroke drawn after that eraser.
final canonicalRoom = Room(
  id: 1,
  roomCode: 'FIXTUR',
  hostId: 1,
  status: 'FINISHED',
  canvasWidth: 1000,
  canvasHeight: 1000,
);

/// The host draws nothing and holds no region, so contributes no layer.
final canonicalPlayers = [
  Player(id: 1, roomId: 1, name: 'host'),
  Player(
    id: 2,
    roomId: 1,
    name: 'alice',
    colorInfo: '0xFFF44336',
    regionX: 0,
    regionY: 0,
    regionWidth: 0.5,
    regionHeight: 1,
  ),
  Player(
    id: 3,
    roomId: 1,
    name: 'bob',
    colorInfo: '0xFF2196F3',
    regionX: 0.5,
    regionY: 0,
    regionWidth: 0.5,
    regionHeight: 1,
  ),
];

/// In ascending sequence, the order they are painted in.
final canonicalStrokes = [
  _stroke(
    id: 11,
    playerId: 2,
    strokeId: 's1',
    sequence: 1,
    points: [0.05, 0.30, 0.45, 0.30],
    colorInfo: '0xFFF44336',
  ),
  // Alice erased along a line that ran into Bob's half; the endpoint clamp cut
  // it at the boundary before it was stored.
  _stroke(
    id: 12,
    playerId: 2,
    strokeId: 's2',
    sequence: 2,
    points: [0.20, 0.30, 0.50, 0.30],
    colorInfo: '0xFFF44336',
    strokeWidth: 0.10,
    isEraser: true,
  ),
  // Drawn after the eraser, so it survives it.
  _stroke(
    id: 13,
    playerId: 2,
    strokeId: 's3',
    sequence: 3,
    points: [0.05, 0.60, 0.45, 0.60],
    colorInfo: '0xFF4CAF50',
  ),
  _stroke(
    id: 14,
    playerId: 3,
    strokeId: 's4',
    sequence: 4,
    points: [0.55, 0.30, 0.95, 0.30],
    colorInfo: '0xFF2196F3',
  ),
];

Stroke _stroke({
  required int id,
  required int playerId,
  required String strokeId,
  required int sequence,
  required List<double> points,
  required String colorInfo,
  double strokeWidth = 0.06,
  bool isEraser = false,
}) => Stroke(
  id: id,
  roomId: 1,
  playerId: playerId,
  strokeId: strokeId,
  points: points,
  colorInfo: colorInfo,
  strokeWidth: strokeWidth,
  isEraser: isEraser,
  sequence: sequence,
  timestamp: DateTime.utc(2026, 8, 22),
);
