import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/controllers/room_controller.dart';
import 'room_waiting_screen.dart';
import 'test_drawing_screen.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final _nameController = TextEditingController();
  final _roomCodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  void _handleJoin() async {
    final name = _nameController.text.trim();
    final code = _roomCodeController.text.trim().toUpperCase();
    if (name.isEmpty || code.isEmpty) return;

    setState(() => _isLoading = true);
    final success = await ref.read(roomControllerProvider).joinRoom(code, name);
    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RoomWaitingScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to join room.')));
    }
  }

  void _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    // Arbitrary default canvas size, maybe 1000x1000
    final success = await ref
        .read(roomControllerProvider)
        .createRoom(name, 1000, 1000);
    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RoomWaitingScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to create room.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Draw Together Lobby')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome to Draw Together',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Your Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _roomCodeController,
                decoration: const InputDecoration(
                  labelText: 'Room Code (to join)',
                ),
              ),
              const SizedBox(height: 32),
              if (_isLoading) const CircularProgressIndicator(),
              if (!_isLoading) ...[
                ElevatedButton(
                  onPressed: _handleJoin,
                  child: const Text('Join Game'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _handleCreate,
                  child: const Text('Create New Game'),
                ),
              ],
              const SizedBox(height: 64),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TestDrawingScreen(),
                    ),
                  );
                },
                child: const Text('Test Drawing Locally'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
