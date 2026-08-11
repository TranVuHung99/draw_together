import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_providers.dart';
import '../../providers/controllers/websocket_service.dart';
import '../../core/serverpod_client.dart';
import 'game_screen.dart';

class RoomWaitingScreen extends ConsumerStatefulWidget {
  const RoomWaitingScreen({super.key});

  @override
  ConsumerState<RoomWaitingScreen> createState() => _RoomWaitingScreenState();
}

class _RoomWaitingScreenState extends ConsumerState<RoomWaitingScreen> {
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
    if (room != null) {
      // Hardcoded duration: 60 seconds.
      await client.room.startGame(room.id!, 60);
    }
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
      appBar: AppBar(title: Text('Room: ${room.roomCode}')),
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
            if (isHost)
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
        ),
      ),
    );
  }
}
