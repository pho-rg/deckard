import '../models/profile_models.dart';
import 'api_service.dart';

/// Profil utilisateur câblé au backend (DB).
/// Routes: GET/PUT /users/me, /users/me/{favorites,watched,ratings},
/// et /users/{id}/{favorites,watched,ratings} pour les autres utilisateurs.
class ProfileService {
  final _api = ApiService();

  // ── Current user ──────────────────────────────────────────────────────────

  /// GET /users/me -> UserOut
  Future<ProfileUser> getMe() async {
    final data = await _api.get('/users/me');
    return ProfileUser.fromJson(data as Map<String, dynamic>);
  }

  /// PUT /users/me { username?, email?, language? } -> UserOut
  ///
  /// NB: la réinitialisation du mot de passe est mise de côté pour l'instant —
  /// les paramètres password sont acceptés mais non transmis au backend.
  Future<ProfileUser> updateMe({
    String? username,
    String? email,
    String? language,
    String? currentPassword, // ignoré pour l'instant
    String? newPassword, // ignoré pour l'instant
  }) async {
    final body = <String, dynamic>{
      if (username != null) 'username': username,
      if (email != null) 'email': email,
      if (language != null) 'language': language,
    };
    final data = await _api.put('/users/me', body);
    return ProfileUser.fromJson(data as Map<String, dynamic>);
  }

  /// GET /users/me/favorites -> list<MovieCard>
  Future<List<ProfileMovieCard>> getMyFavorites() =>
      _cards('/users/me/favorites');

  /// GET /users/me/watched -> list<MovieCard>
  Future<List<ProfileMovieCard>> getMyWatched() => _cards('/users/me/watched');

  /// GET /users/me/ratings -> list<RatingWithMovieOut>
  Future<List<ProfileRating>> getMyRatings() => _ratings('/users/me/ratings');

  // ── Other users (gated par l'amitié côté backend) ──────────────────────────

  /// GET /users/{id} -> UserProfileOut (id, username, created_at)
  Future<ProfileUser> getUser(String userId) async {
    final data = await _api.get('/users/$userId');
    return ProfileUser.fromPublicJson(data as Map<String, dynamic>);
  }

  Future<List<ProfileMovieCard>> getUserFavorites(String userId) =>
      _cards('/users/$userId/favorites');

  Future<List<ProfileMovieCard>> getUserWatched(String userId) =>
      _cards('/users/$userId/watched');

  Future<List<ProfileRating>> getUserRatings(String userId) =>
      _ratings('/users/$userId/ratings');

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<List<ProfileMovieCard>> _cards(String endpoint) async {
    final data = await _api.get(endpoint);
    return (data as List)
        .map((m) => ProfileMovieCard.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProfileRating>> _ratings(String endpoint) async {
    final data = await _api.get(endpoint);
    return (data as List)
        .map((r) => ProfileRating.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
