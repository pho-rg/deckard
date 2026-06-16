import logging
import math
from typing import Any

from sqlalchemy.orm import Session

from app.integrations.tmdb import TMDBClient, get_tmdb_client
from app.repositories.movie_repository import MovieRepository
from app.schemas.movie import MovieCard, MovieDetailOut, PagedMovies
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

    # ------------ TMDB passthrough (memory-cached) ------------

    def list_trending(self, *, language: str = "fr-FR") -> dict[str, Any]:
        return tmdb_cache.get_or_compute(
            "trending", ("trending", language), lambda: self.tmdb.trending(language=language)
        )

    def list_now_playing(
        self, *, region: str = "FR", page: int = 1, language: str = "fr-FR"
    ) -> dict[str, Any]:
        key = ("now_playing", region, page, language)
        return tmdb_cache.get_or_compute(
            "now_playing",
            key,
            lambda: self.tmdb.now_playing(region=region, page=page, language=language),
        )
