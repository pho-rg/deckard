# Service for user-centric movie actions: favorites, watchlist, watched, rating.

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.integrations.tmdb import TMDBClient
from app.models.movie import Movie
from app.models.rating import Rating
from app.models.user import User
from app.repositories.rating_repository import RatingRepository
from app.repositories.user_movie_flag import (
    FavoriteRepository,
    WatchedRepository,
    WatchlistRepository,
)
from app.services.movie_service import MovieService


class UserMovieService:
    def __init__(self, db: Session, tmdb: TMDBClient | None = None):
        self.db = db
        self.movies = MovieService(db, tmdb)
        self.favorites = FavoriteRepository(db)
        self.watchlist = WatchlistRepository(db)
        self.watched = WatchedRepository(db)
        self.ratings = RatingRepository(db)

    # ------------ membership actions ------------

    def add_favorite(self, user: User, tmdb_id: int) -> None:
        self._ensure_movie_cached(tmdb_id, user)
        self.favorites.add(user.id, tmdb_id)

    def remove_favorite(self, user: User, tmdb_id: int) -> None:
        self.favorites.remove(user.id, tmdb_id)

    def add_to_watchlist(self, user: User, tmdb_id: int) -> None:
        self._ensure_movie_cached(tmdb_id, user)
        self.watchlist.add(user.id, tmdb_id)

    def remove_from_watchlist(self, user: User, tmdb_id: int) -> None:
        self.watchlist.remove(user.id, tmdb_id)

    def mark_watched(self, user: User, tmdb_id: int) -> None:
        self._ensure_movie_cached(tmdb_id, user)
        self.watched.add(user.id, tmdb_id)

    def unmark_watched(self, user: User, tmdb_id: int) -> None:
        self.watched.remove(user.id, tmdb_id)

    # ------------ rating ------------

    def set_rating(self, user: User, tmdb_id: int, stars: float) -> None:
        self._ensure_movie_cached(tmdb_id, user)
        # Pydantic already enforced `multiple_of=0.5` & range 0..5; round defensively.
        half_stars = round(stars * 2)
        self.ratings.upsert(user.id, tmdb_id, half_stars)

    def remove_rating(self, user: User, tmdb_id: int) -> None:
        self.ratings.remove(user.id, tmdb_id)

    # ------------ read-side ------------

    def get_user_state(self, user: User, tmdb_id: int) -> dict:
        rating_row = self.ratings.get(user.id, tmdb_id)
        return {
            "is_favorite": self.favorites.exists(user.id, tmdb_id),
            "in_watchlist": self.watchlist.exists(user.id, tmdb_id),
            "is_watched": self.watched.exists(user.id, tmdb_id),
            "user_rating": (rating_row.rating / 2) if rating_row else None,
        }

    def list_favorites(self, user: User) -> list[Movie]:
        return self.favorites.list_movies(user.id)

    def list_watchlist(self, user: User) -> list[Movie]:
        return self.watchlist.list_movies(user.id)

    def list_watched(self, user: User) -> list[Movie]:
        return self.watched.list_movies(user.id)

    def list_ratings(self, user: User) -> list[Rating]:
        return self.ratings.list_for_user(user.id)

    # ------------ internals ------------

    def _ensure_movie_cached(self, tmdb_id: int, user: User) -> None:
        already_cached = self.db.scalar(
            select(Movie.tmdb_id).where(Movie.tmdb_id == tmdb_id).limit(1)
        )
        if already_cached is None:
            self.movies.get_movie_details(tmdb_id, language=user.language)
