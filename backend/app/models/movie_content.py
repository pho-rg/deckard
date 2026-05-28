from sqlalchemy import ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class MovieContent(Base):
    # Localized movie text, one row per (movie, language).
    __tablename__ = "movie_content"

    tmdb_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("movies.tmdb_id", ondelete="CASCADE"),
        primary_key=True,
    )
    language_iso: Mapped[str] = mapped_column(String(2), primary_key=True)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    overview: Mapped[str | None] = mapped_column(Text, nullable=True)
    tag_line: Mapped[str | None] = mapped_column(Text, nullable=True)
