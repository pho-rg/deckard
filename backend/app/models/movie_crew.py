from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.person import Person


class MovieCrew(Base):
    """Crew member for a movie.

    A single person can hold multiple jobs on the same movie (director +
    writer), hence the composite PK includes ``job``.
    """

    __tablename__ = "movie_crew"

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
    job: Mapped[str] = mapped_column(String(100), primary_key=True)
    department: Mapped[str | None] = mapped_column(String(100), nullable=True)

    person: Mapped["Person"] = relationship(lazy="joined")
