// Models matching backend schemas:
//   UserOut            → ProfileUser
//   MovieCard          → ProfileMovieCard
//   RatingWithMovieOut → ProfileRating

class ProfileUser {
  final String id;
  final String username;
  final String email;
  final String language;
  final String region;
  final DateTime createdAt;

  ProfileUser({
    required this.id,
    required this.username,
    required this.email,
    required this.language,
    required this.region,
    required this.createdAt,
  });

  factory ProfileUser.fromJson(Map<String, dynamic> json) => ProfileUser(
        id: json['id'] as String,
        username: json['username'] as String,
        email: json['email'] as String,
        language: json['language'] as String,
        region: json['region'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  /// Public projection of another user (UserProfileOut): no email/language/region.
  factory ProfileUser.fromPublicJson(Map<String, dynamic> json) => ProfileUser(
        id: json['id'] as String,
        username: json['username'] as String,
        email: '',
        language: '',
        region: '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class ProfileMovieCard {
  final int tmdbId;
  final String title;
  final String? posterUrl;
  final String? backdropUrl;
  final double? voteAverage;
  final String? releaseDate; // "YYYY-MM-DD"

  ProfileMovieCard({
    required this.tmdbId,
    required this.title,
    this.posterUrl,
    this.backdropUrl,
    this.voteAverage,
    this.releaseDate,
  });

  factory ProfileMovieCard.fromJson(Map<String, dynamic> json) =>
      ProfileMovieCard(
        tmdbId: (json['tmdb_id'] as num).toInt(),
        title: json['title'] as String,
        posterUrl: json['poster_url'] as String?,
        backdropUrl: json['backdrop_url'] as String?,
        // vote_average peut arriver en String (Decimal sérialisé) ou en num.
        voteAverage: _toDouble(json['vote_average']),
        releaseDate: json['release_date'] as String?,
      );

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String get year => releaseDate?.split('-').first ?? '';
}

class ProfileRating {
  final ProfileMovieCard movie;
  final double stars;
  final String? review;
  final DateTime createdAt;

  ProfileRating({
    required this.movie,
    required this.stars,
    this.review,
    required this.createdAt,
  });

  factory ProfileRating.fromJson(Map<String, dynamic> json) => ProfileRating(
        movie: ProfileMovieCard.fromJson(
            json['movie'] as Map<String, dynamic>),
        stars: (json['stars'] as num).toDouble(),
        review: json['review'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
