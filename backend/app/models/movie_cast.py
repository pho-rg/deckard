from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class MovieCast(Base):
    """On-screen cast for a movie."""

    __tablename__ = "movie_cast"

    movie_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("movies.tmdb_id", ondelete="CASCADE"),
        primary_key=True,
    )
    person_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("persons.tmdb_id", ondelete="CASCADE"),
        primary_key=True,
    )
    character: Mapped[str | None] = mapped_column(String(255), nullable=True)
    # cast_order avoids the SQL reserved word "order".
    cast_order: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default="0"
    )
