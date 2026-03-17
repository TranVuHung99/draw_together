import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/screens/lobby_screen.dart';

void main() {
  runApp(
    // To install Riverpod, we need to add this widget above everything else.
    const ProviderScope(child: DrawTogetherApp()),
  );
}

class DrawTogetherApp extends StatelessWidget {
  const DrawTogetherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Draw Together',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const LobbyScreen(),
    );
  }
}
