from datetime import datetime

from pydantic import AliasChoices, BaseModel, ConfigDict, Field, field_validator

from app.schemas.movie import MovieSummary


class UserStateOut(BaseModel):
    is_favorite: bool
    in_watchlist: bool
    is_watched: bool
    user_rating: float | None = Field(
        default=None,
        description="0.0 to 5.0 in 0.5 steps, or null if not rated",
    )


class RatingIn(BaseModel):
    stars: float = Field(ge=0, le=5, multiple_of=0.5)


class RatingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    movie_id: int
    stars: float = Field(validation_alias=AliasChoices("stars", "rating"))
    created_at: datetime
    updated_at: datetime

    @field_validator("stars", mode="before")
    @classmethod
    def _half_stars_to_float(cls, v):
        # Storage is an int 0..10 (half-stars); expose float 0.0..5.0.
        if isinstance(v, int):
            return v / 2
        return float(v)


class RatingWithMovieOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    movie: MovieSummary
    stars: float = Field(validation_alias=AliasChoices("stars", "rating"))
    created_at: datetime
    updated_at: datetime

    @field_validator("stars", mode="before")
    @classmethod
    def _half_stars_to_float(cls, v):
        if isinstance(v, int):
            return v / 2
        return float(v)
