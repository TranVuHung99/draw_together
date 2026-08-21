import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
// The generated `Stroke` is the server's table row; the canvas works with the
// local painting model of the same name.
import 'package:draw_together_serverpod_client/draw_together_serverpod_client.dart'
    hide Stroke;
import '../../models/canvas_viewport.dart';
import '../../models/stroke.dart';
import '../../providers/game_providers.dart';
import '../../providers/tool_providers.dart';
import '../../providers/controllers/websocket_service.dart';
import 'drawing_painter.dart';

/// The canvas: one painter and one gesture layer, both driven by the current
/// viewport.
///
/// The viewport is the local player's region in draw mode and the whole canvas
/// for the host and for a spectating player. Input is only wired up when
/// [canDrawProvider] says so.
class DrawingBoard extends ConsumerStatefulWidget {
  const DrawingBoard({super.key});

  @override
  ConsumerState<DrawingBoard> createState() => _DrawingBoardState();
}

class _DrawingBoardState extends ConsumerState<DrawingBoard> {
  Stroke? _activeStroke;

  /// Normalized points drawn since the last batch was sent.
  final List<Offset> _batchPoints = [];
  Timer? _batchTimer;

  /// The tool as it was when the active stroke began, so changing tools
  /// mid-stroke cannot alter what has already been drawn.
  DrawingTool _activeTool = const DrawingTool();

  /// The active tool's width as a fraction of the canvas width.
  ///
  /// The slider is in pixels of the room's configured canvas, so the width
  /// travels normalized alongside the points and means the same thing on every
  /// screen, in the server's SVG, and in an export.
  double _normalizedStrokeWidth(Room room) => room.canvasWidth <= 0
      ? _activeTool.strokeWidth
      : _activeTool.strokeWidth / room.canvasWidth;

