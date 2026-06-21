import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.models.match import MatchStatus
from app.schemas.friend import UserPublicOut
from app.schemas.movie import MovieCard


class MatchJoinIn(BaseModel):
    code: str = Field(min_length=4, max_length=8)


class MatchChoicesIn(BaseModel):
    """The tmdb_ids the participant voted "no" on (to eliminate)."""

    rejected_ids: list[int] = Field(default_factory=list, max_length=100)


class MatchSessionOut(BaseModel):
    id: uuid.UUID
    code: str
    status: MatchStatus
    created_at: datetime
    host: UserPublicOut
    participants: list[UserPublicOut]
    participant_count: int
    choices_received: int
    # Voting list (present once started). Each participant votes on the full list.
    movies: list[MovieCard] = []
    # Unanimous movies (no "no") — only meaningful once status == finished.
    result: list[MovieCard] = []
