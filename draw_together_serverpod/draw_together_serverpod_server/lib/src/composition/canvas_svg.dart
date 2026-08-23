import '../generated/protocol.dart';

/// Builds the final composite as an SVG document.
///
/// The stroke model maps onto SVG one-to-one, so this is pure string building
/// with no dependency and no rasterization. The document is authored in the
/// normalized unit square the strokes already live in, and stretched to the
/// room's configured pixel size by `preserveAspectRatio="none"`, which is the
/// same mapping the live canvas applies.
///
/// The composition rules are the ones `DrawingPainter` uses on the client, so
/// the artifact and the canvas players watched being drawn agree by
/// construction:
///
/// - one group per drawing player, clipped to that player's region,
/// - groups composited in ascending player id order,
/// - strokes painted in ascending sequence within a group,
/// - an eraser masking only what its owner drew before it.
String composeCanvasSvg({
  required Room room,
  required List<Player> players,
  required List<Stroke> strokes,
}) {
  // Strokes arrive in ascending sequence and this preserves that order within
  // each player, which is the paint order inside a layer.
  final byPlayer = <int, List<Stroke>>{};
  for (final stroke in strokes) {
    (byPlayer[stroke.playerId] ??= <Stroke>[]).add(stroke);
  }

  final regions = <int, _Region>{};
  for (final player in players) {
    final region = _Region.of(player);
    if (player.id != null && region != null) regions[player.id!] = region;
  }

  // The host owns no region and so contributes no layer.
  final layerOwners = byPlayer.keys.where(regions.containsKey).toList()..sort();

  final defs = StringBuffer();
  final body = StringBuffer();

  for (final playerId in layerOwners) {
    final region = regions[playerId]!;
    final clipId = 'clip$playerId';
    defs.write(
      '<clipPath id="$clipId" clipPathUnits="userSpaceOnUse">'
      '<rect x="${_n(region.left)}" y="${_n(region.top)}" '
      'width="${_n(region.width)}" height="${_n(region.height)}"/>'
      '</clipPath>',
    );

    // An eraser removes what was drawn before it and leaves what comes after
    // untouched, so each eraser wraps the content so far rather than masking
    // the whole layer.
    var layer = StringBuffer();
    for (final stroke in byPlayer[playerId]!) {
      if (stroke.isEraser) {
        final maskId = 'mask${stroke.id}';
        defs.write(
          '<mask id="$maskId" maskUnits="userSpaceOnUse" '
          'x="0" y="0" width="1" height="1">'
          '<rect x="0" y="0" width="1" height="1" fill="#ffffff"/>'
          '${_polyline(stroke, color: '#000000', opacity: 1)}'
          '</mask>',
        );
        final masked = '<g mask="url(#$maskId)">$layer</g>';
        layer = StringBuffer(masked);
      } else {
        final color = _Color.parse(stroke.colorInfo);
        layer.write(
          _polyline(stroke, color: color.hex, opacity: color.opacity),
        );
      }
    }

    body.write('<g clip-path="url(#$clipId)">$layer</g>');
  }

  return '<svg xmlns="http://www.w3.org/2000/svg" '
      'width="${_n(room.canvasWidth)}" height="${_n(room.canvasHeight)}" '
      'viewBox="0 0 1 1" preserveAspectRatio="none">'
      '<rect x="0" y="0" width="1" height="1" fill="#ffffff"/>'
      '${defs.isEmpty ? '' : '<defs>$defs</defs>'}'
      '$body'
      '</svg>';
}

String _polyline(
  Stroke stroke, {
  required String color,
  required double opacity,
}) {
  final points = StringBuffer();
  for (var i = 0; i + 1 < stroke.points.length; i += 2) {
    if (points.isNotEmpty) points.write(' ');
    points.write('${_n(stroke.points[i])},${_n(stroke.points[i + 1])}');
  }
  if (points.isEmpty) return '';

  // A tap without a drag is one point; SVG draws nothing for a lone moveto, so
  // it is repeated to leave the round dot the live canvas leaves.
  if (stroke.points.length == 2) {
    points.write(' ${_n(stroke.points[0])},${_n(stroke.points[1])}');
  }

  final alpha = opacity >= 1 ? '' : ' stroke-opacity="${_n(opacity)}"';
  return '<polyline points="$points" fill="none" stroke="$color"'
      ' stroke-width="${_n(stroke.strokeWidth)}"$alpha'
      ' stroke-linecap="round" stroke-linejoin="round"/>';
}

/// Formats a number for the document: fixed notation, no exponent, no trailing
/// zeros. Everything written into the SVG goes through here or through a
/// parsed colour, so no client-supplied string is ever interpolated raw.
String _n(double value) {
  if (!value.isFinite) return '0';
  if (value == value.roundToDouble() && value.abs() < 1e9) {
    return value.toInt().toString();
  }
  var text = value.toStringAsFixed(6);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);
  }
  return text.isEmpty ? '0' : text;
}

/// A stroke colour, read from the `0xAARRGGBB` wire form.
class _Color {
  final String hex;
  final double opacity;

  const _Color(this.hex, this.opacity);

  static _Color parse(String colorInfo) {
    final argb = int.tryParse(colorInfo);
    // An unparseable colour is drawn black rather than dropped: the stroke was
    // on the canvas, so it belongs in the composite.
    if (argb == null) return const _Color('#000000', 1);
    final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return _Color('#$rgb', ((argb >> 24) & 0xFF) / 255);
  }
}

/// A player's assigned region, in normalized canvas coordinates (0.0 - 1.0).
class _Region {
  final double left;
  final double top;
  final double width;
  final double height;

  const _Region(this.left, this.top, this.width, this.height);

  static _Region? of(Player player) {
    final x = player.regionX;
    final y = player.regionY;
    final width = player.regionWidth;
    final height = player.regionHeight;
    if (x == null || y == null || width == null || height == null) return null;
    return _Region(x, y, width, height);
  }
}