  @override
  void initState() {
    super.initState();
    // Start on the player's assigned colour if they have one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final colorInfo = ref.read(currentPlayerProvider)?.colorInfo;
      if (colorInfo != null) {
        ref
            .read(drawingToolProvider.notifier)
            .setColor(Color(int.parse(colorInfo)));
      }
    });
  }

  @override
  void dispose() {
    _batchTimer?.cancel();
    super.dispose();
  }

  Offset _clampToRegion(Offset point, Rect region) => Offset(
    point.dx.clamp(region.left, region.right),
    point.dy.clamp(region.top, region.bottom),
  );

  void _startStroke(DragStartDetails details, CanvasViewport viewport) {
    final room = ref.read(roomProvider);
    final player = ref.read(currentPlayerProvider);
    final region = ref.read(localRegionProvider);
    if (room == null || player == null || region == null) return;

    // A press in the letterboxed dead space is not a press on the canvas.
    if (!viewport.containsWidgetPoint(details.localPosition)) return;

    final strokeId = _generateUuid();
    final point = _clampToRegion(
      viewport.toCanvas(details.localPosition),
      region,
    );
    _activeTool = ref.read(drawingToolProvider);

    setState(() {
      _activeStroke = Stroke(
        id: strokeId,
        playerId: player.id!,
        points: [point],
        color: _activeTool.color,
        strokeWidth: _normalizedStrokeWidth(room),
        isEraser: _activeTool.isEraser,
      );
    });
    // Undo is unavailable until this stroke is finished.
    ref.read(strokeInProgressProvider.notifier).set(true);

    // Send the start message immediately
    _send(room, player.id!, strokeId, 'start', [point]);
    _batchPoints.clear();

    // Start batching timer for updates
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final stroke = _activeStroke;
      if (_batchPoints.isNotEmpty && stroke != null) {
        _send(room, player.id!, stroke.id, 'update', _batchPoints);
        _batchPoints.clear();
      }
    });
  }

  void _updateStroke(DragUpdateDetails details, CanvasViewport viewport) {
    final stroke = _activeStroke;
    final region = ref.read(localRegionProvider);
    if (stroke == null || region == null) return;

    // Dragging past the region edge keeps the stroke going, pinned to the
    // boundary, rather than ending it.
    final point = _clampToRegion(
      viewport.toCanvas(details.localPosition),
      region,
    );

    setState(() {
      stroke.add(point);
    });

    _batchPoints.add(point);
  }

  /// Finishes the stroke in progress. A cancelled drag ends the same way as a
  /// released one, so a stroke other clients have already seen start is never
  /// left open.
  void _endStroke() {
    final room = ref.read(roomProvider);
    final player = ref.read(currentPlayerProvider);
    final stroke = _activeStroke;
    if (room == null || player == null || stroke == null) return;

    _batchTimer?.cancel();

    // The end message carries the whole stroke, not just the unsent tail: it
    // is what the server persists, and what it replays to a client that joins
    // or reconnects later.
    _send(room, player.id!, stroke.id, 'end', stroke.points);

    // Save final local stroke — the server does not echo it back.
    ref.read(strokesProvider.notifier).addStroke(stroke);
    ref.read(strokeInProgressProvider.notifier).set(false);

    setState(() {
      _batchPoints.clear();
      _activeStroke = null;
    });
  }

  void _send(
    Room room,
    int playerId,
    String strokeId,
    String action,
    List<Offset> points,
  ) {
    ref
        .read(webSocketServiceProvider)
        .sendMessage(
          StrokeSyncMsg(
            roomId: room.id!,
            playerId: playerId,
            strokeId: strokeId,
            action: action,
            // Normalized canvas coordinates, clamped to the player's region.
            points: flatFromOffsets(points),
            colorInfo: _activeTool.colorInfo,
            strokeWidth: _normalizedStrokeWidth(room),
            isEraser: _activeTool.isEraser,
            timestamp: DateTime.now(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(strokesProvider);
    final regions = ref.watch(playerRegionsProvider);
    final room = ref.watch(roomProvider);
    final canDraw = ref.watch(canDrawProvider);
    final viewportRect = ref.watch(viewportRectProvider);
    final players = ref.watch(playersProvider);
    final currentPlayer = ref.watch(currentPlayerProvider);

    final canvasAspectRatio = (room == null || room.canvasHeight == 0)
        ? 1.0
        : room.canvasWidth / room.canvasHeight;

    final showsWholeCanvas = viewportRect == CanvasViewport.fullCanvas;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = CanvasViewport.fit(
          viewport: viewportRect,
          available: Size(constraints.maxWidth, constraints.maxHeight),
          canvasAspectRatio: canvasAspectRatio,
        );

        final layers = <Widget>[
          CustomPaint(
            size: Size.infinite,
            painter: DrawingPainter(
              board: board,
              regions: regions,
              currentStroke: _activeStroke,
              viewport: viewport,
            ),
          ),
        ];

        if (showsWholeCanvas) {
          final outlines = <RegionOutline>[];
          for (final player in players) {
            final region = regionOf(player);
            // Unassigned cells are not outlined: an unassigned cell has no
            // player, so there is nothing here to iterate over for it.
            if (region == null) continue;
            outlines.add(
              RegionOutline(
                region: region,
                isOwn: player.id == currentPlayer?.id,
              ),
            );
          }
          layers.add(
            CustomPaint(
              size: Size.infinite,
              painter: RegionOutlinePainter(
                outlines: outlines,
                viewport: viewport,
              ),
            ),
          );
        }

        Widget canvas = Stack(fit: StackFit.expand, children: layers);

        if (canDraw) {
          canvas = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => _startStroke(details, viewport),
            onPanUpdate: (details) => _updateStroke(details, viewport),
            onPanEnd: (details) => _endStroke(),
            onPanCancel: _endStroke,
            child: canvas,
          );
        }

        return canvas;
      },
    );
  }

  String _generateUuid() {
    final random = Random();
    final parts = [
      random.nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0'),
      random.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0'),
      random.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0'),
      random.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0'),
      random.nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0') +
          random.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0'),
    ];
    return parts.join('-');
  }
}
