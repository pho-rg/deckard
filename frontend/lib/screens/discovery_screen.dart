import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';
import '../services/profile_service.dart';
import '../widgets/movie_card.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';
import 'movie_detail_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  late Future<Map<String, dynamic>> _discoveryData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _discoveryData = _fetchDiscovery();
  }

  Future<Map<String, dynamic>> _fetchDiscovery() async {
    final results = await Future.wait([
      MovieService.getTrending(),
      MovieService.getNowPlaying(),
      MovieService.getFeatured(),
      MovieService.getRecommendations(),
    ]);

    final trending = results[0] as List<Movie>;
    final nowPlaying = results[1] as List<Movie>;
    Movie? featured = results[2] as Movie?;
    final forYou = results[3] as List<Movie>;

    // No configured featured movie → fall back to the first trending one.
    // `trending` entries are MovieCard-shaped (no cast/crew), so the fallback
    // must fetch the full detail to get director/actors like a real featured
    // movie would have.
    if (featured == null && trending.isNotEmpty) {
      try {
        featured = await MovieService.getMovieDetail(trending.first.id);
      } catch (_) {
        featured = trending.first;
      }
    }

    if (featured == null &&
        trending.isEmpty &&
        nowPlaying.isEmpty &&
        forYou.isEmpty) {
      return {};
    }

    return {
      'featured': featured,
      'trending': trending.take(15).toList(),
      'nowPlaying': nowPlaying.take(15).toList(),
      'forYou': forYou,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () => _showLanguageDialog(context, localeProvider, l10n),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _discoveryData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text(l10n.noMoviesAvailable));
          }

          final featured = snapshot.data!['featured'] as Movie?;
          final trending = snapshot.data!['trending'] as List<Movie>;
          final nowPlaying = snapshot.data!['nowPlaying'] as List<Movie>;
          final forYou = snapshot.data!['forYou'] as List<Movie>;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (featured != null) ...[
                  // Section: Discovery (Featured)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                    child: Text(
                      l10n.discover,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  _buildFeaturedSection(featured, l10n),
                  const SizedBox(height: 30),
                ],

                // Section: Trending
                _buildHorizontalSection(l10n.trending, trending),

                const SizedBox(height: 30),

                // Section: Now Playing
                _buildHorizontalSection(l10n.nowPlaying, nowPlaying),

                const SizedBox(height: 30),

                // Section: For You (recommandations, en grille)
                if (forYou.isNotEmpty) _buildGridSection(l10n.forYou, forYou),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedSection(Movie movie, AppLocalizations l10n) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = screenWidth * 0.40;

    // Extracting info
    final director = movie.crew?.firstWhere(
      (c) => c.job == 'Director', 
      orElse: () => movie.crew?.firstWhere(
        (c) => c.department == 'Directing', 
        orElse: () => Crew(id: 0, name: 'Unknown', job: '', department: '')
      ) as Crew
    ).name ?? 'Unknown';
    
    final actors = movie.cast?.take(3).map((a) => a.name).join(', ') ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Movie Card on the left
          MovieCard(
            movie: movie,
            width: cardWidth,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MovieDetailScreen(movie: movie),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          // Info on the right
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: AppTheme.secondaryPurple, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      (movie.voteAverage ?? 0.0).toStringAsFixed(1),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      movie.releaseDate?.split('-').first ?? '',
                      style: const TextStyle(fontSize: 14, color: Colors.white54),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.directedBy,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38),
                ),
                Text(
                  director,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.withActors,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38),
                ),
                Text(
                  actors,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Text(
                  movie.overview ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalSection(String title, List<Movie> movies) {
    final double cardWidth = MediaQuery.of(context).size.width * 0.22; // Size of grid 4

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Colors.white70,
            ),
          ),
        ),
        SizedBox(
          height: (cardWidth / (2 / 3)), // Height based on 2:3 ratio
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: MovieCard(
                  movie: movies[index],
                  width: cardWidth,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MovieDetailScreen(movie: movies[index]),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Section en grille (comme la page Watchlist) — posters cliquables, 3 colonnes.
  Widget _buildGridSection(String title, List<Movie> movies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Colors.white70,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2 / 3,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
          ),
          itemCount: movies.length,
          itemBuilder: (context, index) {
            return MovieCard(
              movie: movies[index],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        MovieDetailScreen(movie: movies[index]),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _showLanguageDialog(BuildContext context, LocaleProvider localeProvider, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B1A23), // AppTheme.surface
          title: Center(
            child: Text(
              l10n.languageSelection,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageOption(
                context,
                localeProvider,
                const Locale('en'),
                '🇺🇸',
                'English',
              ),
              const Divider(color: Colors.white10),
              _buildLanguageOption(
                context,
                localeProvider,
                const Locale('fr'),
                '🇫🇷',
                'Français',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    LocaleProvider localeProvider,
    Locale locale,
    String flag,
    String name,
  ) {
    final isSelected = localeProvider.locale == locale;

    return InkWell(
      onTap: () async {
        Navigator.of(context).pop();
        if (isSelected) return;
        localeProvider.setLocale(locale);
        // Le contenu (titres, synopsis…) est servi dans la langue stockée
        // côté backend sur l'utilisateur : il faut la synchroniser avec la
        // langue de l'UI, sinon les films restent affichés dans l'ancienne.
        try {
          await ProfileService().updateMe(
            language: locale.languageCode == 'en' ? 'en-US' : 'fr-FR',
          );
        } catch (_) {
          // Best-effort : la langue de l'UI change même si la sync échoue.
        }
        if (mounted) {
          setState(_loadData);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: isSelected ? AppTheme.secondaryPurple : Colors.white,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, color: AppTheme.secondaryPurple, size: 20),
          ],
        ),
      ),
    );
  }
}
