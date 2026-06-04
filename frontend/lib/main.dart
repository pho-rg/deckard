// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/main_navigation.dart';

void main() {
  runApp(const DeckardApp());
}

class DeckardApp extends StatelessWidget {
  const DeckardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deckard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const MainNavigation(),
    );
  }
}