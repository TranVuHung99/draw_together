import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/png_download.dart';
import '../../providers/game_providers.dart';
import '../../providers/controllers/target_image_controller.dart';
import '../../providers/controllers/websocket_service.dart';
import 'lobby_screen.dart';

/// Shows the composite the server generated, as the SVG document it sent.
///
/// The SVG is the artifact; a PNG is only produced when a player asks for one,
/// so nothing is rasterized just to put the picture on screen.
class FinalResultScreen extends ConsumerStatefulWidget {
  const FinalResultScreen({super.key});

  @override
  ConsumerState<FinalResultScreen> createState() => _FinalResultScreenState();
}

class _FinalResultScreenState extends ConsumerState<FinalResultScreen> {
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    // A drawing player only ever held their own crop, so the reveal is a fresh
    // fetch of the full image rather than something already on this client.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(targetImageControllerProvider).loadReveal();
    });
  }

  @override
  Widget build(BuildContext context) {
    final svg = ref.watch(finalCanvasSvgProvider);
    final room = ref.watch(roomProvider);
    // Null when the room had no target, or when the reveal could not be
    // fetched — either way the composite is shown alone.
    final target = ref.watch(revealedTargetProvider);

    // The SVG is authored in a unit square, so the room's canvas size is what
    // gives it back its shape — the same mapping the live canvas used.
    final canvasSize = Size(room?.canvasWidth ?? 1, room?.canvasHeight ?? 1);
    final aspectRatio = canvasSize.height <= 0
        ? 1.0
        : canvasSize.width / canvasSize.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Final Masterpiece'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (svg != null)
              // The target beside what everyone made of it. A room that had
              // none — or a reveal that could not be fetched — simply shows
              // the composite alone, which is the whole screen as it was.
              Flexible(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 24,
                  children: [
                    Flexible(
                      child: _labelled(
                        'The canvas',
                        AspectRatio(
                          aspectRatio: aspectRatio,
                          child: SvgPicture.string(svg, fit: BoxFit.fill),
                        ),
                      ),
                    ),
                    if (target != null)
                      Flexible(
                        child: _labelled(
                          'The target',
                          AspectRatio(
                            aspectRatio: aspectRatio,
                            child: Image.memory(target, fit: BoxFit.fill),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              const CircularProgressIndicator(),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 16,
              children: [
                ElevatedButton.icon(
                  onPressed: (svg == null || _exporting)
                      ? null
                      : () => _exportPng(svg, canvasSize),
                  icon: _exporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: const Text('Download PNG'),
                ),
                ElevatedButton(
                  onPressed: _backToLobby,
                  child: const Text('Back to Lobby'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _labelled(String label, Widget child) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      Flexible(
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
          child: child,
        ),
      ),
    ],
  );

  /// Rasterizes the SVG at the room's configured canvas resolution.
  ///
  /// This rasterizes the composite document alone — never the widget tree — so
  /// the export contains only strokes: no overlay borders, no owner names, and
  /// no part of the reference image. This is the only place a PNG is ever
  /// produced.
  Future<void> _exportPng(String svg, Size canvasSize) async {
    setState(() => _exporting = true);
    try {
      final pictureInfo = await vg.loadPicture(SvgStringLoader(svg), null);
      final ui.Image image;
      try {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        // The document is a unit square, so this is the scale that takes it to
        // the room's pixels — per axis, exactly as the canvas maps it.
        canvas.scale(
          canvasSize.width / (pictureInfo.size.width),
          canvasSize.height / (pictureInfo.size.height),
        );
        canvas.drawPicture(pictureInfo.picture);
        final picture = recorder.endRecording();
        image = await picture.toImage(
          canvasSize.width.round(),
          canvasSize.height.round(),
        );
        picture.dispose();
      } finally {
        pictureInfo.picture.dispose();
      }

      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('The canvas produced no PNG data');

      final roomCode = ref.read(roomProvider)?.roomCode ?? 'canvas';
      final destination = await downloadPng(
        data.buffer.asUint8List(),
        'draw_together_$roomCode.png',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved $destination')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _backToLobby() {
    // Leaving the room is the one thing that stops the reconnect loop short of
    // disposing the service: a dropped stream is worth re-establishing, a
    // departure is not.
    ref.read(webSocketServiceProvider).disconnect();

    // Clear state
    ref.read(strokesProvider.notifier).clear();
    ref.read(pendingStrokesProvider.notifier).clear();
    ref.read(strokeRejectionProvider.notifier).set(null);
    ref.read(rosterRefreshFailedProvider.notifier).set(false);
    ref.read(finalCanvasSvgProvider.notifier).set(null);
    ref.read(targetImageProvider.notifier).clear();
    ref.read(revealedTargetProvider.notifier).set(null);
    ref.read(roomProvider.notifier).set(null);
    ref.read(currentPlayerProvider.notifier).set(null);
    ref.read(playersProvider.notifier).set([]);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LobbyScreen()),
    );
  }
}
