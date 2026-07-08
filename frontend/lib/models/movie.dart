import 'package:json_annotation/json_annotation.dart';

part 'movie.g.dart';

@JsonSerializable()
class Genre {
  final int id;
  final String name;

  Genre({required this.id, required this.name});

  factory Genre.fromJson(Map<String, dynamic> json) => _$GenreFromJson(json);
  Map<String, dynamic> toJson() => _$GenreToJson(this);
}

@JsonSerializable()
class Cast {
  final int id;
  final String name;
  final String character;
  @JsonKey(name: 'profile_path')
  final String? profilePath;
  final int order;

  Cast({
    required this.id,
    required this.name,
    required this.character,
    this.profilePath,
    required this.order,
  });

  factory Cast.fromJson(Map<String, dynamic> json) => _$CastFromJson(json);
  Map<String, dynamic> toJson() => _$CastToJson(this);

  String get profileUrl {
    if (profilePath == null) return 'https://via.placeholder.com/185x278?text=No+Image';
    if (profilePath!.startsWith('http')) return profilePath!;
    return 'https://image.tmdb.org/t/p/w185$profilePath';
  }
}

@JsonSerializable()
class Crew {
  final int id;
  final String name;
  final String job;
  final String department;
  @JsonKey(name: 'profile_path')
  final String? profilePath;

  Crew({
    required this.id,
    required this.name,
    required this.job,
    required this.department,
    this.profilePath,
  });

  factory Crew.fromJson(Map<String, dynamic> json) => _$CrewFromJson(json);
  Map<String, dynamic> toJson() => _$CrewToJson(this);

  String get profileUrl {
    if (profilePath == null || profilePath!.isEmpty) return '';
    if (profilePath!.startsWith('http')) return profilePath!;
    return 'https://image.tmdb.org/t/p/w185$profilePath';
  }
}

@JsonSerializable()
class Video {
  final String id;
  final String key;
  final String name;
  final String site;
  final String type;
  final bool official;

  Video({
    required this.id,
    required this.key,
    required this.name,
    required this.site,
    required this.type,
    required this.official,
  });

  factory Video.fromJson(Map<String, dynamic> json) => _$VideoFromJson(json);
  Map<String, dynamic> toJson() => _$VideoToJson(this);

  String get youtubeUrl => 'https://www.youtube.com/watch?v=$key';
}

@JsonSerializable()
class Movie {
  final int id;
  final String title;
  @JsonKey(name: 'poster_path')
  final String? posterPath;
  @JsonKey(name: 'backdrop_path')
  final String? backdropPath;
  final String? overview;
  @JsonKey(name: 'release_date')
  final String? releaseDate;
  @JsonKey(name: 'vote_average')
  final double? voteAverage;
  final double? popularity;
  final List<Genre>? genres;
  @JsonKey(readValue: _readCast)
  final List<Cast>? cast;
  @JsonKey(readValue: _readCrew)
  final List<Crew>? crew;
  @JsonKey(readValue: _readTrailers)
  final List<Video>? trailers;

  Movie({
    required this.id,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.overview,
    this.releaseDate,
    this.voteAverage,
    this.popularity,
    this.genres,
    this.cast,
    this.crew,
    this.trailers,
  });

  static Object? _readCast(Map json, String key) {
    return json['credits']?['cast'];
  }

  static Object? _readCrew(Map json, String key) {
    return json['credits']?['crew'];
  }

  static Object? _readTrailers(Map json, String key) {
    final videos = json['videos']?['results'] as List?;
    if (videos == null) return null;
    return videos
        .where((v) => v['site'] == 'YouTube' && v['type'] == 'Trailer')
        .toList();
  }

  factory Movie.fromJson(Map<String, dynamic> json) => _$MovieFromJson(json);
  Map<String, dynamic> toJson() => _$MovieToJson(this);

