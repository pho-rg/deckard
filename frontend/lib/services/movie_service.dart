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
