import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/canvas_viewport.dart';
import '../../providers/game_providers.dart';
import '../../providers/controllers/target_image_controller.dart';
import 'drawing_painter.dart';

/// The layers that sit on top of the canvas without being part of it.
///
/// Both of these are siblings of `DrawingBoard` in a `Stack`, not layers inside
/// `DrawingPainter`. `DrawingPainter`'s output is the artwork — it is what the
/// local canvas shows and what the server's SVG mirrors — so anything painted
/// inside it is something the composite must also contain. A reference image
/// and a set of owner names must appear in neither.

/// Region borders and owner names over the host's full-canvas view.
///
/// It recomputes the viewport exactly as `DrawingBoard` does, from the same
/// constraints, so its rectangles land on the same pixels as the strokes they
/// outline. It never takes input: pointers pass straight through to the canvas
/// beneath.
class RegionOwnershipOverlay extends ConsumerWidget {
  const RegionOwnershipOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owners = ref.watch(regionOwnersProvider);
    final room = ref.watch(roomProvider);
    final viewportRect = ref.watch(viewportRectProvider);

    final canvasAspectRatio = (room == null || room.canvasHeight == 0)
        ? 1.0
        : room.canvasWidth / room.canvasHeight;

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = CanvasViewport.fit(
            viewport: viewportRect,
            available: Size(constraints.maxWidth, constraints.maxHeight),
            canvasAspectRatio: canvasAspectRatio,
          );
          return CustomPaint(
            size: Size.infinite,
            painter: RegionOwnershipPainter(
              owners: [
                for (final owner in owners)
                  (
                    region: owner.region,
                    name: owner.name,
                    color: owner.color,
                  ),
              ],
              viewport: viewport,
            ),
          );
        },
      ),
    );
  }
}

/// The reference image, in a top corner of the game screen.
///
/// Being above the canvas in the `Stack` is what keeps it out of the canvas's
/// hit-testing: a drag that starts here is absorbed here, so it can never
/// begin a stroke, in any room status and either view mode.
///
/// A fetch that failed shows a retry rather than blocking the game — the
/// canvas is fully playable with no reference at all.
class TargetImageThumbnail extends ConsumerWidget {
  const TargetImageThumbnail({super.key});

  static const double _size = 120;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(targetImageProvider);

    // A room with no target shows nothing at all, and the canvas fills the
    // screen exactly as it did before targets existed.
    if (!target.hasImage && !target.failed && !target.loading) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      // Opaque, so the pointer stops here rather than reaching the canvas.
      behavior: HitTestBehavior.opaque,
      onTap: target.hasImage
          ? () => _openFullScreen(context, ref)
          : (target.failed
                ? () => ref.read(targetImageControllerProvider).load()
                : null),
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: _content(context, target),
      ),
    );
  }

  Widget _content(BuildContext context, TargetImageState target) {
    if (target.loading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (target.failed) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh, size: 20),
            SizedBox(height: 4),
            Text('Retry', style: TextStyle(fontSize: 11)),
          ],
        ),
      );
    }
    return Image.memory(target.bytes!, fit: BoxFit.cover);
  }

  void _openFullScreen(BuildContext context, WidgetRef ref) {
    final bytes = ref.read(targetImageProvider).bytes;
    if (bytes == null) return;
    // A route rather than an in-place expansion, so dismissing it puts the
    // game screen back exactly as it was.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Reference')),
          body: Center(
            child: InteractiveViewer(child: Image.memory(bytes)),
          ),
        ),
      ),
    );
  }
}
