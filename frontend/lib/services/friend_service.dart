import '../models/friend_models.dart';
import '../models/profile_models.dart';
import 'api_service.dart';

// ── Service ───────────────────────────────────────────────────────────────────

class FriendService {
  final _api = ApiService();

  // ── Friends list (DB-backed) ─────────────────────────────────────────────────

  /// GET /friends -> list<UserPublicOut>
  Future<List<Friend>> getMyFriends() async {
    final data = await _api.get('/friends');
    return (data as List)
        .map((u) => Friend.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  /// GET /friends/requests -> { incoming: [...], outgoing: [...] }
  /// On n'expose ici que les demandes entrantes (à accepter/refuser).
  Future<List<FriendRequest>> getIncomingRequests() async {
    final data = await _api.get('/friends/requests');
    final incoming = (data is Map ? data['incoming'] as List? : null) ?? const [];
    return incoming
        .map((r) => FriendRequest.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// POST /friends/requests { username }
  Future<void> sendFriendRequest(String username) async {
    await _api.post('/friends/requests', {'username': username});
  }

  /// POST /friends/requests/{requester_id}/accept
  Future<void> acceptRequest(String requesterId) async {
    await _api.post('/friends/requests/$requesterId/accept', {});
  }

  /// POST /friends/requests/{requester_id}/reject
  Future<void> rejectRequest(String requesterId) async {
    await _api.post('/friends/requests/$requesterId/reject', {});
  }

  // ── Popular with friends (DB-backed) ────────────────────────────────────────

  /// GET /friends/popular -> list<MovieCard>
  /// Derniers films vus par les amis (agrégés, dédupliqués).
  Future<List<ProfileMovieCard>> getPopularWithFriends() async {
    final data = await _api.get('/friends/popular');
    return (data as List)
        .map((m) => ProfileMovieCard.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  // ── Match session (DB-backed, polling HTTP) ──────────────────────────────────

  /// POST /matches -> MatchSessionOut (crée la session, l'appelant est l'hôte).
  Future<MatchSession> createMatch() async {
    final data = await _api.post('/matches', {});
    return MatchSession.fromJson(data as Map<String, dynamic>);
  }

  /// POST /matches/join { code } -> MatchSessionOut
  Future<MatchSession> joinMatch(String code) async {
    final data =
        await _api.post('/matches/join', {'code': code.trim().toUpperCase()});
    return MatchSession.fromJson(data as Map<String, dynamic>);
  }

  /// GET /matches/{id} -> MatchSessionOut (pollé par le lobby / la phase de vote).
  Future<MatchSession> getMatch(String sessionId) async {
    final data = await _api.get('/matches/$sessionId');
    return MatchSession.fromJson(data as Map<String, dynamic>);
  }

  /// POST /matches/{id}/start -> MatchSessionOut (hôte : génère la liste de vote).
  Future<MatchSession> startMatch(String sessionId) async {
    final data = await _api.post('/matches/$sessionId/start', {});
    return MatchSession.fromJson(data as Map<String, dynamic>);
  }

  /// POST /matches/{id}/relaunch -> MatchSessionOut (hôte : régénère une liste).
  Future<MatchSession> relaunchMatch(String sessionId) async {
    final data = await _api.post('/matches/$sessionId/relaunch', {});
    return MatchSession.fromJson(data as Map<String, dynamic>);
  }

  /// POST /matches/{id}/choices { rejected_ids } -> MatchSessionOut
  /// `rejectedIds` = les tmdb_id sur lesquels l'utilisateur a voté "non".
  Future<MatchSession> submitChoices(
      String sessionId, List<int> rejectedIds) async {
    final data = await _api.post(
        '/matches/$sessionId/choices', {'rejected_ids': rejectedIds});
    return MatchSession.fromJson(data as Map<String, dynamic>);
  }

  /// POST /matches/cleanup — purge des sessions inactives (> 1h).
  Future<void> cleanupMatches() async {
    await _api.post('/matches/cleanup', {});
  }

  /// POST /matches/{id}/leave — retire l'appelant de la session (lobby, vote
  /// ou résultat). Best-effort : appelée quand l'utilisateur quitte l'écran
  /// d'attente ou de vote, pour que les autres participants ne restent pas
  /// bloqués à l'attendre.
  Future<void> leaveMatch(String sessionId) async {
    await _api.post('/matches/$sessionId/leave', {});
  }
}
