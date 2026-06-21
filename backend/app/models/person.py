from sqlalchemy import Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Person(Base):
    # Person data. Name is stored directly here (language-agnostic in our catalogue).
    __tablename__ = "persons"

    tmdb_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=False)
    imdb_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    gender: Mapped[int | None] = mapped_column(Integer, nullable=True)
    known_for_department: Mapped[str | None] = mapped_column(Text, nullable=True)
    profile_path: Mapped[str | None] = mapped_column(String(255), nullable=True)
