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

enum MatchStatus { waiting, voting, finished }

class MatchSession {
  final String id;
  final String code;
  final MatchStatus status;
  final String hostId;
  final List<Friend> participants;
  final List<ProfileMovieCard> movies;

  const MatchSession({
    required this.id,
    required this.code,
    required this.status,
    required this.hostId,
    required this.participants,
    this.movies = const [],
  });

  bool get isHost => hostId == 'mock-user-id';

  MatchSession copyWith({
    MatchStatus? status,
    List<Friend>? participants,
    List<ProfileMovieCard>? movies,
  }) =>
      MatchSession(
        id: id,
        code: code,
        status: status ?? this.status,
        hostId: hostId,
        participants: participants ?? this.participants,
        movies: movies ?? this.movies,
      );
}
