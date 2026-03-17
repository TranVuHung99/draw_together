import 'package:draw_together_flutter/ui/widgets/drawing_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/game_providers.dart';
import 'package:draw_together_serverpod_client/draw_together_serverpod_client.dart';

class TestDrawingScreen extends ConsumerStatefulWidget {
  const TestDrawingScreen({super.key});

  @override
  ConsumerState<TestDrawingScreen> createState() => _TestDrawingScreenState();
}

class _TestDrawingScreenState extends ConsumerState<TestDrawingScreen> {
  @override
  void initState() {
    super.initState();
    // Inject mock player and room data so DrawingBoard doesn't return null
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(roomProvider.notifier)
          .set(
            Room(
              id: 1,
              roomCode: 'TEST',
              hostId: 1,
              status: 'PLAYING',
              canvasWidth: 800,
              canvasHeight: 600,
            ),
          );

      ref
          .read(currentPlayerProvider.notifier)
          .set(
            Player(
              id: 1,
              roomId: 1,
              name: 'Tester',
              colorInfo: '0xFFFF0000',
              regionX: 0,
              regionY: 0,
              regionWidth: 800,
              regionHeight: 600,
            ),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Draw Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              ref.read(strokesProvider.notifier).clear();
            },
            tooltip: 'Clear Canvas',
          ),
        ],
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: 800 / 600,
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
            child: ClipRect(child: const DrawingBoard()),
          ),
        ),
      ),
    );
  }
}
