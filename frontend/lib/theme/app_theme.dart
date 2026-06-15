import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF0F0E17);
  static const Color surface = Color(0xFF1B1A23);
  static const Color primaryPurple = Color(0xFF7D70BA);
  static const Color secondaryPurple = Color(0xFFDEC1FF);
  static const Color accentGreen = Color(0xFF00FF94);
  static const Color textMain = Colors.white;
  static const Color textDim = Color(0xFF94A3B8);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryPurple,
      colorScheme: const ColorScheme.dark(
        primary: primaryPurple,
        secondary: secondaryPurple,
        surface: surface,
        onSurface: textMain,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textMain,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primaryPurple,
        unselectedItemColor: textDim,
      ),
    );
  }
}
