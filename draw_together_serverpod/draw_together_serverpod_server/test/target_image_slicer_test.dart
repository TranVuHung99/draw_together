import 'dart:convert';
import 'dart:typed_data';

import 'package:draw_together_serverpod_server/src/composition/target_image_slicer.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

/// The geometry and the format normalization, exercised directly against the
/// slicer so a failure names the arithmetic rather than an endpoint.
void main() {
  /// A source image whose four quadrants are four distinct flat colours, so a
  /// crop can be identified by the pixels it contains.
  img.Image quadrants(int width, int height) {
    final image = img.Image(width: width, height: height);
    final colours = [
      img.ColorRgb8(255, 0, 0), // top-left
      img.ColorRgb8(0, 255, 0), // top-right
      img.ColorRgb8(0, 0, 255), // bottom-left
      img.ColorRgb8(255, 255, 0), // bottom-right
    ];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = (y < height / 2 ? 0 : 2) + (x < width / 2 ? 0 : 1);
        image.setPixel(x, y, colours[index]);
      }
    }
    return image;
  }

  Uint8List pngOf(img.Image image) => Uint8List.fromList(img.encodePng(image));

  /// The colour at the centre of an encoded raster, as `(r, g, b)`.
  List<int> centreColour(Uint8List bytes) {
    final decoded = img.decodeImage(bytes)!;
    final pixel = decoded.getPixel(decoded.width ~/ 2, decoded.height ~/ 2);
    return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
  }

  group('Given an upload to normalize', () {
    test('when a square image goes to a 2:1 room then it is stored 2:1, '
        'centre-cropped rather than stretched or letterboxed', () {
      // A 400x400 source: cover to 2:1 keeps the full width and the middle
      // half of the height, so the stored image is 400x200.
      final normalized = normalizeTargetImage(pngOf(quadrants(400, 400)), 2.0)!;

      expect(normalized.width / normalized.height, closeTo(2.0, 0.02));
      expect(normalized.width, 400);
      expect(normalized.height, 200);

      // Stretching would have kept the top-left quadrant red across the whole
      // top-left; letterboxing would have put blank bands top and bottom. A
      // centre crop puts the quadrant boundary through the middle, so the four
      // corners of the result are still the four source colours.
      final decoded = img.decodeImage(normalized.bytes)!;
      int r(int x, int y) => decoded.getPixel(x, y).r.toInt();
      int g(int x, int y) => decoded.getPixel(x, y).g.toInt();
      int b(int x, int y) => decoded.getPixel(x, y).b.toInt();
      expect([r(10, 10), g(10, 10), b(10, 10)], [255, 0, 0]);
      expect([r(390, 10), g(390, 10), b(390, 10)], [0, 255, 0]);
      expect([r(10, 190), g(10, 190), b(10, 190)], [0, 0, 255]);
      expect([r(390, 190), g(390, 190), b(390, 190)], [255, 255, 0]);
    });

    test('when a wide image goes to a square room then the sides are trimmed',
        () {
      final normalized = normalizeTargetImage(pngOf(quadrants(800, 200)), 1.0)!;
      expect(normalized.width, 200);
      expect(normalized.height, 200);
    });

    test('when the longer edge exceeds the bound then it is downscaled to it, '
        'keeping the normalized aspect', () {
      final normalized = normalizeTargetImage(
        pngOf(quadrants(4000, 4000)),
        2.0,
      )!;
      expect(normalized.width, maxTargetImageEdge);
      expect(normalized.height, maxTargetImageEdge ~/ 2);
    });

    test('when the image is already inside the bound then it is left at its '
        'own size', () {
      final normalized = normalizeTargetImage(pngOf(quadrants(300, 150)), 2.0)!;
      expect(normalized.width, 300);
      expect(normalized.height, 150);
    });

    test('when a JPEG is uploaded then the stored bytes are a PNG', () {
      final jpeg = Uint8List.fromList(img.encodeJpg(quadrants(400, 400)));
      // The source really is a JPEG, so the assertion below is about the
      // conversion rather than about a PNG staying a PNG.
      expect(img.findFormatForData(jpeg), img.ImageFormat.jpg);

      final normalized = normalizeTargetImage(jpeg, 1.0)!;
      expect(img.findFormatForData(normalized.bytes), img.ImageFormat.png);
    });

    test('when the upload is not a decodable image then it is refused', () {
      final text = Uint8List.fromList(utf8.encode('this is not an image'));
      expect(normalizeTargetImage(text, 1.0), isNull);
    });

    test('when the upload is empty or past the byte cap then it is refused',
        () {
      expect(normalizeTargetImage(Uint8List(0), 1.0), isNull);
      expect(
        normalizeTargetImage(Uint8List(maxTargetImageBytes + 1), 1.0),
        isNull,
      );
    });
  });

  group('Given a normalized target to slice', () {
    test('when a region is cropped then its pixel rect is region times '
        'dimensions', () {
      // The scenario the spec names: region (0.5, 0, 0.5, 0.5) of a 1000x500
      // target is the 500x250 rect at (500, 0) — the top-right quadrant.
      final target = pngOf(quadrants(1000, 500));
      final crop = cropTargetImage(
        target,
        left: 0.5,
        top: 0.0,
        width: 0.5,
        height: 0.5,
      )!;

      expect(crop.width, 500);
      expect(crop.height, 250);
      expect(centreColour(crop.bytes), [0, 255, 0]);
    });

    test('when each quadrant is cropped then each carries its own colour', () {
      final target = pngOf(quadrants(1000, 500));
      final expected = {
        [0.0, 0.0]: [255, 0, 0],
        [0.5, 0.0]: [0, 255, 0],
        [0.0, 0.5]: [0, 0, 255],
        [0.5, 0.5]: [255, 255, 0],
      };
      expected.forEach((origin, colour) {
        final crop = cropTargetImage(
          target,
          left: origin[0],
          top: origin[1],
          width: 0.5,
          height: 0.5,
        )!;
        expect(crop.width, 500);
        expect(crop.height, 250);
        expect(centreColour(crop.bytes), colour, reason: 'at $origin');
      });
    });

    test('when a region reaches the far edge then the crop stays inside the '
        'image', () {
      // A three-column partition does not divide 1000 evenly, so the last
      // column is where rounding would run off the end.
      final target = pngOf(quadrants(1000, 500));
      final crop = cropTargetImage(
        target,
        left: 2 / 3,
        top: 0.5,
        width: 1 / 3,
        height: 0.5,
      )!;
      expect(crop.width, lessThanOrEqualTo(1000 - (2 / 3 * 1000).round()));
      expect(crop.width, greaterThan(0));
      expect(crop.height, 250);
    });
  });
}
