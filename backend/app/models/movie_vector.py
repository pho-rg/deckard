from sqlalchemy import ARRAY, REAL, ForeignKey, Integer
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class MovieVector(Base):
    # Embedding for the AI/content-based recommendation model.
    # Populated by an external ML pipeline, not by the TMDB sync.
    __tablename__ = "movie_vector"

    tmdb_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("movies.tmdb_id", ondelete="CASCADE"),
        primary_key=True,
    )
    vector: Mapped[list[float]] = mapped_column(ARRAY(REAL), nullable=False)
