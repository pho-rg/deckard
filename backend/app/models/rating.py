import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Rating(Base):
    """User rating for a movie.

    Stored as an integer half-star count: 0..10 maps to 0..5 stars in 0.5 steps.
        0  → 0     stars     6  → 3     stars
        1  → 0.5   stars     7  → 3.5   stars
        2  → 1     star      8  → 4     stars
        3  → 1.5   stars     9  → 4.5   stars
        4  → 2     stars    10  → 5     stars
        5  → 2.5   stars
    """

    __tablename__ = "ratings"
    __table_args__ = (
        CheckConstraint("rating >= 0 AND rating <= 10", name="ck_ratings_range"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    movie_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("movies.tmdb_id", ondelete="CASCADE"),
        primary_key=True,
    )
    rating: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
