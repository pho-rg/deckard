// lib/screens/friends_screen.dart
import 'package:flutter/material.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Mes amis', style: TextStyle(fontSize: 24))),
    );
  }
}