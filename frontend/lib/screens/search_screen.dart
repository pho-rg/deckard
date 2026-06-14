import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';
import 'movie_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  List<String> _searchHistory = [];
  List<Movie> _movieResults = [];
  List<dynamic> _peopleResults = [];
  List<Movie> _suggestedMovies = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSearchHistory();
    _loadSuggestions();
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('search_history') ?? [];
    });
  }

  Future<void> _loadSuggestions() async {
    final movies = await MovieService.getMockMovies();
    if (mounted) {
      setState(() {
        // Mocking newest releases
        _suggestedMovies = List<Movie>.from(movies)
          ..sort((a, b) => (b.releaseDate ?? '').compareTo(a.releaseDate ?? ''));
        _suggestedMovies = _suggestedMovies.take(5).toList();
      });
    }
  }

  Future<void> _saveSearchHistory(String query) async {
    if (query.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _searchHistory.remove(query);
    _searchHistory.insert(0, query);
    if (_searchHistory.length > 20) _searchHistory.removeLast();
    await prefs.setStringList('search_history', _searchHistory);
    setState(() {});
  }

  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
    setState(() {
      _searchHistory = [];
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query, saveToHistory: false);
    });
  }

  void _performSearch(String query, {bool saveToHistory = true}) {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _hasSearched = false;
        _movieResults = [];
        _peopleResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    if (saveToHistory) {
      _saveSearchHistory(query);
    }

    MovieService.getMockMovies().then((movies) {
      final queryLower = query.toLowerCase();
      
      final moviesFound = movies.where((m) => 
        m.title.toLowerCase().contains(queryLower) || 
        (m.overview?.toLowerCase().contains(queryLower) ?? false)
      ).toList();

      final Set<int> seenPeopleIds = {};
      final List<dynamic> peopleFound = [];

      for (var m in movies) {
        if (m.cast != null) {
          for (var c in m.cast!) {
            if (c.name.toLowerCase().contains(queryLower) && !seenPeopleIds.contains(c.id)) {
              seenPeopleIds.add(c.id);
              peopleFound.add(c);
            }
          }
        }
        if (m.crew != null) {
          for (var cr in m.crew!) {
            if (cr.name.toLowerCase().contains(queryLower) && !seenPeopleIds.contains(cr.id)) {
              seenPeopleIds.add(cr.id);
              peopleFound.add(cr);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _movieResults = moviesFound;
          _peopleResults = peopleFound;
          _isSearching = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildSearchBar(l10n),
            if (_hasSearched) _buildTabBar(l10n),
            Expanded(
              child: _hasSearched ? _buildSearchResults(l10n) : _buildHistoryView(l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(25),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          onSubmitted: (val) => _performSearch(val, saveToHistory: true),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(AppLocalizations l10n) {
    return TabBar(
      controller: _tabController,
      indicatorColor: AppTheme.secondaryPurple,
      dividerColor: Colors.white10,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white38,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      tabs: [
        Tab(text: l10n.films.toUpperCase()),
        Tab(text: l10n.castCrew.toUpperCase()),
      ],
    );
  }

  Widget _buildHistoryView(AppLocalizations l10n) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (_searchHistory.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.recentSearches.toUpperCase(),
                  style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                GestureDetector(
                  onTap: _clearSearchHistory,
                  child: Text(l10n.clearHistory.toUpperCase(), style: const TextStyle(color: AppTheme.primaryPurple, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          ..._searchHistory.map((query) => ListTile(
            leading: const Icon(Icons.history, color: Colors.white24, size: 20),
            title: Text(query, style: const TextStyle(color: Colors.white70, fontSize: 15)),
            trailing: const Icon(Icons.north_west, color: Colors.white24, size: 16),
            onTap: () {
              _searchController.text = query;
              _performSearch(query, saveToHistory: true);
            },
          )),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            l10n.newReleases.toUpperCase(),
            style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
        ),
        ..._suggestedMovies.map((movie) => _buildMovieResultItem(movie, l10n)),
      ],
    );
  }

  Widget _buildSearchResults(AppLocalizations l10n) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple));
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildMovieResults(l10n),
        _buildPeopleResults(l10n),
      ],
    );
  }

  Widget _buildMovieResults(AppLocalizations l10n) {
    if (_movieResults.isEmpty) {
      return Center(child: Text(l10n.noResults, style: const TextStyle(color: Colors.white38)));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 16), // Restoring padding adjustment
      itemCount: _movieResults.length,
      itemBuilder: (context, index) {
        return _buildMovieResultItem(_movieResults[index], l10n, saveHistory: true);
      },
    );
  }

  Widget _buildMovieResultItem(Movie movie, AppLocalizations l10n, {bool saveHistory = false}) {
    final director = movie.crew?.firstWhere(
      (c) => c.job == 'Director',
      orElse: () => Crew(id: 0, name: 'Unknown', job: '', department: ''),
    ).name ?? 'Unknown';

    final starring = movie.cast?.take(3).map((c) => c.name).join(', ') ?? '';

    return InkWell(
      onTap: () {
        if (saveHistory) {
          _saveSearchHistory(_searchController.text);
        }
        Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: movie.posterUrl,
                width: 60,
                height: 90,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.white10),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white38, fontSize: 13),
                      children: [
                        TextSpan(text: '${movie.releaseDate?.split('-').first ?? ''} • ${l10n.directedByLower} '),
                        TextSpan(
                          text: director,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  if (starring.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                        children: [
                          TextSpan(text: '${l10n.withActorsLower} '),
                          TextSpan(
                            text: starring,
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeopleResults(AppLocalizations l10n) {
    if (_peopleResults.isEmpty) {
      return Center(child: Text(l10n.noResults, style: const TextStyle(color: Colors.white38)));
    }

    return ListView.builder(
      itemCount: _peopleResults.length,
      itemBuilder: (context, index) {
        final person = _peopleResults[index];
        final isCast = person is Cast;
        final profileUrl = isCast ? person.profileUrl : (person as Crew).profileUrl;

        return ListTile(
          onTap: () {},
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: Colors.white10,
            backgroundImage: profileUrl.isNotEmpty ? CachedNetworkImageProvider(profileUrl) : null,
            child: profileUrl.isEmpty ? const Icon(Icons.person, color: Colors.white10) : null,
          ),
          title: Text(person.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(
            isCast ? person.character : person.job,
            style: const TextStyle(color: Colors.white38),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.white10),
        );
      },
    );
  }
}
