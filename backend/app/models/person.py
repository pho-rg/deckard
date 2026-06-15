from datetime import date
from typing import TYPE_CHECKING

from sqlalchemy import Date, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.person_content import PersonContent


class Person(Base):
    # Language-agnostic person data. Localized text (name, bio) in person_content.
    __tablename__ = "persons"

    tmdb_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=False)
    imdb_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    birthday: Mapped[date | None] = mapped_column(Date, nullable=True)
    deathday: Mapped[date | None] = mapped_column(Date, nullable=True)
    gender: Mapped[int | None] = mapped_column(Integer, nullable=True)
    known_for_department: Mapped[str | None] = mapped_column(Text, nullable=True)
    profile_path: Mapped[str | None] = mapped_column(String(255), nullable=True)

    contents: Mapped[list["PersonContent"]] = relationship(
        lazy="select", cascade="all, delete-orphan"
    )
