import enum
import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    String,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.movie import Movie
    from app.models.user import User


class MatchStatus(str, enum.Enum):
    not_started = "not_started"  # waiting room — people still joining
    in_progress = "in_progress"  # movies generated, everyone is voting
    finished = "finished"  # all choices received, result available


class MatchSession(Base):
    __tablename__ = "match_sessions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    code: Mapped[str] = mapped_column(
        String(8), unique=True, index=True, nullable=False
    )
    host_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    status: Mapped[MatchStatus] = mapped_column(
        Enum(MatchStatus, name="match_status"),
        nullable=False,
        default=MatchStatus.not_started,
    )
    # Number of participants who have submitted their choices in the current run.
    choices_received: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default="0"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    host: Mapped["User"] = relationship(foreign_keys=[host_id], lazy="joined")
    participants: Mapped[list["MatchParticipant"]] = relationship(
        back_populates="session",
        cascade="all, delete-orphan",
    )
    movies: Mapped[list["MatchMovie"]] = relationship(
        back_populates="session",
        cascade="all, delete-orphan",
    )


class MatchParticipant(Base):
    __tablename__ = "match_participants"

    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("match_sessions.id", ondelete="CASCADE"),
        primary_key=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    # True once this participant submitted their choices for the current run.
    has_submitted: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="false"
    )

    session: Mapped["MatchSession"] = relationship(back_populates="participants")
    user: Mapped["User"] = relationship(lazy="joined")


class MatchMovie(Base):
    # A movie proposed for voting in a session. `eliminated` flips to True as
    # soon as a participant votes "no" → the final unanimous list is the set of
    # non-eliminated movies once everyone has submitted.
    __tablename__ = "match_movies"

    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("match_sessions.id", ondelete="CASCADE"),
        primary_key=True,
    )
    movie_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("movies.tmdb_id", ondelete="CASCADE"),
        primary_key=True,
    )
    position: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default="0"
    )
    eliminated: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="false"
    )

    session: Mapped["MatchSession"] = relationship(back_populates="movies")
    movie: Mapped["Movie"] = relationship(lazy="joined")