  /// The backend can serialise numeric fields as either a number or a string
  /// (e.g. vote_average "7.0"). Coerce both forms safely.
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.parse(v.toString());
  }

  /// Build a Movie from the backend `MovieCard` shape (DB-backed):
  /// { tmdb_id, title, original_title, overview, release_date,
  ///   vote_average, poster_url, backdrop_url, genres: [{tmdb_id, name}] }.
  /// The URL fields are already absolute; posterUrl/backdropUrl getters
  /// pass http URLs through unchanged.
  factory Movie.fromCard(Map<String, dynamic> json) {
    final genresJson = (json['genres'] as List?) ?? const [];
    return Movie(
      id: _toInt(json['tmdb_id']),
      title: (json['title'] ?? json['original_title'] ?? '') as String,
      posterPath: json['poster_url'] as String?,
      backdropPath: json['backdrop_url'] as String?,
      overview: json['overview'] as String?,
      releaseDate: json['release_date'] as String?,
      voteAverage: _toDouble(json['vote_average']),
      genres: genresJson
          .map((g) => Genre(
                id: _toInt(g['tmdb_id']),
                name: (g['name'] ?? '') as String,
              ))
          .toList(),
    );
  }

  /// Build a Movie from the backend `MovieDetailOut` shape (DB-backed, full):
  /// genres [{tmdb_id, name}], cast [{person:{tmdb_id,name,profile_url},
  /// character, order}], crew [{person:{...}, job, department}], and
  /// trailer_youtube_key. URL fields are absolute (getters pass them through).
  factory Movie.fromDetail(Map<String, dynamic> json) {
    final genresJson = (json['genres'] as List?) ?? const [];
    final castJson = (json['cast'] as List?) ?? const [];
    final crewJson = (json['crew'] as List?) ?? const [];
    final trailerKey = json['trailer_youtube_key'] as String?;

    return Movie(
      id: _toInt(json['tmdb_id']),
      title: (json['title'] ?? json['original_title'] ?? '') as String,
      posterPath: json['poster_url'] as String?,
      backdropPath: json['backdrop_url'] as String?,
      overview: json['overview'] as String?,
      releaseDate: json['release_date'] as String?,
      voteAverage: _toDouble(json['vote_average']),
      genres: genresJson
          .map((g) => Genre(
                id: _toInt(g['tmdb_id']),
                name: (g['name'] ?? '') as String,
              ))
          .toList(),
      cast: castJson.map((c) {
        final p = c['person'] as Map<String, dynamic>;
        return Cast(
          id: _toInt(p['tmdb_id']),
          name: (p['name'] ?? '') as String,
          character: (c['character'] ?? '') as String,
          profilePath: p['profile_url'] as String?,
          order: _toDouble(c['order'])?.toInt() ?? 0,
        );
      }).toList(),
      crew: crewJson.map((c) {
        final p = c['person'] as Map<String, dynamic>;
        return Crew(
          id: _toInt(p['tmdb_id']),
          name: (p['name'] ?? '') as String,
          job: (c['job'] ?? '') as String,
          department: (c['department'] ?? '') as String,
          profilePath: p['profile_url'] as String?,
        );
      }).toList(),
      trailers: (trailerKey != null && trailerKey.isNotEmpty)
          ? [
              Video(
                id: trailerKey,
                key: trailerKey,
                name: 'Trailer',
                site: 'YouTube',
                type: 'Trailer',
                official: true,
              )
            ]
          : null,
    );
  }

  String get posterUrl {
    if (posterPath == null) return 'https://via.placeholder.com/500x750?text=No+Poster';
    if (posterPath!.startsWith('http')) return posterPath!;
    return 'https://image.tmdb.org/t/p/w500$posterPath';
  }

  String get backdropUrl {
    if (backdropPath == null) return 'https://via.placeholder.com/1280x720?text=No+Backdrop';
    if (backdropPath!.startsWith('http')) return backdropPath!;
    return 'https://image.tmdb.org/t/p/w1280$backdropPath';
  }

  String? get officialTrailerUrl {
    if (trailers == null || trailers!.isEmpty) return null;
    final official = trailers!.firstWhere((v) => v.official, orElse: () => trailers!.first);
    return official.youtubeUrl;
  }
}

