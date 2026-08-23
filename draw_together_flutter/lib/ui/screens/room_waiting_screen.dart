import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_providers.dart';
import '../../providers/controllers/websocket_service.dart';
import '../../core/serverpod_client.dart';
import 'game_screen.dart';

/// The largest file the client will send, matching the server's own cap.
///
/// Enforced here so an oversized pick is answered immediately rather than
/// after a pointless upload; the server's cap is still the boundary.
const int maxTargetImageBytes = 5 * 1024 * 1024;

/// The round lengths the host can pick from, within the range the server
/// accepts. The server validates the value regardless — this list is a
/// convenience, not the check.
const List<int> roundDurationOptions = [60, 120, 180, 300, 600];

class RoomWaitingScreen extends ConsumerStatefulWidget {
  const RoomWaitingScreen({super.key});

  @override
  ConsumerState<RoomWaitingScreen> createState() => _RoomWaitingScreenState();
}

class _RoomWaitingScreenState extends ConsumerState<RoomWaitingScreen> {
  int _durationSeconds = 120;

  /// The target as the host picked it, kept for the preview. The stored target
  /// is the server's normalized version of this.
  Uint8List? _targetPreview;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _connectToRoom();
  }

  void _connectToRoom() async {
    final room = ref.read(roomProvider);
    final player = ref.read(currentPlayerProvider);
    if (room != null && player != null) {
      await ref.read(webSocketServiceProvider).connect(room.id!, player.id!);
      // Refresh players upon joining
      final players = await client.room.getPlayersInRoom(room.id!);
      ref.read(playersProvider.notifier).set(players);
    }
  }

  void _startGame() async {
    final room = ref.read(roomProvider);
    final player = ref.read(currentPlayerProvider);
    if (room == null || player == null) return;
    // The host's own id is what proves to the server who is asking.
    await client.room.startGame(room.id!, player.id!, _durationSeconds);
  }

  Future<void> _pickTargetImage() async {
    final room = ref.read(roomProvider);
    final player = ref.read(currentPlayerProvider);
    if (room == null || player == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      // Bytes rather than a path: on web there is no path to read from.
      withData: true,
    );
    final bytes = result?.files.singleOrNull?.bytes;
    if (bytes == null) return;

    if (bytes.length > maxTargetImageBytes) {
      _report('That image is larger than ${maxTargetImageBytes ~/ (1024 * 1024)} MB');
      return;
    }

    setState(() => _uploading = true);
    try {
      final accepted = await client.room.uploadTargetImage(
        room.id!,
        player.id!,
        ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes),
      );
      if (!accepted) {
        // The server refuses anything it cannot decode, anything over its own
        // cap, and any upload once the game has started.
        _report('The server refused that image');
        return;
      }
      if (mounted) setState(() => _targetPreview = bytes);
    } catch (e) {
      _report('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Puts the room code on the clipboard, so it can be pasted into whatever
  /// the players are already talking in rather than read out letter by letter.
  Future<void> _copyRoomCode(String roomCode) async {
    await Clipboard.setData(ClipboardData(text: roomCode));
    _report('Copied $roomCode');
  }

  void _report(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider);
    final currentPlayer = ref.watch(currentPlayerProvider);
    final players = ref.watch(playersProvider);

    // Watch for game state change to PLAYING
    ref.listen(roomProvider, (previous, next) {
      if (next != null && next.status == 'PLAYING') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const GameScreen()),
        );
      }
    });

    if (room == null || currentPlayer == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isHost = room.hostId == currentPlayer.id;

    return Scaffold(
      appBar: AppBar(
        title: Text('Room: ${room.roomCode}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy the room code',
            onPressed: () => _copyRoomCode(room.roomCode),
          ),
        ],
      ),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 32),
            Text(
              'Waiting for players...',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final p = players[index];
                  final isMe = p.id == currentPlayer.id;
                  final isRoomHost = p.id == room.hostId;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(
                        int.parse(p.colorInfo ?? '0xFFFFFFFF'),
                      ),
                    ),
                    title: Text(
                      p.name +
                          (isMe ? ' (You)' : '') +
                          (isRoomHost ? ' - Host' : ''),
                    ),
                    // The host observes and controls the session; only the
                    // other players are given a region to draw in.
                    subtitle: Text(
                      isRoomHost ? 'Observing - does not draw' : 'Drawing',
                    ),
                  );
                },
              ),
            ),
            if (isHost) ...[
              _targetImagePicker(),
              _durationPicker(),
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: ElevatedButton(
                  // The game needs at least one drawing player, and the host is
                  // not one of them.
                  onPressed: players.any((p) => p.id != room.hostId)
                      ? _startGame
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'Start Game',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Picking the picture everyone will be drawing. A round with no target is
  /// still a round, so this is never required.
  Widget _targetImagePicker() {
    final preview = _targetPreview;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 16,
        children: [
          if (preview != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(
                preview,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickTargetImage,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image_outlined),
                  label: Text(
                    preview == null
                        ? 'Choose a target image'
                        : 'Replace target image',
                  ),
                ),
                Text(
                  preview == null
                      ? 'Optional — without one, players just draw'
                      : 'Each player will see only their own part of it',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _durationPicker() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 12,
        children: [
          const Text('Round length'),
          DropdownButton<int>(
            value: _durationSeconds,
            onChanged: (value) {
              if (value != null) setState(() => _durationSeconds = value);
            },
            items: [
              for (final seconds in roundDurationOptions)
                DropdownMenuItem(
                  value: seconds,
                  child: Text(
                    seconds < 60
                        ? '$seconds seconds'
                        : '${seconds ~/ 60} minute${seconds == 60 ? '' : 's'}',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
