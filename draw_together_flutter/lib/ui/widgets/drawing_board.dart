import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
import 'package:draw_together_serverpod_client/draw_together_serverpod_client.dart';
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

    final paint = Paint()
      ..color = _activeTool.color
      ..strokeWidth = _activeTool.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = _activeTool.isEraser ? BlendMode.clear : BlendMode.srcOver;

    setState(() {
      _activeStroke = Stroke(
        id: strokeId,
        playerId: player.id!,
        points: [point],
        paint: paint,
        isEraser: _activeTool.isEraser,
      );
    });

    // Send the start message immediately
    _send(room.id!, player.id!, strokeId, 'start', [point]);
    _batchPoints.clear();

    // Start batching timer for updates
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final stroke = _activeStroke;
      if (_batchPoints.isNotEmpty && stroke != null) {
        _send(room.id!, player.id!, stroke.id, 'update', _batchPoints);
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

  void _endStroke(DragEndDetails details) {
    final room = ref.read(roomProvider);
    final player = ref.read(currentPlayerProvider);
    final stroke = _activeStroke;
    if (room == null || player == null || stroke == null) return;

    _batchTimer?.cancel();

    // Send the final end message
    _send(room.id!, player.id!, stroke.id, 'end', _batchPoints);

    // Save final local stroke
    ref.read(strokesProvider.notifier).addStroke(stroke);

    setState(() {
      _batchPoints.clear();
      _activeStroke = null;
    });
  }

  void _send(
    int roomId,
    int playerId,
    String strokeId,
    String action,
    List<Offset> points,
  ) {
    ref
        .read(webSocketServiceProvider)
        .sendMessage(
          StrokeSyncMsg(
            roomId: roomId,
            playerId: playerId,
            strokeId: strokeId,
            action: action,
            // Normalized canvas coordinates, clamped to the player's region.
            points: flatFromOffsets(points),
            colorInfo: _activeTool.colorInfo,
            strokeWidth: _activeTool.strokeWidth,
            isEraser: _activeTool.isEraser,
            timestamp: DateTime.now(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final strokes = ref.watch(strokesProvider);
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
              strokes: strokes,
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
            onPanEnd: _endStroke,
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
