from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class GenreContent(Base):
    # Localized genre name, one row per (genre, language).
    __tablename__ = "genre_content"

    tmdb_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("genres.tmdb_id", ondelete="CASCADE"),
        primary_key=True,
    )
    language_iso: Mapped[str] = mapped_column(String(2), primary_key=True)
    name: Mapped[str] = mapped_column(String(64), nullable=False)
