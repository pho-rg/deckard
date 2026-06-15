import 'dart:math';

import '../models/friend_models.dart';
import '../models/movie.dart';
import '../models/profile_models.dart';
import 'movie_service.dart';

// ── Mock data ─────────────────────────────────────────────────────────────────

final _mockMe = Friend(id: 'mock-user-id', username: 'hugo');

final _mockFriends = <Friend>[
  Friend(id: 'f1', username: 'jane_riefel'),
  Friend(id: 'f2', username: 'yann_brumir'),
  Friend(id: 'f3', username: 'sofia_delacroix'),
  Friend(id: 'f4', username: 'alex_martin'),
];

final _mockIncoming = <FriendRequest>[
  FriendRequest(
    requester: Friend(id: 'r1', username: 'pierre_dupont'),
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
  ),
];

// ── Service ───────────────────────────────────────────────────────────────────

class FriendService {
  // ── Friends list ───────────────────────────────────────────────────────────

  Future<List<Friend>> getMyFriends() async => _mockFriends;

  Future<List<FriendRequest>> getIncomingRequests() async => _mockIncoming;

  Future<void> sendFriendRequest(String username) async {
    // TODO: POST /friends/requests  { username }
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> acceptRequest(String requesterId) async {
    // TODO: POST /friends/requests/{requester_id}/accept
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> rejectRequest(String requesterId) async {
    // TODO: POST /friends/requests/{requester_id}/reject
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // ── Popular with friends ───────────────────────────────────────────────────

  Future<List<ProfileMovieCard>> getPopularWithFriends() async {
    final movies = await MovieService.getMockMovies();
    final rng = Random(42);
    final shuffled = List.of(movies)..shuffle(rng);
    return shuffled.take(12).map(_toCard).toList();
  }

  // ── Match session ──────────────────────────────────────────────────────────

  Future<MatchSession> createMatch() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return MatchSession(
      id: 'session-${DateTime.now().millisecondsSinceEpoch}',
      code: _generateCode(),
      status: MatchStatus.waiting,
      hostId: _mockMe.id,
      participants: [_mockMe],
    );
  }

  Future<MatchSession> joinMatch(String code) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return MatchSession(
      id: 'session-joined',
      code: code.toUpperCase(),
      status: MatchStatus.waiting,
      hostId: 'f1', // someone else is host
      participants: [_mockFriends[0], _mockMe],
    );
  }

  /// Called when host presses GO. Returns the movies to vote on.
  Future<List<ProfileMovieCard>> startMatch(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final movies = await MovieService.getMockMovies();
    final rng = Random(sessionId.hashCode);
    final shuffled = List.of(movies)..shuffle(rng);
    return shuffled.take(10).map(_toCard).toList();
  }

  /// Simulates submitting choices and getting unanimous results back.
  Future<List<ProfileMovieCard>> submitChoices(
    List<ProfileMovieCard> movies,
    Map<int, bool> choices,
  ) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final selected = movies.where((m) => choices[m.tmdbId] == true).toList();
    if (selected.isEmpty) return [];
    // Simulate: ~40% of selected make unanimity
    final rng = Random();
    final unanimous =
        selected.where((_) => rng.nextDouble() < 0.45).take(4).toList();
    return unanimous;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  ProfileMovieCard _toCard(Movie m) => ProfileMovieCard(
        tmdbId: m.id,
        title: m.title,
        posterUrl: m.posterUrl,
        backdropUrl: m.backdropUrl,
        voteAverage: m.voteAverage,
        releaseDate: m.releaseDate,
      );

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    return List.generate(5, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
