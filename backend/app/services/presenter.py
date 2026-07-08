"""Assemble localized API responses from ORM objects.

Relationships must be eager-loaded by the repository before calling these.
"""

from __future__ import annotations

from app.models.movie import Movie
from app.models.rating import Rating
from app.schemas.movie import (
    CastOut,
    CrewOut,
    GenreOut,
    MovieCard,
    MovieDetailOut,
    MovieSummary,
    PersonCard,
    PersonOut,
)
from app.schemas.movie import _image_url
from app.schemas.friend import UserPublicOut
from app.schemas.user_movie import (
    MovieRatingsOut,
    MovieReviewOut,
    RatingWithMovieOut,
)
from app.services.localization import pick_content


def _movie_title(movie: Movie, lang_iso: str) -> tuple[str, str | None, str | None]:
    content = pick_content(movie.contents, lang_iso)
    if content is None:
        return (movie.original_title or "", None, None)
    return (content.title, content.overview, content.tag_line)


def _person_out(person, lang_iso: str) -> PersonOut:
    return PersonOut(
        tmdb_id=person.tmdb_id,
        name=person.name or "",
        profile_url=_image_url(person.profile_path, "w185"),
    )


def person_card(person) -> PersonCard:
    # Person names are language-agnostic in our catalogue (stored on Person).
    return PersonCard(
        tmdb_id=person.tmdb_id,
        name=person.name or "",
        known_for_department=person.known_for_department,
        profile_url=_image_url(person.profile_path, "w185"),
    )


def movie_card(movie: Movie, lang_iso: str) -> MovieCard:
    title, overview, _ = _movie_title(movie, lang_iso)
    genres = []
    for g in movie.genres:
        gc = pick_content(g.contents, lang_iso)
        genres.append(GenreOut(tmdb_id=g.tmdb_id, name=gc.name if gc else ""))
    return MovieCard(
        tmdb_id=movie.tmdb_id,
        title=title,
        original_title=movie.original_title,
        overview=overview,
        release_date=movie.release_date,
        vote_average=movie.vote_average,
        poster_url=_image_url(movie.poster_path, "w500"),
        backdrop_url=_image_url(movie.backdrop_path, "w1280"),
        genres=genres,
    )


def movie_summary(movie: Movie, lang_iso: str) -> MovieSummary:
    """DB-sourced summary in the same shape as a TMDB list entry."""
    title, overview, _ = _movie_title(movie, lang_iso)
    return MovieSummary(
        tmdb_id=movie.tmdb_id,
        title=title,
        original_title=movie.original_title,
        overview=overview,
        release_date=movie.release_date,
        vote_average=movie.vote_average,
        genre_ids=[g.tmdb_id for g in movie.genres],
        poster_path=movie.poster_path,
        backdrop_path=movie.backdrop_path,
    )


def movie_detail(movie: Movie, lang_iso: str) -> MovieDetailOut:
    title, overview, tag_line = _movie_title(movie, lang_iso)

    genres = []
    for g in movie.genres:
        gc = pick_content(g.contents, lang_iso)
        genres.append(GenreOut(tmdb_id=g.tmdb_id, name=gc.name if gc else ""))

    cast = [
        CastOut(
            person=_person_out(c.person, lang_iso),
            character=c.character,
            order=c.cast_order,
        )
        for c in movie.cast
    ]
    crew = [
        CrewOut(
            person=_person_out(c.person, lang_iso),
            job=c.job,
            department=c.department,
        )
        for c in movie.crew
    ]

    video = pick_content(movie.videos, lang_iso)

    return MovieDetailOut(
        tmdb_id=movie.tmdb_id,
        imdb_id=movie.imdb_id,
        title=title,
        original_title=movie.original_title,
        overview=overview,
        tag_line=tag_line,
        release_date=movie.release_date,
        runtime=movie.runtime,
        original_language=movie.original_language,
        vote_average=movie.vote_average,
        status=movie.status.value if movie.status else None,
        poster_url=_image_url(movie.poster_path, "w500"),
        backdrop_url=_image_url(movie.backdrop_path, "w1280"),
        trailer_youtube_key=video.youtube_key if video else None,
        genres=genres,
        cast=cast,
        crew=crew,
    )


def rating_with_movie(rating: Rating, lang_iso: str) -> RatingWithMovieOut:
    return RatingWithMovieOut(
        movie=movie_card(rating.movie, lang_iso),
        stars=rating.rating / 2,
        review=rating.review,
        created_at=rating.created_at,
        updated_at=rating.updated_at,
    )


def movie_review(rating: Rating) -> MovieReviewOut:
    return MovieReviewOut(
        user=UserPublicOut(id=rating.user.id, username=rating.user.username),
        stars=rating.rating / 2,
        review=rating.review or "",
        created_at=rating.created_at,
    )


def movie_ratings(
    average: float | None,
    count: int,
    distribution: list[int],
    reviews: list[Rating],
) -> MovieRatingsOut:
    return MovieRatingsOut(
        average=round(average, 1) if average is not None else None,
        count=count,
        distribution=distribution,
        reviews=[movie_review(r) for r in reviews],
    )
