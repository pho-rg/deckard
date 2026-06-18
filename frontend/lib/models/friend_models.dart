import '../services/auth_service.dart';
import 'profile_models.dart';

class Friend {
  final String id;
  final String username;

  const Friend({required this.id, required this.username});

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
        id: json['id'] as String,
        username: json['username'] as String,
      );

  String get initials => username.length >= 2
      ? username.substring(0, 2).toUpperCase()
      : username.toUpperCase();
}

class FriendRequest {
  final Friend requester;
  final DateTime createdAt;

  const FriendRequest({required this.requester, required this.createdAt});

  /// Maps the backend `FriendRequestOut` { requester, addressee, created_at }.
  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
        requester: Friend.fromJson(json['requester'] as Map<String, dynamic>),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// Statut d'une session match. Mappe le backend :
/// not_started → waiting, in_progress → voting, finished → finished.
enum MatchStatus { waiting, voting, finished }

MatchStatus _statusFromString(String? s) {
  switch (s) {
    case 'in_progress':
      return MatchStatus.voting;
    case 'finished':
      return MatchStatus.finished;
    case 'not_started':
    default:
      return MatchStatus.waiting;
  }
}

/// Session match, mappe le backend `MatchSessionOut`.
class MatchSession {
  final String id;
  final String code;
  final MatchStatus status;
  final Friend host;
  final List<Friend> participants;
  final int participantCount;
  final int choicesReceived;
  final List<ProfileMovieCard> movies; // liste de vote
  final List<ProfileMovieCard> result; // films unanimes (si terminé)

  const MatchSession({
    required this.id,
    required this.code,
    required this.status,
    required this.host,
    required this.participants,
    required this.participantCount,
    required this.choicesReceived,
    this.movies = const [],
    this.result = const [],
  });

  String get hostId => host.id;

  /// Vrai si l'utilisateur connecté est l'hôte de la session.
  bool get isHost =>
      AuthService.currentUserId != null &&
      host.id == AuthService.currentUserId;

  factory MatchSession.fromJson(Map<String, dynamic> json) {
    List<ProfileMovieCard> cards(String key) =>
        ((json[key] as List?) ?? const [])
            .map((m) => ProfileMovieCard.fromJson(m as Map<String, dynamic>))
            .toList();

    return MatchSession(
      id: json['id'] as String,
      code: json['code'] as String,
      status: _statusFromString(json['status'] as String?),
      host: Friend.fromJson(json['host'] as Map<String, dynamic>),
      participants: ((json['participants'] as List?) ?? const [])
          .map((p) => Friend.fromJson(p as Map<String, dynamic>))
          .toList(),
      participantCount: (json['participant_count'] as num?)?.toInt() ?? 0,
      choicesReceived: (json['choices_received'] as num?)?.toInt() ?? 0,
      movies: cards('movies'),
      result: cards('result'),
    );
  }
}
