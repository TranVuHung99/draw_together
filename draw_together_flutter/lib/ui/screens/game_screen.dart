import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../core/serverpod_client.dart';
import '../../providers/game_providers.dart';
import '../../providers/controllers/target_image_controller.dart';
import '../widgets/canvas_overlays.dart';
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
      // Entering a game already in progress — a reconnect, or a client that
      // missed the PLAYING broadcast — still needs its reference. Asking for
      // it here as well as on the transition is what makes the fetch
      // independent of having observed one.
      final status = ref.read(roomProvider)?.status;
      if (status == 'PLAYING' || status == 'PAUSED') {
        ref.read(targetImageControllerProvider).load();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _pause() async {
    final ids = _roomAndPlayer();
    if (ids == null) return;
    await client.room.pauseGame(ids.$1, ids.$2);
  }

  Future<void> _resume() async {
    final ids = _roomAndPlayer();
    if (ids == null) return;
    await client.room.resumeGame(ids.$1, ids.$2);
  }

  /// Ending the round early is not undoable, so it is confirmed first.
  Future<void> _stop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End the game now?'),
        content: const Text(
          'The canvas is finalized as it stands and everyone goes to the '
          'result screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End game'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ids = _roomAndPlayer();
    if (ids == null) return;
    await client.room.stopGame(ids.$1, ids.$2);
  }

  /// The room and the caller, or null if either is missing. The player id is
  /// what proves to the server that the host is the one asking.
  (int, int)? _roomAndPlayer() {
    final roomId = ref.read(roomProvider)?.id;
    final playerId = ref.read(currentPlayerProvider)?.id;
    if (roomId == null || playerId == null) return null;
    return (roomId, playerId);
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider);
    final player = ref.watch(currentPlayerProvider);
    final canDraw = ref.watch(canDrawProvider);
    final spectating = ref.watch(viewGlobalCanvasProvider);
    final isHost = ref.watch(isHostProvider);
    final isPaused = ref.watch(isPausedProvider);
    final showOwnership = ref.watch(showOwnershipOverlayProvider);
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

    // Derived from the room's deadline while playing and from the banked
    // remainder while paused, so a client that joins mid-game shows the time
    // that is actually left and a paused clock does not move.
    final timeLeft = remainingSeconds(room) ?? 0;
    final String timeStr =
        '${(timeLeft ~/ 60).toString().padLeft(2, '0')}:${(timeLeft % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Draw Together - $timeStr'),
        automaticallyImplyLeading: false,
        actions: [
          // The overlay is only ever on the host's full-canvas view, so the
          // toggle appears exactly where it can do something.
          if (isHost)
            IconButton(
              icon: Icon(
                ref.watch(showOwnershipProvider)
                    ? Icons.label
                    : Icons.label_off_outlined,
              ),
              tooltip: 'Show who owns each region',
              onPressed: () =>
                  ref.read(showOwnershipProvider.notifier).toggle(),
            ),
          // Each session control is offered only in the state where it is
          // valid, so the host is never shown a button the server would refuse.
          if (isHost && room.status == 'PLAYING')
            IconButton(
              icon: const Icon(Icons.pause),
              tooltip: 'Pause the game',
              onPressed: _pause,
            ),
          if (isHost && room.status == 'PAUSED')
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Resume the game',
              onPressed: _resume,
            ),
          if (isHost &&
              (room.status == 'PLAYING' || room.status == 'PAUSED'))
            IconButton(
              icon: const Icon(Icons.stop),
              tooltip: 'End the game now',
              onPressed: _stop,
            ),
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
          // Everyone sees the pause, not just the host, so a canvas that has
          // gone read-only is never unexplained.
          if (isPaused)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.tertiaryContainer,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 8,
                children: [
                  const Icon(Icons.pause_circle_outline, size: 18),
                  Text(
                    'Paused by the host — $timeStr left',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          // The toolbar is a sibling of the canvas and goes away whenever input
          // is not accepted.
          if (canDraw) const DrawingToolbar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              // The canvas and the two non-artwork layers above it. Both
              // overlays are siblings of DrawingBoard rather than layers
              // inside it, so neither can reach the composite and neither can
              // start a stroke.
              child: Stack(
                children: [
                  const Positioned.fill(child: DrawingBoard()),
                  if (showOwnership)
                    const Positioned.fill(child: RegionOwnershipOverlay()),
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: TargetImageThumbnail(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
