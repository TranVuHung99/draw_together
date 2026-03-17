import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:draw_together_serverpod_client/draw_together_serverpod_client.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import '../../providers/game_providers.dart';
import '../../providers/controllers/websocket_service.dart';
import '../widgets/drawing_board.dart';
import '../widgets/drawing_painter.dart';
import 'final_result_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  Timer? _countdownTimer;
  int _timeLeft = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    final room = ref.read(roomProvider);
    if (room?.endTime != null) {
      _timeLeft = room!.endTime!.difference(DateTime.now()).inSeconds;
      if (_timeLeft < 0) _timeLeft = 0;

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _timeLeft--;
          if (_timeLeft <= 0) {
            _timeLeft = 0;
            timer.cancel();
            _handleGameEnd();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleGameEnd() async {
    final room = ref.read(roomProvider);
    final player = ref.read(currentPlayerProvider);

    // Only the host triggers the composite rendering
    if (room != null && player != null && room.hostId == player.id) {
      await _generateAndBroadcastFinalImage();
    }
  }

  Future<void> _generateAndBroadcastFinalImage() async {
    final strokes = ref.read(strokesProvider);
    final room = ref.read(roomProvider)!;

    // We can use a PictureRecorder to record all strokes, then toImage, then base64
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(room.canvasWidth, room.canvasHeight);

    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // Re-use the DrawingPainter
    final painter = DrawingPainter(strokes: strokes);
    painter.paint(canvas, size);

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final base64String = base64Encode(byteData.buffer.asUint8List());

      // Broadcast it!
      ref
          .read(webSocketServiceProvider)
          .sendMessage(
            FinalCanvasMsg(roomId: room.id!, base64Image: base64String),
          );
      // Wait, our sendStroke expects StrokeSyncMsg. Let's add a proper send call if we can.
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider);
    final player = ref.watch(currentPlayerProvider);

    // Listen for the final image to navigate
    ref.listen(finalImageBase64Provider, (previous, next) {
      if (next != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FinalResultScreen()),
        );
      }
    });

    if (room == null || player == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final String timeStr =
        '${(_timeLeft ~/ 60).toString().padLeft(2, '0')}:${(_timeLeft % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Draw Together - $timeStr'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: room.canvasWidth / room.canvasHeight,
          child: Stack(
            children: [
              // Show the entire canvas (other people's strokes)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: DrawingPainter(strokes: ref.watch(strokesProvider)),
                ),
              ),
              // Overlay the player's active drawing bounding box
              Positioned(
                left: player.regionX,
                top: player.regionY,
                width: player.regionWidth,
                height: player.regionHeight,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueAccent, width: 2),
                  ),
                  child: ClipRect(
                    child: Transform.translate(
                      offset: Offset(-player.regionX, -player.regionY),
                      child: const DrawingBoard(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
