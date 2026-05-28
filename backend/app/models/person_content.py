from sqlalchemy import ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class PersonContent(Base):
    # Localized person text (name + bio), one row per (person, language).
    __tablename__ = "person_content"

    tmdb_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("persons.tmdb_id", ondelete="CASCADE"),
        primary_key=True,
    )
    language_iso: Mapped[str] = mapped_column(String(2), primary_key=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    biography: Mapped[str | None] = mapped_column(Text, nullable=True)
    place_of_birth: Mapped[str | None] = mapped_column(Text, nullable=True)
