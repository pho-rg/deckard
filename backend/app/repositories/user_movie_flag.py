from __future__ import annotations

import uuid
from typing import ClassVar

from sqlalchemy import delete, func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.orm import Session, selectinload

from app.models.base import Base
from app.models.favorite import Favorite
from app.models.genre import Genre
from app.models.movie import Movie
from app.models.watched import WatchedItem
from app.models.watchlist import WatchlistItem

# Eager-load everything `presenter.movie_card` needs to localize a card.
_CARD_OPTIONS = (
    selectinload(Movie.contents),
    selectinload(Movie.genres).selectinload(Genre.contents),
)


# Common repository pattern for favorites, watchlist and watched
class _UserMovieFlagRepository:

    # targeted model (favorite, watchlist, watched)
    model: ClassVar[type[Base]]
    # timestamp column name (ordering purpose)
    timestamp_col_name: ClassVar[str]

    def __init__(self, db: Session):
        self.db = db

    def exists(self, user_id: uuid.UUID, movie_id: int) -> bool:
        return self.db.scalar(
            select(self.model.user_id)
            .where(self.model.user_id == user_id, self.model.movie_id == movie_id)
            .limit(1)
        ) is not None

    def has_any(self, user_id: uuid.UUID) -> bool:
        # True if the user has at least one entry (used for onboarding detection)
        return self.db.scalar(
            select(self.model.movie_id).where(self.model.user_id == user_id).limit(1)
        ) is not None

    def add(self, user_id: uuid.UUID, movie_id: int) -> None:
        stmt = pg_insert(self.model).values(user_id=user_id, movie_id=movie_id)
        stmt = stmt.on_conflict_do_nothing()
        self.db.execute(stmt)
        self.db.commit()

    def remove(self, user_id: uuid.UUID, movie_id: int) -> bool:
        # Returns True if a row was actually deleted, False if nothing to remove
        result = self.db.execute(
            delete(self.model).where(
                self.model.user_id == user_id, self.model.movie_id == movie_id
            )
        )
        self.db.commit()
        return result.rowcount > 0

    def list_movies(self, user_id: uuid.UUID) -> list[Movie]:
        # Return the user's movies, newest first
        ts_col = getattr(self.model, self.timestamp_col_name)
        return list(
            self.db.scalars(
                select(Movie)
                .join(self.model, self.model.movie_id == Movie.tmdb_id)
                .where(self.model.user_id == user_id)
                .order_by(ts_col.desc())
                .options(*_CARD_OPTIONS)
            )
        )


class FavoriteRepository(_UserMovieFlagRepository):
    model = Favorite
    timestamp_col_name = "created_at"


class WatchlistRepository(_UserMovieFlagRepository):
    model = WatchlistItem
    timestamp_col_name = "created_at"


class WatchedRepository(_UserMovieFlagRepository):
    model = WatchedItem
    timestamp_col_name = "watched_at"

    def list_recent_for_users(
        self, user_ids: list[uuid.UUID], *, limit: int = 12
    ) -> list[Movie]:
        # Distinct movies watched by any of the given users, most recently
        # watched first. Aggregates across several friends (max watched_at).
        if not user_ids:
            return []
        latest = func.max(WatchedItem.watched_at)
        rows = self.db.execute(
            select(Movie)
            .join(WatchedItem, WatchedItem.movie_id == Movie.tmdb_id)
            .where(WatchedItem.user_id.in_(user_ids))
            .group_by(Movie.tmdb_id)
            .order_by(latest.desc())
            .limit(limit)
            .options(*_CARD_OPTIONS)
        ).all()
        return [r[0] for r in rows]
