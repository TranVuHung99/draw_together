import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tool_providers.dart';

/// Tool controls for the canvas.
///
/// A sibling of the canvas rather than a child of it, so it can be left out
/// entirely when drawing input is not accepted.
class DrawingToolbar extends ConsumerWidget {
  const DrawingToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tool = ref.watch(drawingToolProvider);
    final notifier = ref.read(drawingToolProvider.notifier);

    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
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
}
