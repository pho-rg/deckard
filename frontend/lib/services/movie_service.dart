import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/movie.dart';
import '../models/profile_models.dart';
import 'api_service.dart';

class MovieService {
  static final _api = ApiService();

  static const _onboardingListAsset = 'lib/data/onboarding_movies.json';

  /// Onboarding grid: read the fixed tmdb_id list bundled with the app, then
  /// resolve them to cards via the backend (DB-backed, no TMDB).
  /// POST /movies/by-ids { tmdb_ids: [...] } → list<MovieCard>
  static Future<List<ProfileMovieCard>> getOnboardingMovies() async {
    final raw = await rootBundle.loadString(_onboardingListAsset);
    final tmdbIds = (json.decode(raw) as List)
        .map((e) => (e as num).toInt())
        .toList();
    if (tmdbIds.isEmpty) return [];

    final data = await _api.post('/movies/by-ids', {'tmdb_ids': tmdbIds});
    return (data as List)
        .map((m) => ProfileMovieCard.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  /// Full movie detail (DB-backed): genres, cast, crew, trailer.
  /// GET /movies/{tmdb_id} -> MovieDetailOut
  static Future<Movie> getMovieDetail(int tmdbId) async {
    final data = await _api.get('/movies/$tmdbId');
    return Movie.fromDetail(data as Map<String, dynamic>);
  }

  /// TMDB community rating (separate call, may be slow).
  /// GET /movies/{tmdb_id}/tmdb-rating -> { vote_average: double? }
  static Future<double?> getTmdbRating(int tmdbId) async {
    final data = await _api.get('/movies/$tmdbId/tmdb-rating');
    final va = (data as Map<String, dynamic>)['vote_average'];
    return va != null ? (va as num).toDouble() : null;
  }

  /// Tendances (source TMDB, mises en cache côté back).
  /// GET /movies/trending -> PagedMovies { results: [MovieSummary] }
  static Future<List<Movie>> getTrending() async {
    final data = await _api.get('/movies/trending');
    return _cardsFromPaged(data);
  }

  /// À l'affiche / en salle (source TMDB, mises en cache côté back).
  /// GET /movies/now-playing -> PagedMovies { results: [MovieSummary] }
  static Future<List<Movie>> getNowPlaying() async {
    final data = await _api.get('/movies/now-playing');
    return _cardsFromPaged(data);
  }

  /// Film mis en avant (DB). Renvoie null si aucun n'est configuré (404).
  /// GET /movies/featured -> MovieDetailOut
  static Future<Movie?> getFeatured() async {
    try {
      final data = await _api.get('/movies/featured');
      return Movie.fromDetail(data as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Recherche de films (DB, pas TMDB).
  /// GET /movies/search?q= -> PagedMovies { results: [MovieSummary] }
  static Future<List<Movie>> searchMovies(String query) async {
    final data =
        await _api.get('/movies/search?q=${Uri.encodeQueryComponent(query)}');
    return _cardsFromPaged(data);
  }

  /// Recherche de personnes (cast & crew) dans notre catalogue (DB).
  /// GET /persons/search?q= -> PagedPersons { results: [PersonCard] }
  static Future<List<PersonResult>> searchPersons(String query) async {
    final data =
        await _api.get('/persons/search?q=${Uri.encodeQueryComponent(query)}');
    final results = (data is Map ? data['results'] as List? : null) ?? const [];
    return results
        .map((p) => PersonResult.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// Recommandations personnelles (v1 : films au hasard de la BDD côté back ;
  /// un modèle IA sera branché plus tard).
  /// GET /recommendations -> list<MovieCard>
  static Future<List<Movie>> getRecommendations() async {
    final data = await _api.get('/recommendations');
    return (data as List)
        .map((m) => Movie.fromCard(m as Map<String, dynamic>))
        .toList();
  }

  /// Filmographie d'une personne (films où elle apparaît au cast ou crew).
  /// GET /persons/{id}/filmography -> list<MovieCard>
  static Future<List<Movie>> getFilmography(int personId) async {
    final data = await _api.get('/persons/$personId/filmography');
    return (data as List)
        .map((m) => Movie.fromCard(m as Map<String, dynamic>))
        .toList();
  }

  /// MovieSummary partage la forme de MovieCard (tmdb_id, title, poster_url…),
  /// donc Movie.fromCard sait la mapper.
  static List<Movie> _cardsFromPaged(dynamic data) {
    final results = (data is Map ? data['results'] as List? : null) ?? const [];
    return results
        .map((m) => Movie.fromCard(m as Map<String, dynamic>))
        .toList();
  }

  /// Films similaires (v1 : films au hasard côté back ; modèle IA plus tard).
  /// GET /movies/{tmdb_id}/similar -> list<MovieCard>
  static Future<List<Movie>> getSimilar(int tmdbId) async {
    final data = await _api.get('/movies/$tmdbId/similar');
    return (data as List)
        .map((m) => Movie.fromCard(m as Map<String, dynamic>))
        .toList();
  }

  /// Public ratings aggregate + reviews for a movie.
  /// GET /movies/{tmdb_id}/reviews -> MovieRatingsOut
  static Future<MovieRatings> getMovieReviews(int tmdbId) async {
    final data = await _api.get('/movies/$tmdbId/reviews');
    return MovieRatings.fromJson(data as Map<String, dynamic>);
  }

  /// The signed-in user's relationship to a movie.
  /// GET /movies/{tmdb_id}/user-state -> UserStateOut
  static Future<MovieUserState> getUserState(int tmdbId) async {
    final data = await _api.get('/movies/$tmdbId/user-state');
    return MovieUserState.fromJson(data as Map<String, dynamic>);
  }

  // ---- favorite ----
  static Future<void> addFavorite(int tmdbId) async {
    await _api.post('/movies/$tmdbId/favorite', {});
  }

  static Future<void> removeFavorite(int tmdbId) async {
    await _api.delete('/movies/$tmdbId/favorite');
  }

  // ---- watched ----
  static Future<void> markWatched(int tmdbId) async {
    await _api.post('/movies/$tmdbId/watched', {});
  }

  static Future<void> unmarkWatched(int tmdbId) async {
    await _api.delete('/movies/$tmdbId/watched');
  }

  // ---- rating + review ----
  /// PUT /movies/{tmdb_id}/rating { stars, review }
  static Future<void> setRating(int tmdbId, double stars, String? review) async {
    await _api.put('/movies/$tmdbId/rating', {
      'stars': stars,
      if (review != null && review.isNotEmpty) 'review': review,
    });
  }

  static Future<void> removeRating(int tmdbId) async {
    await _api.delete('/movies/$tmdbId/rating');
  }

  /// The signed-in user's watchlist (DB-backed).
  /// GET /users/me/watchlist → list<MovieCard>
  static Future<List<Movie>> getWatchlist() async {
    final data = await _api.get('/users/me/watchlist');
    return (data as List)
        .map((m) => Movie.fromCard(m as Map<String, dynamic>))
        .toList();
  }

  /// Add a movie to the signed-in user's watchlist.
  /// POST /movies/{tmdb_id}/watchlist
  static Future<void> addToWatchlist(int tmdbId) async {
    await _api.post('/movies/$tmdbId/watchlist', {});
  }

  /// Remove a movie from the signed-in user's watchlist.
  /// DELETE /movies/{tmdb_id}/watchlist
  static Future<void> removeFromWatchlist(int tmdbId) async {
    await _api.delete('/movies/$tmdbId/watchlist');
  }

  // ---------------------------------------------------------------------------
  // Mock data — still used by screens not yet wired to the backend
  // (search, recommendations, discovery, profile, friends, person, detail's
  // similar-movies). To be removed as each screen is migrated.
  // ---------------------------------------------------------------------------

  static Future<List<Movie>> getMockMovies() async {
    try {
      final String response = await rootBundle.loadString('lib/fake_data/raw_movie_data_test.jsonl');
      final List<String> lines = response.split('\n');
      final List<Movie> allMovies = [];

      for (var line in lines) {
        if (line.trim().isNotEmpty) {
          try {
            final Map<String, dynamic> data = json.decode(line);
            allMovies.add(Movie.fromJson(data));
          } catch (e) {
            print('Error parsing line: $e');
          }
        }
      }

      if (allMovies.isEmpty) return [];

      // Randomize the list and pick a subset between 50 and 80
      final random = Random();
      final int count = 50 + random.nextInt(31); // 50 to 80

      allMovies.shuffle(random);
      return allMovies.take(min(count, allMovies.length)).toList();
    } catch (e) {
      print('Error loading mock data: $e');
      return [];
    }
  }

  /// Find a single movie by its TMDB id.
  /// Searches the full JSONL (not the randomised subset) for reliability.
  static Future<Movie?> getById(int tmdbId) async {
    try {
      final String response =
          await rootBundle.loadString('lib/fake_data/raw_movie_data_test.jsonl');
      for (final line in response.split('\n')) {
        if (line.trim().isEmpty) continue;
        try {
          final data = json.decode(line) as Map<String, dynamic>;
          if (data['id'] == tmdbId) return Movie.fromJson(data);
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }
}
