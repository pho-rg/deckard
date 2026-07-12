import 'package:flutter/material.dart';
import 'profile_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => MyProfileScreenState();
}

class MyProfileScreenState extends State<MyProfileScreen> {
  final _profileKey = GlobalKey<ProfileScreenState>();

  void reload() => _profileKey.currentState?.reload();

  @override
  Widget build(BuildContext context) {
    return ProfileScreen(key: _profileKey);
  }
}
