"""Shared repository shape for the three (user_id, movie_id) flag tables.

``favorites``, ``watchlist`` and ``watched`` all share the same access pattern:
toggle membership, check membership, list the user's movies. The only thing
that varies is which table and which timestamp column drives the ordering.
"""

from __future__ import annotations

import uuid
from typing import ClassVar

from sqlalchemy import delete, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.orm import Session

from app.models.base import Base
from app.models.favorite import Favorite
from app.models.movie import Movie
from app.models.watched import WatchedItem
from app.models.watchlist import WatchlistItem


class _UserMovieFlagRepository:
    """Base. Subclasses bind ``model`` and ``timestamp_col_name``.

    Note: we hold the timestamp column as a *string* rather than the
    InstrumentedAttribute. Storing the attribute directly at class level
    triggers SQLAlchemy's descriptor protocol on ``self.timestamp_col``,
    which then complains that the repository isn't a mapped instance.
    """

    model: ClassVar[type[Base]]
    timestamp_col_name: ClassVar[str]

    def __init__(self, db: Session):
        self.db = db

    def exists(self, user_id: uuid.UUID, movie_id: int) -> bool:
        return self.db.scalar(
            select(self.model.user_id)
            .where(self.model.user_id == user_id, self.model.movie_id == movie_id)
            .limit(1)
        ) is not None

    def add(self, user_id: uuid.UUID, movie_id: int) -> None:
        """Idempotent — duplicate add is a no-op."""
        stmt = pg_insert(self.model).values(user_id=user_id, movie_id=movie_id)
        stmt = stmt.on_conflict_do_nothing()
        self.db.execute(stmt)
        self.db.commit()

    def remove(self, user_id: uuid.UUID, movie_id: int) -> bool:
        """Returns True if a row was actually deleted, False if nothing to remove."""
        result = self.db.execute(
            delete(self.model).where(
                self.model.user_id == user_id, self.model.movie_id == movie_id
            )
        )
        self.db.commit()
        return result.rowcount > 0

    def list_movies(self, user_id: uuid.UUID) -> list[Movie]:
        """Return the user's movies, newest first."""
        ts_col = getattr(self.model, self.timestamp_col_name)
        return list(
            self.db.scalars(
                select(Movie)
                .join(self.model, self.model.movie_id == Movie.tmdb_id)
                .where(self.model.user_id == user_id)
                .order_by(ts_col.desc())
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
