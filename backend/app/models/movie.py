from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Movie(Base):
    """Stub movies table — will be expanded when TMDB integration lands.

    Other user-related tables reference this via foreign key.
    """

    __tablename__ = "movies"

    tmdb_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
