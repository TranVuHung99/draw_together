import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:draw_together_flutter/models/canvas_viewport.dart';
import 'package:draw_together_flutter/providers/controllers/target_image_controller.dart';
import 'package:draw_together_flutter/providers/game_providers.dart';
import 'package:draw_together_flutter/ui/screens/final_result_screen.dart';
import 'package:draw_together_flutter/ui/widgets/drawing_painter.dart';
import 'package:draw_together_serverpod_client/draw_together_serverpod_client.dart'
    hide Stroke;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/canonical_scene.dart';
import 'support/rendered_canvas.dart';

/// Verifies the final composite the server generates is the canvas players
/// watched being drawn, and that a PNG export comes out at the room's
/// configured size.

const red = Color(0xFFF44336);
const green = Color(0xFF4CAF50);
const blue = Color(0xFF2196F3);
const white = Color(0xFFFFFFFF);

/// Rasterizes an SVG document the way the result screen does: a unit-square
/// picture scaled to the destination pixels.
Future<RenderedCanvas> renderSvg(String svg, Size size) async {
  final pictureInfo = await vg.loadPicture(SvgStringLoader(svg), null);
  try {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(
      size.width / pictureInfo.size.width,
      size.height / pictureInfo.size.height,
    );
    canvas.drawPicture(pictureInfo.picture);
    return RenderedCanvas.ofPicture(recorder.endRecording(), size);
  } finally {
    pictureInfo.picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Given the canonical scene', () {
    const size = Size(500, 500);
    final viewport = CanvasViewport.fit(
      viewport: CanvasViewport.fullCanvas,
      available: size,
      canvasAspectRatio: canvasWidth / canvasHeight,
    );

    late RenderedCanvas live;
    late RenderedCanvas composite;

    setUp(() async {
      live = await RenderedCanvas.ofPainter(
        DrawingPainter(
          board: canonicalBoard(),
          regions: canonicalRegions,
          viewport: viewport,
        ),
        size,
      );
      composite = await renderSvg(canonicalSvg(), size);
    });

    test('when the composite is rendered then it shows the same ordering, '
        'clipping and erasing as the live canvas', () async {
      Color liveAt(double x, double y) =>
          live.atCanvasPoint(viewport, Offset(x, y));
      Color compositeAt(double x, double y) =>
          composite.atCanvasPoint(viewport, Offset(x, y));

      final probes = <Offset, Color>{
        // Alice's first line, ahead of her eraser.
        const Offset(0.10, 0.30): red,
        // Erased back to the background, not to a transparent hole.
        const Offset(0.35, 0.30): white,
        // Erased right up to her region's edge.
        const Offset(0.48, 0.30): white,
        // Bob's line, which her eraser reached towards but never touched.
        const Offset(0.60, 0.30): blue,
        const Offset(0.90, 0.30): blue,
        // Drawn after the eraser, so it is still there.
        const Offset(0.25, 0.60): green,
        // Untouched canvas.
        const Offset(0.75, 0.80): white,
      };

      for (final probe in probes.entries) {
        final x = probe.key.dx;
        final y = probe.key.dy;
        expectColor(liveAt(x, y), probe.value, reason: 'live canvas at ${probe.key}');
        expectColor(
          compositeAt(x, y),
          probe.value,
          tolerance: 8,
          reason: 'composite at ${probe.key}',
        );
      }
    });

    test('when the two renderings are compared then they agree outside stroke '
        'edges', () async {
      // Both go through Skia, so they agree almost exactly — fewer than 25 px
      // of 250,000 differ, all of them on stroke outlines where the two
      // stroking paths round antialiasing differently. The bound leaves room
      // for renderer versions without leaving room for a real divergence: a
      // dropped stroke or a mask over the wrong content is thousands of pixels.
      final differing = live.fractionDifferingFrom(composite);
      expect(differing, lessThan(0.005), reason: '${differing * 100}% differ');
    });
  });

  group('Given the result screen', () {
    testWidgets('when a PNG is exported then it comes out at the room\'s '
        'canvas size', (tester) async {
      final room = Room(
        id: 1,
        roomCode: 'FIXTUR',
        hostId: 1,
        status: 'FINISHED',
        canvasWidth: canvasWidth,
        canvasHeight: canvasHeight,
      );
      final destination = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'draw_together_${room.roomCode}.png',
      );
      if (destination.existsSync()) destination.deleteSync();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomProvider.overrideWith(() => _FixedRoom(room)),
            finalCanvasSvgProvider.overrideWith(
              () => _FixedSvg(canonicalSvg()),
            ),
            // The reveal is a network fetch; this test is about the export, so
            // it is stubbed out rather than left to fail against no server.
            targetImageControllerProvider.overrideWith(
              (ref) => _NoReveal(ref),
            ),
          ],
          child: const MaterialApp(home: FinalResultScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Nothing is rasterized to put the picture on screen.
      expect(destination.existsSync(), isFalse);

      await tester.tap(find.text('Download PNG'));
      await tester.pump();

      // Rasterizing and writing go through the engine and the file system,
      // which need the real event loop; the export's own continuations only run
      // when the test's loop is pumped. So the two are alternated. The file
      // appears when it is opened, so the wait is for its size to settle rather
      // than for it to exist.
      var previous = -1;
      for (var i = 0; i < 200; i++) {
        final size = destination.existsSync() ? destination.lengthSync() : 0;
        if (size > 0 && size == previous) break;
        previous = size;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump();
      }

      expect(destination.existsSync(), isTrue);
      final png = destination.readAsBytesSync();
      expect(_pngSize(png), const Size(canvasWidth, canvasHeight));

      // The export rasterizes the composite document, never the widget tree,
      // so it carries neither the ownership overlay nor the reference image —
      // it is pixel-identical to the composite alone. Decoding and
      // rasterizing are engine work, so they need the real event loop.
      double? differing;
      await tester.runAsync(() async {
        const size = Size(canvasWidth, canvasHeight);
        final exported = await RenderedCanvas.ofPicture(
          await _pictureOf(png),
          size,
        );
        differing = exported.fractionDifferingFrom(
          await renderSvg(canonicalSvg(), size),
        );
      });
      expect(differing, isNotNull);
      expect(differing, lessThan(0.005));

      destination.deleteSync();

      // Let the confirmation snackbar come and go so no timer outlives the
      // test.
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
    });
  });
}

/// Reads the dimensions out of a PNG's IHDR chunk.
Size _pngSize(Uint8List bytes) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  expect(bytes.sublist(0, 8), signature);
  final header = ByteData.sublistView(bytes, 16, 24);
  return Size(
    header.getUint32(0).toDouble(),
    header.getUint32(4).toDouble(),
  );
}

/// Decodes an exported PNG back into a picture, so it can be compared with the
/// composite the screen was showing.
Future<ui.Picture> _pictureOf(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImage(frame.image, Offset.zero, Paint());
  frame.image.dispose();
  codec.dispose();
  return recorder.endRecording();
}

class _NoReveal extends TargetImageController {
  _NoReveal(super.ref);

  @override
  Future<void> loadReveal() async {}
}

class _FixedRoom extends RoomNotifier {
  _FixedRoom(this.room);
  final Room room;

  @override
  Room? build() => room;
}

class _FixedSvg extends FinalCanvasSvgNotifier {
  _FixedSvg(this.svg);
  final String svg;

  @override
  String? build() => svg;
}
