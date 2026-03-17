import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../../providers/game_providers.dart';
import 'lobby_screen.dart';

class FinalResultScreen extends ConsumerWidget {
  const FinalResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base64Image = ref.watch(finalImageBase64Provider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Final Masterpiece'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (base64Image != null)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: Image.memory(
                  base64Decode(base64Image),
                  fit: BoxFit.contain,
                ),
              )
            else
              const CircularProgressIndicator(),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Clear state
                ref.read(strokesProvider.notifier).clear();
                ref.read(finalImageBase64Provider.notifier).set(null);
                ref.read(roomProvider.notifier).set(null);
                ref.read(currentPlayerProvider.notifier).set(null);
                ref.read(playersProvider.notifier).set([]);

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LobbyScreen()),
                );
              },
              child: const Text('Back to Lobby'),
            ),
          ],
        ),
      ),
    );
  }
}
