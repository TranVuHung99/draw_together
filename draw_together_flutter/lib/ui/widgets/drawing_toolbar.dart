import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:draw_together_serverpod_client/draw_together_serverpod_client.dart'
    hide Stroke;
import '../../providers/game_providers.dart';
import '../../providers/controllers/websocket_service.dart';
import '../../providers/tool_providers.dart';

/// Tool controls for the canvas.
///
/// A sibling of the canvas rather than a child of it, so it can be left out
/// entirely when drawing input is not accepted. Undo lives here for the same
/// reason: it is a drawing action, and a read-only view offers none.
class DrawingToolbar extends ConsumerWidget {
  const DrawingToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tool = ref.watch(drawingToolProvider);
    final notifier = ref.read(drawingToolProvider.notifier);
    final undoable = ref.watch(undoableStrokeProvider);
    final drawing = ref.watch(strokeInProgressProvider);

    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.undo),
            // Disabled mid-drag rather than reasoning about which stroke an
            // undo would land on, and disabled when there is nothing to undo.
            onPressed: (undoable == null || drawing)
                ? null
                : () => _undo(ref, undoable.id, undoable.playerId),
            tooltip: 'Undo my last stroke',
          ),
          IconButton(
            icon: Icon(
              Icons.edit,
              color: tool.isEraser ? Colors.grey : Colors.blue,
            ),
            onPressed: () => notifier.setEraser(false),
            tooltip: 'Draw',
          ),
          IconButton(
            icon: Icon(
              Icons.phonelink_erase,
              color: tool.isEraser ? Colors.blue : Colors.grey,
            ),
            onPressed: () => notifier.setEraser(true),
            tooltip: 'Eraser',
          ),
          Slider(
            value: tool.strokeWidth,
            min: 1,
            max: 20,
            onChanged: notifier.setStrokeWidth,
            activeColor: Colors.blue,
          ),
          // Basic color picker
          DropdownButton<Color>(
            value: tool.color,
            items:
                {
                  tool.color, // Ensure current color is in the list
                  const Color(0xFF000000), // black
                  const Color(0xFFF44336), // red
                  const Color(0xFF4CAF50), // green
                  const Color(0xFF2196F3), // blue
                  const Color(0xFFFFEB3B), // yellow
                  const Color(0xFFFF9800), // orange
                  const Color(0xFF9C27B0), // purple
                }.map((Color color) {
                  return DropdownMenuItem<Color>(
                    value: color,
                    child: Container(width: 24, height: 24, color: color),
                  );
                }).toList(),
            onChanged: (Color? newValue) {
              if (newValue != null) notifier.setColor(newValue);
            },
          ),
        ],
      ),
    );
  }

  /// Asks the server to retract a stroke. Nothing is removed here — the canvas
  /// changes when the server confirms, so what a player sees is what the
  /// server actually deleted.
  void _undo(WidgetRef ref, String strokeId, int playerId) {
    final roomId = ref.read(roomProvider)?.id;
    if (roomId == null) return;
    ref
        .read(webSocketServiceProvider)
        .sendMessage(
          StrokeUndoMsg(
            roomId: roomId,
            playerId: playerId,
            strokeId: strokeId,
          ),
        );
  }
}
