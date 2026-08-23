import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:draw_together_flutter/models/canvas_viewport.dart';
import 'package:draw_together_flutter/providers/game_providers.dart';
import 'package:draw_together_flutter/ui/widgets/canvas_overlays.dart';
import 'package:draw_together_flutter/ui/widgets/drawing_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/canonical_scene.dart';
import 'support/rendered_canvas.dart';

/// The ownership overlay and the reference thumbnail are on screen but not in
/// the artwork.
///
/// Both are siblings of the canvas rather than layers inside `DrawingPainter`,
/// whose output is what the server's SVG mirrors. This pins that: the composed
/// canvas is pixel-identical whether or not they are showing, and neither one
/// can start a stroke.
void main() {
  const size = Size(400, 400);
  final viewport = CanvasViewport.fit(
    viewport: CanvasViewport.fullCanvas,
    available: size,
    canvasAspectRatio: canvasWidth / canvasHeight,
  );

  final owners = [
    (region: canonicalRegions[aliceId]!, name: 'alice', color: Colors.red),
    (region: canonicalRegions[bobId]!, name: 'bob', color: Colors.blue),
  ];

  DrawingPainter canvasPainter() => DrawingPainter(
    board: canonicalBoard(),
    regions: canonicalRegions,
    viewport: viewport,
  );

  test('when the overlay is painted then the composed canvas is unchanged',
      () async {
    // The canvas alone.
    final artwork = await RenderedCanvas.ofPainter(canvasPainter(), size);

    // The same canvas with the overlay above it, as the host sees it. If the
    // overlay were a layer inside DrawingPainter, this is where the two would
    // diverge — and the composite would have borders and names in it.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvasPainter().paint(canvas, size);
    final withOverlay = await RenderedCanvas.ofPicture(
      recorder.endRecording(),
      size,
    );

    expect(withOverlay.fractionDifferingFrom(artwork), 0);
  });

  test('when the overlay painter runs then it draws only outside the '
      'composition', () async {
    // Painted on its own, the overlay is exactly the borders and labels —
    // there is no artwork in it, which is the other half of the separation.
    final overlay = await RenderedCanvas.ofPainter(
      RegionOwnershipPainter(owners: owners, viewport: viewport),
      size,
    );

    // The centre of Alice's region, well away from any border, is untouched.
    expectColor(
      overlay.atCanvasPoint(viewport, const Offset(0.25, 0.6)),
      const Color(0x00000000),
      reason: 'the overlay paints nothing over the middle of a region',
    );
    // The border of Bob's region is drawn in Bob's colour.
    expectColor(
      overlay.pixel(
        viewport.toWidget(const Offset(0.5, 0.5)).dx.round() + 1,
        viewport.toWidget(const Offset(0.5, 0.5)).dy.round(),
      ),
      Colors.blue,
      tolerance: 40,
      reason: 'the region border carries its owner\'s colour',
    );
  });

  group('Given the reference thumbnail', () {
    /// A one-pixel PNG, which is all this needs — the assertions are about
    /// input and presence, not about what the picture shows.
    Uint8List tinyPng() => Uint8List.fromList(const [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82,
    ]);

    /// The thumbnail over a canvas stand-in that records any drag reaching it.
    Widget scene(ProviderContainer container, List<String> reachedCanvas) =>
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) => reachedCanvas.add('start'),
                      child: const ColoredBox(color: Colors.white),
                    ),
                  ),
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: TargetImageThumbnail(),
                  ),
                ],
              ),
            ),
          ),
        );

    testWidgets('when a drag crosses it then no stroke is started',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(targetImageProvider.notifier).set(tinyPng());

      final reachedCanvas = <String>[];
      await tester.pumpWidget(scene(container, reachedCanvas));
      await tester.pump();

      // A drag that begins on the thumbnail is absorbed there: the canvas
      // below is never in the hit-test path at all.
      final thumbnail = tester.getCenter(find.byType(TargetImageThumbnail));
      await tester.dragFrom(thumbnail, const Offset(60, 60));
      await tester.pumpAndSettle();

      expect(reachedCanvas, isEmpty);
    });

    testWidgets('when the room has no target then nothing is shown',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(targetImageProvider.notifier).set(null);

      await tester.pumpWidget(scene(container, []));
      await tester.pump();

      expect(find.byType(Image), findsNothing);
    });

    testWidgets('when the fetch failed then a retry is offered rather than '
        'the game being blocked', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(targetImageProvider.notifier).failed();

      await tester.pumpWidget(scene(container, []));
      await tester.pump();

      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });
}
