from datetime import datetime

from pydantic import BaseModel, Field

from app.schemas.movie import MovieCard


class UserStateOut(BaseModel):
    is_favorite: bool
    in_watchlist: bool
    is_watched: bool
    user_rating: float | None = Field(
        default=None, description="0.0 to 5.0 in 0.5 steps, or null if not rated"
    )
    user_review: str | None = None


class RatingIn(BaseModel):
    stars: float = Field(ge=0, le=5, multiple_of=0.5)
    review: str | None = Field(default=None, max_length=5000)


class RatingWithMovieOut(BaseModel):
    """A user's rating with the rated movie embedded (built by the presenter)."""

    movie: MovieCard
    stars: float
    review: str | None = None
    created_at: datetime
    updated_at: datetime
