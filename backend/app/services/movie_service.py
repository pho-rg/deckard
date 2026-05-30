import logging
from typing import Any

from sqlalchemy.orm import Session

from app.integrations.tmdb import TMDBClient, get_tmdb_client
from app.repositories.movie_repository import MovieRepository
from app.schemas.movie import MovieDetailOut
from app.services import presenter, tmdb_cache
from app.services.localization import to_iso2

logger = logging.getLogger(__name__)


class MovieService:
    def __init__(self, db: Session, tmdb: TMDBClient | None = None):
        self.db = db
        self.tmdb = tmdb or get_tmdb_client()
        self.repo = MovieRepository(db)

    def get_movie_details(self, tmdb_id: int, *, language: str = "fr-FR") -> MovieDetailOut:
        lang_iso = to_iso2(language)
        movie = self.repo.get_full(tmdb_id)
        if movie is None:
            logger.info("cache miss for movie %s — fetching TMDB (safety net)", tmdb_id)
            movie = self._sync(tmdb_id, language=language)
        return presenter.movie_detail(movie, lang_iso)

    def get_featured(self, *, language: str = "fr-FR") -> MovieDetailOut | None:
        movie = self.repo.get_featured()
        if movie is None:
            return None
        return presenter.movie_detail(movie, to_iso2(language))

    # ------------ list endpoints (TMDB passthrough, memory-cached) ------------

    def search_movies(
        self, query: str, *, page: int = 1, language: str = "fr-FR"
    ) -> dict[str, Any]:
        key = ("search", query.strip().lower(), page, language)
        return tmdb_cache.get_or_compute(
            "search",
            key,
            lambda: self.tmdb.search_movies(query, page=page, language=language),
        )

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

    # ------------ internals ------------

    def _sync(self, tmdb_id: int, *, language: str):
        lang_iso = to_iso2(language)
        movie_data = self.tmdb.get_movie(tmdb_id, language=language)
        credits_data = self.tmdb.get_movie_credits(tmdb_id, language=language)
        videos_data = self.tmdb.get_movie_videos(tmdb_id, language=language)

        try:
            self.repo.upsert_movie(movie_data, lang_iso)
            self.repo.replace_genres(tmdb_id, movie_data.get("genres", []), lang_iso)
            self.repo.replace_credits(tmdb_id, credits_data, lang_iso)
            self.repo.replace_video(tmdb_id, videos_data, lang_iso)
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise

        movie = self.repo.get_full(tmdb_id)
        assert movie is not None, "movie should exist right after sync"
        return movie
