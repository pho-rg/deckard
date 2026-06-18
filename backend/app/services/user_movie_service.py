# Service for user-centric movie actions: favorites, watchlist, watched, rating.

from __future__ import annotations

import uuid

from sqlalchemy.orm import Session

from app.integrations.tmdb import TMDBClient
from app.models.user import User
from app.repositories.friendship_repository import FriendshipRepository
from app.repositories.rating_repository import RatingRepository
from app.repositories.user_movie_flag import (
    FavoriteRepository,
    WatchedRepository,
    WatchlistRepository,
)
from app.schemas.movie import MovieCard
from app.schemas.user_movie import RatingWithMovieOut
from app.services import presenter
from app.services.localization import to_iso2
from app.services.movie_service import MovieNotFound, MovieService


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
        self._ensure_movie_exists(tmdb_id)
        self.favorites.add(user.id, tmdb_id)

    def remove_favorite(self, user: User, tmdb_id: int) -> None:
        self.favorites.remove(user.id, tmdb_id)

    def add_favorites_batch(self, user: User, tmdb_ids: list[int]) -> int:
        # Onboarding: add the picked movies as favorites. Unknown ids are
        # skipped silently so a stale pick never blocks the flow.
        valid = self.movies.repo.existing_ids(tmdb_ids)
        added = 0
        for tmdb_id in tmdb_ids:
            if tmdb_id in valid:
                self.favorites.add(user.id, tmdb_id)
                added += 1
        return added

    # ------------ onboarding ------------

    def needs_onboarding(self, user: User) -> bool:
        return not self.favorites.has_any(user.id)

    def add_to_watchlist(self, user: User, tmdb_id: int) -> None:
        self._ensure_movie_exists(tmdb_id)
        self.watchlist.add(user.id, tmdb_id)

    def remove_from_watchlist(self, user: User, tmdb_id: int) -> None:
        self.watchlist.remove(user.id, tmdb_id)

    def mark_watched(self, user: User, tmdb_id: int) -> None:
        self._ensure_movie_exists(tmdb_id)
        self.watched.add(user.id, tmdb_id)

    def unmark_watched(self, user: User, tmdb_id: int) -> None:
        self.watched.remove(user.id, tmdb_id)

    # ------------ rating ------------

    def set_rating(
        self, user: User, tmdb_id: int, stars: float, review: str | None = None
    ) -> None:
        self._ensure_movie_exists(tmdb_id)
        half_stars = round(stars * 2)
        self.ratings.upsert(user.id, tmdb_id, half_stars, review)
        self._recompute_vote_average(tmdb_id)

    def remove_rating(self, user: User, tmdb_id: int) -> None:
        self.ratings.remove(user.id, tmdb_id)
        self._recompute_vote_average(tmdb_id)

    def _recompute_vote_average(self, tmdb_id: int) -> None:
        # movies.vote_average holds the Deckard community average; recompute it
        # from the ratings table. None again when the last rating is removed.
        avg = self.ratings.community_average(tmdb_id)
        self.movies.repo.set_vote_average(tmdb_id, avg)

    # ------------ read-side ------------

    def get_user_state(self, user: User, tmdb_id: int) -> dict:
        rating_row = self.ratings.get(user.id, tmdb_id)
        return {
            "is_favorite": self.favorites.exists(user.id, tmdb_id),
            "in_watchlist": self.watchlist.exists(user.id, tmdb_id),
            "is_watched": self.watched.exists(user.id, tmdb_id),
            "user_rating": (rating_row.rating / 2) if rating_row else None,
            "user_review": rating_row.review if rating_row else None,
        }

    def list_favorites(self, user: User) -> list[MovieCard]:
        return self.list_favorites_for(user.id, user.language)

    def list_watchlist(self, user: User) -> list[MovieCard]:
        return self.list_watchlist_for(user.id, user.language)

    def list_watched(self, user: User) -> list[MovieCard]:
        return self.list_watched_for(user.id, user.language)

    def list_ratings(self, user: User) -> list[RatingWithMovieOut]:
        return self.list_ratings_for(user.id, user.language)

    def popular_among_friends(
        self, user: User, *, limit: int = 12
    ) -> list[MovieCard]:
        # Recently watched movies across the user's friends (deduped).
        friends = FriendshipRepository(self.db).list_friends(user.id)
        friend_ids = [f.id for f in friends]
        iso = to_iso2(user.language)
        movies = self.watched.list_recent_for_users(friend_ids, limit=limit)
        return [presenter.movie_card(m, iso) for m in movies]

    # by user_id + viewer language — used to expose friends' collections
    def list_favorites_for(self, user_id: uuid.UUID, language: str) -> list[MovieCard]:
        iso = to_iso2(language)
        return [presenter.movie_card(m, iso) for m in self.favorites.list_movies(user_id)]

    def list_watchlist_for(self, user_id: uuid.UUID, language: str) -> list[MovieCard]:
        iso = to_iso2(language)
        return [presenter.movie_card(m, iso) for m in self.watchlist.list_movies(user_id)]

    def list_watched_for(self, user_id: uuid.UUID, language: str) -> list[MovieCard]:
        iso = to_iso2(language)
        return [presenter.movie_card(m, iso) for m in self.watched.list_movies(user_id)]

    def list_ratings_for(
        self, user_id: uuid.UUID, language: str
    ) -> list[RatingWithMovieOut]:
        iso = to_iso2(language)
        return [
            presenter.rating_with_movie(r, iso)
            for r in self.ratings.list_for_user(user_id)
        ]

    # ------------ internals ------------

    def _ensure_movie_exists(self, tmdb_id: int) -> None:
        if not self.movies.repo.exists(tmdb_id):
            raise MovieNotFound(tmdb_id)
