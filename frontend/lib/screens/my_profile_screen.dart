// lib/screens/my_profile_screen.dart
import 'package:flutter/material.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Mon profil', style: TextStyle(fontSize: 24))),
    );
  }
}