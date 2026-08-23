import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The largest upload the server will look at, before decoding.
///
/// Five mebibytes takes a photo straight off a phone without argument, while
/// still bounding the work a single unauthenticated call can ask the server to
/// do: everything past this point decodes the whole image into memory.
const int maxTargetImageBytes = 5 * 1024 * 1024;

/// The longest edge of a stored target, in pixels.
///
/// A target is a reference to glance at, and each drawing player only ever
/// sees a fraction of it, so resolution past this buys nothing on screen. It
/// is also what keeps a re-encoded PNG to a few hundred kilobytes, which is
/// what makes storing the bytes in a row (rather than object storage) a
/// reasonable trade for a room that lives for one game.
const int maxTargetImageEdge = 1024;

/// Every stored target is a PNG, whatever was uploaded.
const String targetImageMimeType = 'image/png';

/// An encoded raster and the dimensions of what it encodes, so a caller can
/// size or slice it without decoding it again.
class RasterImage {
  final Uint8List bytes;
  final int width;
  final int height;

  const RasterImage({
    required this.bytes,
    required this.width,
    required this.height,
  });
}

/// Brings an uploaded image into the one shape and format the rest of the
/// feature assumes, or returns null if it is not an image at all.
///
/// The result is centre-cropped to [aspectRatio] (cover, not contain),
/// downscaled so its longer edge is at most [maxTargetImageEdge], and encoded
/// as PNG. Normalizing the aspect here is what makes "region × dimensions" an
/// unconditional multiply everywhere downstream: a stored target whose shape
/// differed from the canvas would make every crop either distorted or padded,
/// and a player's reference would stop matching the area they draw in.
///
/// Cover rather than contain because losing the edges of the source is better
/// than blank bands inside a player's reference. Re-encoding also flattens
/// JPEG, WebP and animated GIF into one thing every client can render, and
/// drops the source's metadata on the way.
RasterImage? normalizeTargetImage(Uint8List bytes, double aspectRatio) {
  if (bytes.isEmpty || bytes.length > maxTargetImageBytes) return null;
  if (!aspectRatio.isFinite || aspectRatio <= 0) return null;

  // Anything that is not a decodable image — a text file, a truncated upload,
  // a payload wearing an image extension — fails here and is refused.
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) return null;

  final cropped = _centreCrop(decoded, aspectRatio);
  final bounded = _boundLongestEdge(cropped, maxTargetImageEdge);

  return RasterImage(
    bytes: Uint8List.fromList(img.encodePng(bounded)),
    width: bounded.width,
    height: bounded.height,
  );
}

/// Cuts the pixel rect that a normalized region names out of an already
/// normalized target.
///
/// The region is a fraction of the unit canvas and the target has the canvas's
/// aspect ratio, so this is a multiply: region `(0.5, 0, 0.5, 0.5)` of a
/// 1000 × 500 target is the 500 × 250 rect at (500, 0).
RasterImage? cropTargetImage(
  Uint8List bytes, {
  required double left,
  required double top,
  required double width,
  required double height,
}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  // A rect is rounded to whole pixels and then pulled back inside the image,
  // so rounding at the far edge of the canvas cannot ask for a pixel that is
  // not there. Every rect is at least one pixel each way.
  final x = (left * decoded.width).round().clamp(0, decoded.width - 1);
  final y = (top * decoded.height).round().clamp(0, decoded.height - 1);
  final w = (width * decoded.width).round().clamp(1, decoded.width - x);
  final h = (height * decoded.height).round().clamp(1, decoded.height - y);

  final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
  return RasterImage(
    bytes: Uint8List.fromList(img.encodePng(cropped)),
    width: cropped.width,
    height: cropped.height,
  );
}

/// The largest centred rect of the given aspect ratio that fits in [source].
img.Image _centreCrop(img.Image source, double aspectRatio) {
  final sourceRatio = source.width / source.height;
  final int width;
  final int height;
  if (sourceRatio > aspectRatio) {
    // Wider than wanted: keep the full height and trim the sides.
    height = source.height;
    width = (source.height * aspectRatio).round().clamp(1, source.width);
  } else {
    // Taller than wanted (or already right): keep the full width.
    width = source.width;
    height = (source.width / aspectRatio).round().clamp(1, source.height);
  }

  if (width == source.width && height == source.height) return source;

  return img.copyCrop(
    source,
    x: (source.width - width) ~/ 2,
    y: (source.height - height) ~/ 2,
    width: width,
    height: height,
  );
}

/// Scales [source] down so neither edge exceeds [bound], preserving the aspect
/// ratio the centre-crop just established. An image already inside the bound is
/// left alone rather than resampled for nothing.
img.Image _boundLongestEdge(img.Image source, int bound) {
  final longest = source.width > source.height ? source.width : source.height;
  if (longest <= bound) return source;

  return img.copyResize(
    source,
    width: source.width >= source.height ? bound : null,
    height: source.height > source.width ? bound : null,
    interpolation: img.Interpolation.average,
  );
}
