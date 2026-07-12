import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import 'movie_detail_screen.dart';
import 'recommendations_screen.dart';
import 'main_navigation.dart';

enum SortOption { releaseDate, rating }

enum ViewMode { grid4, grid3, grid2, oneByOne }

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => WatchlistScreenState();
}

class WatchlistScreenState extends State<WatchlistScreen> {
  late Future<List<Movie>> _moviesFuture;
  List<Movie> _movies = [];
  SortOption _currentSort = SortOption.releaseDate;
  ViewMode _currentView = ViewMode.grid4;

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  void _loadMovies() {
    _moviesFuture = MovieService.getWatchlist().then((movies) {
      _movies = movies;
      _sortMovies();
      return _movies;
    });
  }

  /// Recharge la watchlist depuis le back. `MainNavigation` conserve cet
  /// écran vivant dans un `IndexedStack` (jamais recréé), donc `initState`
  /// ne suffit pas : un ajout/retrait fait depuis un autre écran (détail,
  /// recherche…) ne serait sinon jamais reflété ici.
  Future<void> reload() async {
    setState(_loadMovies);
    await _moviesFuture;
  }

  void _sortMovies() {
    setState(() {
      if (_currentSort == SortOption.releaseDate) {
        _movies.sort((a, b) {
          final dateA = a.releaseDate ?? '';
          final dateB = b.releaseDate ?? '';
          return dateB.compareTo(dateA); // Newest first
        });
      } else {
        _movies.sort((a, b) => (b.voteAverage ?? 0).compareTo(a.voteAverage ?? 0));
      }
    });
  }

  // Ne cycle qu'entre les 3 densités de grille : la vue plein écran
  // "un film à la fois" n'est volontairement pas dans ce cycle (elle
  // surprenait — on tombait dedans sans l'avoir demandé).
  void _cycleViewMode() {
    setState(() {
      switch (_currentView) {
        case ViewMode.grid4:
          _currentView = ViewMode.grid3;
          break;
        case ViewMode.grid3:
          _currentView = ViewMode.grid2;
          break;
        case ViewMode.grid2:
        case ViewMode.oneByOne:
          _currentView = ViewMode.grid4;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: _currentView == ViewMode.oneByOne && _movies.isNotEmpty
          ? null
          : AppBar(
              title: Text(l10n.watchlist),
              actions: _movies.isEmpty ? null : [
                PopupMenuButton<SortOption>(
                  icon: const Icon(Icons.sort),
                  onSelected: (SortOption result) {
                    _currentSort = result;
                    _sortMovies();
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
                    CheckedPopupMenuItem<SortOption>(
                      value: SortOption.releaseDate,
                      checked: _currentSort == SortOption.releaseDate,
                      child: Text(l10n.releaseDate),
                    ),
                    CheckedPopupMenuItem<SortOption>(
                      value: SortOption.rating,
                      checked: _currentSort == SortOption.rating,
                      child: Text(l10n.ratings),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(_getNextViewIcon()),
                  onPressed: _cycleViewMode,
                ),
              ],
            ),
      body: FutureBuilder<List<Movie>>(
        future: _moviesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _movies.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (_movies.isEmpty) {
            return Column(
              children: [
                _buildAIRecBanner(l10n),
                Expanded(child: _buildEmptyState(l10n)),
              ],
            );
          }

          if (_currentView == ViewMode.oneByOne) {
            return _buildOneByOneView();
          }

          return CustomScrollView(
            slivers: [
              // AI Recommendations Banner
              SliverToBoxAdapter(
                child: _buildAIRecBanner(l10n),
              ),
              // Movie count display
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 16.0, 16.0, 8.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      l10n.moviesCount(_movies.length).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
              // Grid View
              _buildGridView(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_toggle_off, size: 64, color: Colors.white10),
          const SizedBox(height: 16),
          Text(
            l10n.watchlistEmpty,
            style: const TextStyle(color: Colors.white38, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              MainNavigation.of(context)?.setTab(2);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white10,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(l10n.goToDiscover),
          ),
        ],
      ),
    );
  }

  Widget _buildAIRecBanner(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.extendShelf,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RecommendationsScreen()),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.black),
                  label: Text(
                    l10n.viewRecommendations,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryPurple,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.auto_awesome,
            size: 48,
            color: Colors.white10,
          ),
        ],
      ),
    );
  }

  IconData _getNextViewIcon() {
    switch (_currentView) {
      case ViewMode.grid4:
        return Icons.view_module;
      case ViewMode.grid3:
        return Icons.dashboard;
      case ViewMode.grid2:
      case ViewMode.oneByOne:
        return Icons.grid_view;
    }
  }

  Widget _buildGridView() {
    int crossAxisCount = 4;
    if (_currentView == ViewMode.grid3) crossAxisCount = 3;
    if (_currentView == ViewMode.grid2) crossAxisCount = 2;

    return SliverPadding(
      padding: const EdgeInsets.all(4.0),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: 4.0,
          mainAxisSpacing: 4.0,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final movie = _movies[index];
            return MovieCard(
              key: ValueKey(movie.id),
              movie: movie,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MovieDetailScreen(movie: movie),
                  ),
                );
                if (mounted) reload();
              },
            );
          },
          childCount: _movies.length,
        ),
      ),
    );
  }

  Widget _buildOneByOneView() {
    return SafeArea(
      child: Stack(
        children: [
          PageView.builder(
            itemCount: _movies.length,
            itemBuilder: (context, index) {
              final movie = _movies[index];
              return Container(
                padding: const EdgeInsets.fromLTRB(30.0, 60.0, 30.0, 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 3,
                      child: MovieCard(
                        movie: movie,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MovieDetailScreen(movie: movie),
                            ),
                          );
                          if (mounted) reload();
                        },
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text(
                      movie.title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: AppTheme.secondaryPurple, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          (movie.voteAverage ?? 0.0).toStringAsFixed(1),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 20),
                        const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          movie.releaseDate?.split('-').first ?? 'N/A',
                          style: const TextStyle(fontSize: 18, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      flex: 1,
                      child: SingleChildScrollView(
                        child: Text(
                          movie.overview ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, size: 32, color: Colors.white70),
              onPressed: () {
                setState(() {
                  _currentView = ViewMode.grid4;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
