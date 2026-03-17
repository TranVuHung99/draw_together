import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
import 'package:draw_together_serverpod_client/draw_together_serverpod_client.dart';
import '../../models/stroke.dart';
import '../../providers/game_providers.dart';
import '../../providers/controllers/websocket_service.dart';
import 'drawing_painter.dart';

class DrawingBoard extends ConsumerStatefulWidget {
  const DrawingBoard({super.key});

  @override
  ConsumerState<DrawingBoard> createState() => _DrawingBoardState();
}

class _DrawingBoardState extends ConsumerState<DrawingBoard> {
  Stroke? _activeStroke;
  final List<double> _batchPoints = [];
  Timer? _batchTimer;
  Color _myColor = Colors.black;
  double _myStrokeWidth = 5.0;
  bool _isEraser = false;

  @override
  void initState() {
    super.initState();
    // Initialize color from player's assigned color if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = ref.read(currentPlayerProvider);
      if (player?.colorInfo != null) {
        setState(() {
          _myColor = Color(int.parse(player!.colorInfo!));
        });
      }
    });
  }

  @override
  void dispose() {
    _batchTimer?.cancel();
    super.dispose();
  }

  void _startStroke(DragStartDetails details) {
    final room = ref.read(roomProvider);
    final player = ref.read(currentPlayerProvider);
    if (room == null || player == null) return;

    final strokeId = _generateUuid();
    final localPos = details.localPosition;

    final paint = Paint()
      ..color = _myColor
      ..strokeWidth = _myStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = _isEraser ? BlendMode.clear : BlendMode.srcOver;

    final path = Path()..moveTo(localPos.dx, localPos.dy);

    setState(() {
      _activeStroke = Stroke(
        id: strokeId,
        playerId: player.id!,
        path: path,
        paint: paint,
        isEraser: _isEraser,
      );
    });

    _batchPoints.addAll([localPos.dx, localPos.dy]);

    // Send the start message immediately
    ref
        .read(webSocketServiceProvider)
        .sendMessage(
          StrokeSyncMsg(
            roomId: room.id!,
            playerId: player.id!,
            strokeId: strokeId,
            action: 'start',
            points: List.from(_batchPoints),
            colorInfo: '0x${_myColor.value.toRadixString(16).padLeft(8, '0')}',
            strokeWidth: _myStrokeWidth,
            isEraser: _isEraser,
            timestamp: DateTime.now(),
          ),
        );

    _batchPoints.clear();

    // Start batching timer for updates
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_batchPoints.isNotEmpty && _activeStroke != null) {
        ref
            .read(webSocketServiceProvider)
            .sendMessage(
              StrokeSyncMsg(
                roomId: room.id!,
                playerId: player.id!,
                strokeId: _activeStroke!.id,
                action: 'update',
                points: List.from(_batchPoints),
                colorInfo:
                    '0x${_myColor.value.toRadixString(16).padLeft(8, '0')}',
                strokeWidth: _myStrokeWidth,
                isEraser: _isEraser,
                timestamp: DateTime.now(),
              ),
            );
        _batchPoints.clear();
      }
    });
  }

  void _updateStroke(DragUpdateDetails details) {
    if (_activeStroke == null) return;

    final localPos = details.localPosition;
    setState(() {
      _activeStroke!.path.lineTo(localPos.dx, localPos.dy);
    });

    _batchPoints.addAll([localPos.dx, localPos.dy]);
  }

  void _endStroke(DragEndDetails details) {
    final room = ref.read(roomProvider);
    final player = ref.read(currentPlayerProvider);
    if (room == null || player == null || _activeStroke == null) return;

    _batchTimer?.cancel();

    // Send the final end message
    ref
        .read(webSocketServiceProvider)
        .sendMessage(
          StrokeSyncMsg(
            roomId: room.id!,
            playerId: player.id!,
            strokeId: _activeStroke!.id,
            action: 'end',
            points: List.from(_batchPoints),
            colorInfo: '0x${_myColor.value.toRadixString(16).padLeft(8, '0')}',
            strokeWidth: _myStrokeWidth,
            isEraser: _isEraser,
            timestamp: DateTime.now(),
          ),
        );

    // Save final local stroke
    ref.read(strokesProvider.notifier).addStroke(_activeStroke!);

    setState(() {
      _batchPoints.clear();
      _activeStroke = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strokes = ref.watch(strokesProvider);

    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: GestureDetector(
            onPanStart: _startStroke,
            onPanUpdate: _updateStroke,
            onPanEnd: _endStroke,
            child: Container(
              color: Colors.white, // Canvas background
              child: CustomPaint(
                size: Size.infinite,
                painter: DrawingPainter(
                  strokes: strokes,
                  currentStroke: _activeStroke,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              Icons.edit,
              color: _isEraser ? Colors.grey : Colors.blue,
            ),
            onPressed: () => setState(() => _isEraser = false),
            tooltip: 'Draw',
          ),
          IconButton(
            icon: Icon(
              Icons.phonelink_erase,
              color: _isEraser ? Colors.blue : Colors.grey,
            ),
            onPressed: () => setState(() => _isEraser = true),
            tooltip: 'Eraser',
          ),
          Slider(
            value: _myStrokeWidth,
            min: 1,
            max: 20,
            onChanged: (val) => setState(() => _myStrokeWidth = val),
            activeColor: Colors.blue,
          ),
          // Basic color picker
          DropdownButton<Color>(
            value: _myColor,
            items:
                [
                  Colors.black,
                  Colors.red,
                  Colors.green,
                  Colors.blue,
                  Colors.yellow,
                  Colors.orange,
                  Colors.purple,
                ].map((Color color) {
                  return DropdownMenuItem<Color>(
                    value: color,
                    child: Container(width: 24, height: 24, color: color),
                  );
                }).toList(),
            onChanged: (Color? newValue) {
              setState(() {
                _myColor = newValue!;
                _isEraser = false; // Switch off eraser if picking color
              });
            },
          ),
        ],
      ),
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
