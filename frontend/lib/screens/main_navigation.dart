// lib/screens/main_navigation.dart
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import 'watchlist_screen.dart';
import 'search_screen.dart';
import 'discovery_screen.dart';
import 'friends_screen.dart';
import 'my_profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  // Discover par défaut
  int _currentIndex = 2;

  // Liste des écrans dans l'ordre des onglets
  final List<Widget> _screens = const [
    WatchlistScreen(),
    SearchScreen(),
    DiscoveryScreen(),
    FriendsScreen(),
    MyProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      // IndexedStack conserve l'état (scroll, inputs) de chaque écran en mémoire
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.video_library_outlined),
            activeIcon: const Icon(Icons.video_library),
            label: l10n.watchlist,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.search),
            label: l10n.search,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.movie_creation_outlined),
            activeIcon: const Icon(Icons.movie_creation),
            label: l10n.discover,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people_outline),
            activeIcon: const Icon(Icons.people),
            label: l10n.friends,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: l10n.profile,
          ),
        ],
      ),
    );
  }
}
