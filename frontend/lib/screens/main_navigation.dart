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

  static _MainNavigationState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MainNavigationState>();

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  // Discover par défaut
  int _currentIndex = 2;

  final _watchlistKey = GlobalKey<WatchlistScreenState>();
  final _friendsKey = GlobalKey<FriendsScreenState>();
  final _profileKey = GlobalKey<MyProfileScreenState>();

  void setTab(int index) {
    setState(() {
      _currentIndex = index;
    });
    _refreshOnTabSwitch(index);
  }

  // Les écrans restent vivants dans l'IndexedStack ci-dessous, donc un
  // changement fait depuis un autre onglet ne se reflète pas automatiquement :
  // on force un rechargement à chaque fois que l'utilisateur revient.
  void _refreshOnTabSwitch(int index) {
    if (index == 0) _watchlistKey.currentState?.reload();
    if (index == 3) _friendsKey.currentState?.reload();
    if (index == 4) _profileKey.currentState?.reload();
  }

  // Liste des écrans dans l'ordre des onglets
  late final List<Widget> _screens = [
    WatchlistScreen(key: _watchlistKey),
    const SearchScreen(),
    const DiscoveryScreen(),
    FriendsScreen(key: _friendsKey),
    MyProfileScreen(key: _profileKey),
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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          _refreshOnTabSwitch(index);
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
      ),
    );
  }
}
