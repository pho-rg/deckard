from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Genre(Base):
    """TMDB genre — stable, ~19 values. Synced once from /genre/movie/list."""

    __tablename__ = "genres"

    tmdb_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=False)
    name: Mapped[str] = mapped_column(String(64), nullable=False)