/// The signed-in user's relationship to a movie.
/// Maps the backend `UserStateOut`:
/// { is_favorite, in_watchlist, is_watched, user_rating, user_review }.
class MovieUserState {
  final bool isFavorite;
  final bool inWatchlist;
  final bool isWatched;
  final double? userRating; // 0.0–5.0 in 0.5 steps, or null
  final String? userReview;

  MovieUserState({
    required this.isFavorite,
    required this.inWatchlist,
    required this.isWatched,
    this.userRating,
    this.userReview,
  });

  factory MovieUserState.fromJson(Map<String, dynamic> json) {
    return MovieUserState(
      isFavorite: json['is_favorite'] as bool? ?? false,
      inWatchlist: json['in_watchlist'] as bool? ?? false,
      isWatched: json['is_watched'] as bool? ?? false,
      userRating: (json['user_rating'] as num?)?.toDouble(),
      userReview: json['user_review'] as String?,
    );
  }

  static MovieUserState empty() => MovieUserState(
        isFavorite: false,
        inWatchlist: false,
        isWatched: false,
      );
}

/// A public review on a movie. Maps the backend `MovieReviewOut`:
/// { user: { id, username }, stars, review, created_at }.
class MovieReview {
  final String userId;
  final String username;
  final double stars; // 0.0–5.0 in 0.5 steps
  final String review;
  final DateTime createdAt;

  MovieReview({
    required this.userId,
    required this.username,
    required this.stars,
    required this.review,
    required this.createdAt,
  });

  factory MovieReview.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return MovieReview(
      userId: user['id'] as String,
      username: (user['username'] ?? '') as String,
      stars: (json['stars'] as num?)?.toDouble() ?? 0.0,
      review: (json['review'] ?? '') as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Aggregate ratings + public reviews for a movie. Maps `MovieRatingsOut`:
/// { average, count, distribution[10], reviews[] }.
class MovieRatings {
  final double? average; // 0.0–5.0 stars, or null
  final int count;
  final List<int> distribution; // 10 half-star buckets 0.5..5.0
  final List<MovieReview> reviews;

  MovieRatings({
    required this.average,
    required this.count,
    required this.distribution,
    required this.reviews,
  });

  factory MovieRatings.fromJson(Map<String, dynamic> json) => MovieRatings(
        average: (json['average'] as num?)?.toDouble(),
        count: (json['count'] as num?)?.toInt() ?? 0,
        distribution: ((json['distribution'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        reviews: ((json['reviews'] as List?) ?? const [])
            .map((r) => MovieReview.fromJson(r as Map<String, dynamic>))
            .toList(),
      );

  static MovieRatings empty() => MovieRatings(
        average: null,
        count: 0,
        distribution: List.filled(10, 0),
        reviews: const [],
      );
}

/// A person (cast or crew) returned by the DB-backed person search.
/// Maps the backend `PersonCard`:
/// { tmdb_id, name, known_for_department, profile_url }.
class PersonResult {
  final int id;
  final String name;
  final String? knownForDepartment;
  final String? profilePath;

  PersonResult({
    required this.id,
    required this.name,
    this.knownForDepartment,
    this.profilePath,
  });

  factory PersonResult.fromJson(Map<String, dynamic> json) {
    return PersonResult(
      id: Movie._toInt(json['tmdb_id']),
      name: (json['name'] ?? '') as String,
      knownForDepartment: json['known_for_department'] as String?,
      profilePath: json['profile_url'] as String?,
    );
  }

  /// Absolute URL passes through; otherwise build a TMDB profile URL.
  String get profileUrl {
    if (profilePath == null || profilePath!.isEmpty) return '';
    if (profilePath!.startsWith('http')) return profilePath!;
    return 'https://image.tmdb.org/t/p/w185$profilePath';
  }
}
