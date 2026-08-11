import 'dart:ui';

/// Maps a rect of normalized canvas space onto the widget area it is painted
/// into.
///
/// Canvas coordinates run 0.0 to 1.0 on both axes, `(0, 0)` being the canvas
/// top-left. Every view in the game is one of these: the host and a spectating
/// player see [fullCanvas], a drawing player in draw mode sees their own
/// region.
///
/// The viewport keeps its own aspect ratio — it is letterboxed inside the
/// available area rather than stretched. Without that, a region shaped
/// differently from the widget would distort the strokes inside it, and a
/// circle drawn in draw mode would show up as an ellipse on the full-canvas
/// views.
class CanvasViewport {
  /// The part of the canvas on show, in normalized coordinates.
  final Rect viewport;

  /// Where [viewport] lands in widget coordinates.
  final Rect destination;

  const CanvasViewport({required this.viewport, required this.destination});

  /// The whole canvas.
  static const Rect fullCanvas = Rect.fromLTWH(0, 0, 1, 1);

  /// Letterboxes [viewport] into [available], centred.
  ///
  /// [canvasAspectRatio] is the full canvas's width / height: the viewport's
  /// on-screen shape depends on it, since a region 1/3 wide and 1/2 tall of a
  /// square canvas is 2:3, not 1:1.
  factory CanvasViewport.fit({
    required Rect viewport,
    required Size available,
    required double canvasAspectRatio,
  }) {
    final aspect =
        (viewport.width <= 0 || viewport.height <= 0 || canvasAspectRatio <= 0)
        ? 1.0
        : (viewport.width * canvasAspectRatio) / viewport.height;

    var width = available.width;
    var height = width / aspect;
    if (height > available.height) {
      height = available.height;
      width = height * aspect;
    }

    return CanvasViewport(
      viewport: viewport,
      destination: Rect.fromLTWH(
        (available.width - width) / 2,
        (available.height - height) / 2,
        width,
        height,
      ),
    );
  }

  double get scaleX =>
      viewport.width == 0 ? 0 : destination.width / viewport.width;

  double get scaleY =>
      viewport.height == 0 ? 0 : destination.height / viewport.height;

  /// Normalized canvas point to widget point.
  Offset toWidget(Offset point) => Offset(
    destination.left + (point.dx - viewport.left) * scaleX,
    destination.top + (point.dy - viewport.top) * scaleY,
  );

  /// Widget point to normalized canvas point — the inverse of [toWidget].
  Offset toCanvas(Offset point) => Offset(
    scaleX == 0
        ? viewport.left
        : viewport.left + (point.dx - destination.left) / scaleX,
    scaleY == 0
        ? viewport.top
        : viewport.top + (point.dy - destination.top) / scaleY,
  );

  /// Widget-space rect for a rect of normalized canvas space.
  Rect toWidgetRect(Rect rect) =>
      Rect.fromPoints(toWidget(rect.topLeft), toWidget(rect.bottomRight));

  /// Whether a widget point lands on the canvas rather than in the letterboxed
  /// dead space around it.
  bool containsWidgetPoint(Offset point) => destination.contains(point);

  @override
  bool operator ==(Object other) =>
      other is CanvasViewport &&
      other.viewport == viewport &&
      other.destination == destination;

  @override
  int get hashCode => Object.hash(viewport, destination);
}
