import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../providers/game_providers.dart';
import '../widgets/drawing_board.dart';
import '../widgets/drawing_toolbar.dart';
import 'final_result_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // The countdown is presentational: it ticks so the display refreshes, and
    // the remaining time is read from the room's server-set deadline each time.
    // Reaching zero finalizes nothing — the server owns the end of the game and
    // announces it with `GameStateChangeMsg(FINISHED)`.
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // Drawing players start in draw mode, whatever a previous round left behind.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(viewGlobalCanvasProvider.notifier).set(false);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider);
    final player = ref.watch(currentPlayerProvider);
    final canDraw = ref.watch(canDrawProvider);
    final spectating = ref.watch(viewGlobalCanvasProvider);
    // A player with a region draws and so has two modes to switch between; the
    // host has only the full-canvas observer view.
    final canSwitchMode = ref.watch(localRegionProvider) != null;

    // Listen for the final composite to navigate
    ref.listen(finalCanvasSvgProvider, (previous, next) {
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

    // Derived from the room's deadline rather than counted down locally, so a
    // client that joins mid-game shows the time that is actually left.
    final timeLeft = remainingSeconds(room) ?? 0;
    final String timeStr =
        '${(timeLeft ~/ 60).toString().padLeft(2, '0')}:${(timeLeft % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Draw Together - $timeStr'),
        automaticallyImplyLeading: false,
        actions: [
          if (canSwitchMode)
            IconButton(
              icon: Icon(spectating ? Icons.brush : Icons.grid_view),
              tooltip: spectating ? 'Back to my region' : 'View whole canvas',
              onPressed: () =>
                  ref.read(viewGlobalCanvasProvider.notifier).toggle(),
            ),
        ],
      ),
      body: Column(
        children: [
          // The toolbar is a sibling of the canvas and goes away whenever input
          // is not accepted.
          if (canDraw) const DrawingToolbar(),
          const Expanded(
            child: Padding(padding: EdgeInsets.all(8.0), child: DrawingBoard()),
          ),
        ],
      ),
    );
  }
}
