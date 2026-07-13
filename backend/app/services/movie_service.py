import logging
import math
from decimal import Decimal
from typing import Any

from sqlalchemy.orm import Session

from app.integrations.tmdb import TMDBClient, TMDBError, get_tmdb_client
from app.repositories.movie_repository import MovieRepository
from app.repositories.rating_repository import RatingRepository
from app.repositories.vector_repository import VectorRepository
from app.schemas.movie import (
    MovieCard,
    MovieDetailOut,
    PagedMovies,
    PagedPersons,
    PersonCard,
)
from app.schemas.user_movie import MovieRatingsOut
from app.services import presenter, tmdb_cache
from app.services.localization import to_iso2

logger = logging.getLogger(__name__)

_SEARCH_PAGE_SIZE = 20


class MovieNotFound(Exception):
    """The requested movie is not present in our database."""

    def __init__(self, tmdb_id: int):
        super().__init__(f"Movie {tmdb_id} not found in database")
        self.tmdb_id = tmdb_id


class MovieService:
    def __init__(self, db: Session, tmdb: TMDBClient | None = None):
        self.db = db
        # TMDB is only needed for the trending / now-playing passthroughs.
        self._tmdb = tmdb
        self.repo = MovieRepository(db)
        self.ratings = RatingRepository(db)
        self.vectors = VectorRepository(db)

    @property
    def tmdb(self) -> TMDBClient:
        if self._tmdb is None:
            self._tmdb = get_tmdb_client()
        return self._tmdb

    # ------------ DB-sourced (our imported catalogue) ------------

    def get_movie_details(self, tmdb_id: int, *, language: str = "fr-FR") -> MovieDetailOut:
        movie = self.repo.get_full(tmdb_id)
        if movie is None:
            raise MovieNotFound(tmdb_id)
        return presenter.movie_detail(movie, to_iso2(language))

    def get_tmdb_rating(self, tmdb_id: int, *, language: str = "fr-FR") -> Decimal | None:
        """Fetch the TMDB community rating (separate from Deckard ratings).

        Called from a dedicated endpoint so the movie detail response
        is never blocked by TMDB latency.
        """
        try:
            data = self.tmdb.movie(tmdb_id, language=language)
        except TMDBError:
            return None
        va = data.get("vote_average")
        if va is None:
            return None
        # TMDB 0-10 → Deckard 0-5
        return Decimal(str(round(float(va) / 2, 1)))

    def get_featured(self, *, language: str = "fr-FR") -> MovieDetailOut | None:
        movie = self.repo.get_featured()
        if movie is None:
            return None
        return presenter.movie_detail(movie, to_iso2(language))

    def cards_by_ids(
        self, tmdb_ids: list[int], *, language: str = "fr-FR"
    ) -> list[MovieCard]:
        # Resolve a caller-provided tmdb_id list to movie cards (onboarding grid).
        # Preserves the input order; unknown ids are skipped.
        iso = to_iso2(language)
        by_id = {m.tmdb_id: m for m in self.repo.list_by_ids(tmdb_ids)}
        return [
            presenter.movie_card(by_id[i], iso) for i in tmdb_ids if i in by_id
        ]

    def search_movies(
        self, query: str, *, page: int = 1, language: str = "fr-FR"
    ) -> PagedMovies:
        iso = to_iso2(language)
        movies, total = self.repo.search(query, page=page, page_size=_SEARCH_PAGE_SIZE)
        total_pages = max(1, math.ceil(total / _SEARCH_PAGE_SIZE)) if total else 1
        return PagedMovies(
            page=page,
            total_pages=total_pages,
            total_results=total,
            results=[presenter.movie_summary(m, iso) for m in movies],
        )

    def list_similar(
        self, tmdb_id: int, *, limit: int = 10, language: str = "fr-FR"
    ) -> list[MovieCard]:
        iso = to_iso2(language)

        # pgvector similarity — fallback to random if movie not in vecteur table
        similar_ids = self.vectors.similar(tmdb_id, limit=limit)
        if similar_ids:
            movies_unord = self.repo.list_by_ids(similar_ids)
            by_id = {m.tmdb_id: m for m in movies_unord}
            # Preserve vector similarity order; filter out movies without poster
            movies = [by_id[i] for i in similar_ids
                      if i in by_id and by_id[i].poster_path][:limit]
        else:
            movies = self.repo.random_similar(tmdb_id, limit=limit)

        return [presenter.movie_card(m, iso) for m in movies]

    def get_movie_ratings(self, tmdb_id: int) -> MovieRatingsOut:
        # Public aggregate (average/count/distribution) + the text reviews.
        # The average is recomputed from the DB on each read, so it reflects
        # a user's new rating immediately.
        average, count, distribution = self.ratings.stats_for_movie(tmdb_id)
        reviews = self.ratings.list_reviews_for_movie(tmdb_id)
        return presenter.movie_ratings(average, count, distribution, reviews)

    # ------------ people (DB-sourced) ------------

    def search_persons(self, query: str, *, page: int = 1) -> PagedPersons:
        persons, total = self.repo.search_persons(
            query, page=page, page_size=_SEARCH_PAGE_SIZE
        )
        total_pages = max(1, math.ceil(total / _SEARCH_PAGE_SIZE)) if total else 1
        return PagedPersons(
            page=page,
            total_pages=total_pages,
            total_results=total,
            results=[presenter.person_card(p) for p in persons],
        )

    def get_person(self, person_id: int) -> PersonCard | None:
        person = self.repo.get_person(person_id)
        if person is None:
            return None
        return presenter.person_card(person)

    def person_filmography(
        self, person_id: int, *, language: str = "fr-FR"
    ) -> list[MovieCard]:
        iso = to_iso2(language)
        movies = self.repo.filmography(person_id)
        return [presenter.movie_card(m, iso) for m in movies]

    # ------------ TMDB passthrough (memory-cached) ------------

    def list_trending(self, *, language: str = "fr-FR") -> dict[str, Any]:
        return tmdb_cache.get_or_compute(
            "trending",
            ("trending", language),
            lambda: self._with_catalogue_images(self.tmdb.trending(language=language)),
        )

    def list_now_playing(
        self, *, region: str = "FR", page: int = 1, language: str = "fr-FR"
    ) -> dict[str, Any]:
        key = ("now_playing", region, page, language)
        return tmdb_cache.get_or_compute(
            "now_playing",
            key,
            lambda: self._with_catalogue_images(
                self.tmdb.now_playing(region=region, page=page, language=language)
            ),
        )

    def _with_catalogue_images(self, payload: dict[str, Any]) -> dict[str, Any]:
        """Overlay poster/backdrop from our DB for movies already in the
        catalogue, so trending/now-playing (raw TMDB) match what the detail
        page shows (DB-sourced) — TMDB's live poster can drift from the one
        we imported/last synced, which otherwise makes the same movie appear
        with two different posters depending on where it's shown.
        """
        results = payload.get("results") or []
        ids = [r["id"] for r in results if r.get("id") is not None]
        by_id = {m.tmdb_id: m for m in self.repo.list_by_ids(ids)}
        for r in results:
            movie = by_id.get(r.get("id"))
            if movie is not None:
                r["poster_path"] = movie.poster_path
                r["backdrop_path"] = movie.backdrop_path
        return payload
