import 'package:flex_color_picker/flex_color_picker.dart';
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
    final canUndo = ref.watch(canUndoProvider);

    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.undo),
            // Disabled mid-drag, and while a finished stroke is still awaiting
            // confirmation, rather than reasoning about which stroke an undo
            // would land on. Disabled too when there is nothing to undo.
            onPressed: (!canUndo || undoable == null)
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
          // The current colour, and the way to change it. The swatch is the
          // button: tapping it opens the picker on the colour in use.
          ColorIndicator(
            width: 32,
            height: 32,
            borderRadius: 4,
            hasBorder: true,
            color: tool.color,
            onSelect: () => _pickColor(context, ref, tool.color),
          ),
        ],
      ),
    );
  }

  /// Opens the colour picker on the colour currently in use.
  ///
  /// The dialog returns the colour that was picked, or the one it opened with
  /// if it was dismissed, so a cancel is indistinguishable from picking the
  /// same colour again — which is what it should mean.
  Future<void> _pickColor(
    BuildContext context,
    WidgetRef ref,
    Color current,
  ) async {
    final picked = await showColorPickerDialog(
      context,
      current,
      title: Text(
        'Pen colour',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      pickersEnabled: const <ColorPickerType, bool>{
        // The shared palette players recognise each other by, plus a wheel for
        // anything else. Accent and black-and-white would only pad the tabs.
        ColorPickerType.primary: true,
        ColorPickerType.accent: false,
        ColorPickerType.custom: true,
        ColorPickerType.wheel: true,
      },
      customColorSwatchesAndNames: _palette,
      // A hex field alongside the wheel, so a colour can be typed as well as
      // aimed at.
      showColorCode: true,
      colorCodeHasColor: true,
      copyPasteBehavior: const ColorPickerCopyPasteBehavior(
        copyButton: true,
        pasteButton: true,
        longPressMenu: true,
      ),
      width: 36,
      height: 36,
      borderRadius: 4,
      spacing: 4,
      runSpacing: 4,
      constraints: const BoxConstraints(
        minHeight: 460,
        minWidth: 320,
        maxWidth: 340,
      ),
    );
    ref.read(drawingToolProvider.notifier).setColor(picked);
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

/// The colours the game hands out and the ones the toolbar has always offered,
/// as a named palette, so the shades players already associate with each other
/// stay one tap away rather than being hunted for on the wheel.
final Map<ColorSwatch<Object>, String> _palette = {
  ColorTools.createPrimarySwatch(const Color(0xFF000000)): 'Black',
  ColorTools.createPrimarySwatch(const Color(0xFFF44336)): 'Red',
  ColorTools.createPrimarySwatch(const Color(0xFF4CAF50)): 'Green',
  ColorTools.createPrimarySwatch(const Color(0xFF2196F3)): 'Blue',
  ColorTools.createPrimarySwatch(const Color(0xFFFFEB3B)): 'Yellow',
  ColorTools.createPrimarySwatch(const Color(0xFFFF9800)): 'Orange',
  ColorTools.createPrimarySwatch(const Color(0xFF9C27B0)): 'Purple',
};
