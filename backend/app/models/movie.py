from datetime import date, datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import Date, DateTime, Integer, Numeric, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.genre import Genre
    from app.models.movie_cast import MovieCast
    from app.models.movie_crew import MovieCrew


class Movie(Base):
    # Movie cached from TMDB - Populated lazily on first request to /movies/{tmdb_id}
    # refreshed when `last_synced_at` is older than the configured TTL.

    __tablename__ = "movies"

    tmdb_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=False)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    original_title: Mapped[str | None] = mapped_column(String(500), nullable=True)
    overview: Mapped[str | None] = mapped_column(Text, nullable=True)
    release_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    runtime: Mapped[int | None] = mapped_column(Integer, nullable=True)
    poster_path: Mapped[str | None] = mapped_column(String(255), nullable=True)
    backdrop_path: Mapped[str | None] = mapped_column(String(255), nullable=True)
    original_language: Mapped[str | None] = mapped_column(String(10), nullable=True)
    vote_average: Mapped[Decimal | None] = mapped_column(Numeric(3, 1), nullable=True)
    last_synced_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    genres: Mapped[list["Genre"]] = relationship(
        secondary="movie_genres",
        order_by="Genre.name",
        lazy="select",
    )
    cast: Mapped[list["MovieCast"]] = relationship(
        order_by="MovieCast.cast_order",
        lazy="select",
    )
    crew: Mapped[list["MovieCrew"]] = relationship(lazy="select")
