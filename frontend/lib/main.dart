import 'package:flutter/material.dart';
import 'screens/main_navigation.dart';
import 'theme/app_theme.dart';

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
      theme: AppTheme.darkTheme,
      home: const MainNavigation(),
    );
  }
}
