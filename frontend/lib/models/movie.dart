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
