import 'package:draw_together_flutter/ui/widgets/drawing_board.dart';
import 'package:draw_together_flutter/ui/widgets/drawing_toolbar.dart';
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
              // The whole canvas, in normalized coordinates.
              regionX: 0,
              regionY: 0,
              regionWidth: 1,
              regionHeight: 1,
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
      // The board letterboxes its own viewport, so it just needs the space.
      body: const Column(
        children: [
          DrawingToolbar(),
          Expanded(
            child: Padding(padding: EdgeInsets.all(8), child: DrawingBoard()),
          ),
        ],
      ),
    );
  }
}
