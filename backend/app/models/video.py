from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Video(Base):
    # Trailer / clip YouTube key, one row per (movie, language).
    __tablename__ = "video"

    tmdb_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("movies.tmdb_id", ondelete="CASCADE"),
        primary_key=True,
    )
    language_iso: Mapped[str] = mapped_column(String(2), primary_key=True)
    youtube_key: Mapped[str] = mapped_column(String(500), nullable=False)
