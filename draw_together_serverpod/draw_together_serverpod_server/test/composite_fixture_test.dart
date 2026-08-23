import 'dart:io';

import 'package:draw_together_serverpod_server/src/composition/canvas_svg.dart';
import 'package:test/test.dart';

import 'canonical_scene.dart';

/// Pins the generator's output for the canonical scene to the fixture the
/// Flutter side renders and compares against the live canvas.
///
/// Without this, that comparison could keep passing against a stale document
/// while the generator drifted. Regenerating the fixture is a deliberate act:
/// whoever changes the SVG has to look at the new picture.
void main() {
  test('when the canonical scene is composed then it matches the shared '
      'fixture', () {
    final fixture = File('../../test_fixtures/final_composite.svg');
    expect(
      fixture.existsSync(),
      isTrue,
      reason: 'the shared fixture is missing at ${fixture.absolute.path}',
    );

    expect(
      composeCanvasSvg(
        room: canonicalRoom,
        players: canonicalPlayers,
        strokes: canonicalStrokes,
      ),
      fixture.readAsStringSync().trim(),
    );
  });
}
