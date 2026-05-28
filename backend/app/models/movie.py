import enum
from datetime import date, datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import Date, DateTime, Enum, Integer, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.genre import Genre
    from app.models.movie_cast import MovieCast
    from app.models.movie_content import MovieContent
    from app.models.movie_crew import MovieCrew
    from app.models.movie_vector import MovieVector
    from app.models.video import Video


class MovieStatus(str, enum.Enum):
    released = "released"
    not_released = "not_released"


class Movie(Base):
    # Language-agnostic movie data. Localized text lives in movie_content.
    __tablename__ = "movies"

    tmdb_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=False)
    imdb_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    original_title: Mapped[str | None] = mapped_column(String(500), nullable=True)
    release_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    runtime: Mapped[int | None] = mapped_column(Integer, nullable=True)
    poster_path: Mapped[str | None] = mapped_column(String(255), nullable=True)
    backdrop_path: Mapped[str | None] = mapped_column(String(255), nullable=True)
    original_language: Mapped[str | None] = mapped_column(String(10), nullable=True)
    vote_average: Mapped[Decimal | None] = mapped_column(Numeric(3, 1), nullable=True)
    status: Mapped[MovieStatus | None] = mapped_column(
        Enum(MovieStatus, name="movie_status"), nullable=True
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    contents: Mapped[list["MovieContent"]] = relationship(
        lazy="select", cascade="all, delete-orphan"
    )
    videos: Mapped[list["Video"]] = relationship(
        lazy="select", cascade="all, delete-orphan"
    )
    genres: Mapped[list["Genre"]] = relationship(
        secondary="movie_genres", lazy="select"
    )
    cast: Mapped[list["MovieCast"]] = relationship(
        order_by="MovieCast.cast_order", lazy="select"
    )
    crew: Mapped[list["MovieCrew"]] = relationship(lazy="select")
    vector: Mapped["MovieVector | None"] = relationship(
        lazy="select", cascade="all, delete-orphan", uselist=False
    )
