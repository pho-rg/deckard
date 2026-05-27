import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.config import settings
from app.integrations.tmdb import TMDBClient, get_tmdb_client
from app.models.movie import Movie
from app.repositories.movie_repository import MovieRepository

logger = logging.getLogger(__name__)


class MovieService:
    """Orchestrates the lazy cache for movie details.

    - Cache hit (movie present, fresh)  → return it
    - Cache miss or stale               → fetch TMDB, persist, return reloaded movie
    """

    def __init__(self, db: Session, tmdb: TMDBClient | None = None):
        self.db = db
        self.tmdb = tmdb or get_tmdb_client()
        self.repo = MovieRepository(db)

    def get_movie_details(self, tmdb_id: int, *, language: str = "fr-FR") -> Movie:
        cached = self.repo.get_full(tmdb_id)
        if cached and self._is_fresh(cached):
            logger.debug("cache hit for movie %s", tmdb_id)
            return cached

        logger.info(
            "%s for movie %s — fetching TMDB",
            "cache stale" if cached else "cache miss",
            tmdb_id,
        )
        return self._sync(tmdb_id, language=language)

    # ------------ internals ------------

    def _is_fresh(self, movie: Movie) -> bool:
        ttl = timedelta(days=settings.movie_cache_ttl_days)
        return movie.last_synced_at + ttl > datetime.now(timezone.utc)

    def _sync(self, tmdb_id: int, *, language: str) -> Movie:
        movie_data = self.tmdb.get_movie(tmdb_id, language=language)
        credits_data = self.tmdb.get_movie_credits(tmdb_id, language=language)

        try:
            self.repo.upsert_movie(movie_data)
            self.repo.replace_genres(tmdb_id, movie_data.get("genres", []))
            self.repo.replace_credits(tmdb_id, credits_data)
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise

        movie = self.repo.get_full(tmdb_id)
        assert movie is not None, "movie should exist right after sync"
        return movie
