from sqlalchemy import ForeignKey, Integer
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class MovieGenre(Base):
    """Join table — many-to-many between movies and genres."""

    __tablename__ = "movie_genres"

    movie_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("movies.tmdb_id", ondelete="CASCADE"),
        primary_key=True,
    )
    genre_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("genres.tmdb_id", ondelete="CASCADE"),
        primary_key=True,
    )
