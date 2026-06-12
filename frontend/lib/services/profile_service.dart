import 'dart:math';

import '../models/movie.dart';
import '../models/profile_models.dart';
import 'movie_service.dart';

// Hardcoded mock user — swap for real API calls once auth is ready.
final _mockUser = ProfileUser(
  id: 'mock-user-id',
  username: 'hugo',
  email: 'rhugo74@gmail.com',
  language: 'fr-FR',
  region: 'FR',
  createdAt: DateTime(2024, 3, 15),
);

class ProfileService {
  // ── Current user ──────────────────────────────────────────────────────────

  Future<ProfileUser> getMe() async => _mockUser;

  Future<ProfileUser> updateMe({
    String? username,
    String? email,
    String? language,
    String? currentPassword, // ignored in mock; will be verified server-side
    String? newPassword,     // ignored in mock; will be hashed server-side
  }) async {
    // TODO: PUT /users/me once auth is wired
    return ProfileUser(
      id: _mockUser.id,
      username: username ?? _mockUser.username,
      email: email ?? _mockUser.email,
      language: language ?? _mockUser.language,
      region: _mockUser.region,
      createdAt: _mockUser.createdAt,
    );
  }

  Future<List<ProfileMovieCard>> getMyFavorites() async {
    final movies = await MovieService.getMockMovies();
    final rng = Random(1); // fixed seed → stable subset
    final shuffled = List<Movie>.from(movies)..shuffle(rng);
    return shuffled.take(18).map(_toCard).toList();
  }

  Future<List<ProfileMovieCard>> getMyWatched() async {
    final movies = await MovieService.getMockMovies();
    final rng = Random(2);
    final shuffled = List<Movie>.from(movies)..shuffle(rng);
    return shuffled.take(34).map(_toCard).toList();
  }

  Future<List<ProfileRating>> getMyRatings() async {
    final movies = await MovieService.getMockMovies();
    final rng = Random(3);
    final shuffled = List<Movie>.from(movies)..shuffle(rng);
    final picks = shuffled.take(12).toList();

    final starOptions = [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0];
    final sampleReviews = [
      'Un chef-d\'œuvre absolu.',
      'Très bon film, je recommande.',
      'Décevant par rapport aux attentes.',
      'Casting impeccable, mise en scène soignée.',
      null,
      'Pas mal mais trop long.',
      null,
      'Magistral de bout en bout.',
      'Une belle surprise.',
      null,
      'Incontournable.',
      'Bof, rien de transcendant.',
    ];

    return List.generate(picks.length, (i) {
      final stars = starOptions[rng.nextInt(starOptions.length)];
      return ProfileRating(
        movie: _toCard(picks[i]),
        stars: stars,
        review: sampleReviews[i % sampleReviews.length],
        createdAt: DateTime.now().subtract(Duration(days: i * 12 + 3)),
      );
    });
  }

  // ── Other users ───────────────────────────────────────────────────────────

  Future<List<ProfileMovieCard>> getUserFavorites(String userId) async {
    final movies = await MovieService.getMockMovies();
    final rng = Random(userId.hashCode);
    final shuffled = List<Movie>.from(movies)..shuffle(rng);
    return shuffled.take(10).map(_toCard).toList();
  }

  Future<List<ProfileMovieCard>> getUserWatched(String userId) async {
    final movies = await MovieService.getMockMovies();
    final rng = Random(userId.hashCode + 1);
    final shuffled = List<Movie>.from(movies)..shuffle(rng);
    return shuffled.take(22).map(_toCard).toList();
  }

  Future<List<ProfileRating>> getUserRatings(String userId) async {
    final movies = await MovieService.getMockMovies();
    final rng = Random(userId.hashCode + 2);
    final shuffled = List<Movie>.from(movies)..shuffle(rng);
    return shuffled.take(8).map((m) {
      final stars = [2.5, 3.0, 3.5, 4.0, 4.5][rng.nextInt(5)];
      return ProfileRating(
        movie: _toCard(m),
        stars: stars,
        review: null,
        createdAt: DateTime.now().subtract(Duration(days: rng.nextInt(365))),
      );
    }).toList();
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  ProfileMovieCard _toCard(Movie m) => ProfileMovieCard(
        tmdbId: m.id,
        title: m.title,
        posterUrl: m.posterUrl,
        backdropUrl: m.backdropUrl,
        voteAverage: m.voteAverage,
        releaseDate: m.releaseDate,
      );
}
