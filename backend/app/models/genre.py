from typing import TYPE_CHECKING

from sqlalchemy import Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.genre_content import GenreContent


class Genre(Base):
    # Genre concept (TMDB id). Localized names live in genre_content.
    __tablename__ = "genres"

    tmdb_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=False)

    contents: Mapped[list["GenreContent"]] = relationship(
        lazy="select", cascade="all, delete-orphan"
    )
