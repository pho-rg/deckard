import 'package:flutter/material.dart';
import 'package:frontend/theme/app_theme.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';
import '../widgets/movie_card.dart';

enum SortOption { releaseDate, popularity }

enum ViewMode { grid4, grid3, grid2, oneByOne }

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
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
    _moviesFuture = MovieService.getMockMovies().then((movies) {
      _movies = movies;
      _sortMovies();
      return _movies;
    });
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
        _movies.sort((a, b) => (b.popularity ?? 0).compareTo(a.popularity ?? 0));
      }
    });
  }

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
          _currentView = ViewMode.oneByOne;
          break;
        case ViewMode.oneByOne:
          _currentView = ViewMode.grid4;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentView == ViewMode.oneByOne
          ? null
          : AppBar(
              title: const Text('WATCHLIST'),
              actions: [
                PopupMenuButton<SortOption>(
                  icon: const Icon(Icons.sort),
                  onSelected: (SortOption result) {
                    _currentSort = result;
                    _sortMovies();
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
                    const PopupMenuItem<SortOption>(
                      value: SortOption.releaseDate,
                      child: Text('Release Date'),
                    ),
                    const PopupMenuItem<SortOption>(
                      value: SortOption.popularity,
                      child: Text('Popularity'),
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
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (_movies.isEmpty) {
            return const Center(child: Text('Your watchlist is empty'));
          }

          if (_currentView == ViewMode.oneByOne) {
            return _buildOneByOneView();
          }

          return CustomScrollView(
            slivers: [
              // AI Recommendations Banner
              SliverToBoxAdapter(
                child: _buildAIRecBanner(),
              ),
              // Movie count display
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 16.0, 8.0, 8.0),
                  child: Text(
                    '${_movies.length} MOVIES',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
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

  Widget _buildAIRecBanner() {
    return Container(
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1A23), // Surface color
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Extend your movie shelf',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Open Recommendations Page
                  },
                  icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.black),
                  label: const Text(
                    'View recommendations',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
        return Icons.view_module; // Icon representing Grid 3
      case ViewMode.grid3:
        return Icons.dashboard; // Icon representing Grid 2
      case ViewMode.grid2:
        return Icons.view_carousel; // Icon representing OneByOne
      case ViewMode.oneByOne:
        return Icons.grid_view; // Icon representing Grid 4
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
            return MovieCard(
              movie: _movies[index],
              onTap: () {
                // print('Tapped on ${_movies[index].title}');
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
                        onTap: () {
                          // print('Tapped on ${movie.title}');
                        },
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text(
                      movie.title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Color(0xFF00FF94), size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '${movie.voteAverage ?? 0.0}',
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
