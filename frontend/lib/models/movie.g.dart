// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Genre _$GenreFromJson(Map<String, dynamic> json) =>
    Genre(id: (json['id'] as num).toInt(), name: json['name'] as String);

Map<String, dynamic> _$GenreToJson(Genre instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
};

Cast _$CastFromJson(Map<String, dynamic> json) => Cast(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  character: json['character'] as String,
  profilePath: json['profile_path'] as String?,
  order: (json['order'] as num).toInt(),
);

Map<String, dynamic> _$CastToJson(Cast instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'character': instance.character,
  'profile_path': instance.profilePath,
  'order': instance.order,
};

Crew _$CrewFromJson(Map<String, dynamic> json) => Crew(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  job: json['job'] as String,
  department: json['department'] as String,
  profilePath: json['profile_path'] as String?,
);

Map<String, dynamic> _$CrewToJson(Crew instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'job': instance.job,
  'department': instance.department,
  'profile_path': instance.profilePath,
};

Video _$VideoFromJson(Map<String, dynamic> json) => Video(
  id: json['id'] as String,
  key: json['key'] as String,
  name: json['name'] as String,
  site: json['site'] as String,
  type: json['type'] as String,
  official: json['official'] as bool,
);

Map<String, dynamic> _$VideoToJson(Video instance) => <String, dynamic>{
  'id': instance.id,
  'key': instance.key,
  'name': instance.name,
  'site': instance.site,
  'type': instance.type,
  'official': instance.official,
};

Movie _$MovieFromJson(Map<String, dynamic> json) => Movie(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  posterPath: json['poster_path'] as String?,
  backdropPath: json['backdrop_path'] as String?,
  overview: json['overview'] as String?,
  releaseDate: json['release_date'] as String?,
  voteAverage: (json['vote_average'] as num?)?.toDouble(),
  popularity: (json['popularity'] as num?)?.toDouble(),
  genres: (json['genres'] as List<dynamic>?)
      ?.map((e) => Genre.fromJson(e as Map<String, dynamic>))
      .toList(),
  cast: (Movie._readCast(json, 'cast') as List<dynamic>?)
      ?.map((e) => Cast.fromJson(e as Map<String, dynamic>))
      .toList(),
  crew: (Movie._readCrew(json, 'crew') as List<dynamic>?)
      ?.map((e) => Crew.fromJson(e as Map<String, dynamic>))
      .toList(),
  trailers: (Movie._readTrailers(json, 'trailers') as List<dynamic>?)
      ?.map((e) => Video.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$MovieToJson(Movie instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'poster_path': instance.posterPath,
  'backdrop_path': instance.backdropPath,
  'overview': instance.overview,
  'release_date': instance.releaseDate,
  'vote_average': instance.voteAverage,
  'popularity': instance.popularity,
  'genres': instance.genres,
  'cast': instance.cast,
  'crew': instance.crew,
  'trailers': instance.trailers,
};
