from __future__ import annotations

from datetime import date
from decimal import Decimal

from pydantic import (
    AliasChoices,
    BaseModel,
    ConfigDict,
    Field,
    computed_field,
    field_validator,
)

from app.config import settings

_YOUTUBE_WATCH = "https://www.youtube.com/watch?v="


def _image_url(path: str | None, size: str) -> str | None:
    if not path:
        return None
    return f"{settings.tmdb_image_base_url}/{size}{path}"


# ---------- localized building blocks (built by the presenter, not from_attributes) ----------


class GenreOut(BaseModel):
    tmdb_id: int
    name: str


class PersonOut(BaseModel):
    tmdb_id: int
    name: str
    profile_url: str | None = None


class CastOut(BaseModel):
    person: PersonOut
    character: str | None = None
    order: int


class CrewOut(BaseModel):
    person: PersonOut
    job: str
    department: str | None = None


class MovieDetailOut(BaseModel):
    """Full movie detail, localized for the requesting user."""

    tmdb_id: int
    imdb_id: str | None = None
    title: str
    original_title: str | None = None
    overview: str | None = None
    tag_line: str | None = None
    release_date: date | None = None
    runtime: int | None = None
    original_language: str | None = None
    vote_average: Decimal | None = None
    status: str | None = None
    poster_url: str | None = None
    backdrop_url: str | None = None
    trailer_youtube_key: str | None = None
    genres: list[GenreOut] = []
    cast: list[CastOut] = []
    crew: list[CrewOut] = []

    @computed_field  # type: ignore[prop-decorator]
    @property
    def trailer_url(self) -> str | None:
        if not self.trailer_youtube_key:
            return None
        return f"{_YOUTUBE_WATCH}{self.trailer_youtube_key}"


class MovieCard(BaseModel):
    """Compact movie shape for DB-sourced lists (favorites, recos, featured…)."""

    tmdb_id: int
    title: str
    original_title: str | None = None
    overview: str | None = None
    release_date: date | None = None
    vote_average: Decimal | None = None
    poster_url: str | None = None
    backdrop_url: str | None = None


# ---------- TMDB passthrough (search / trending / now-playing) ----------


class MovieSummary(BaseModel):
    """Maps directly from a TMDB list ``results[]`` entry (no DB involved)."""

    model_config = ConfigDict(populate_by_name=True)

    tmdb_id: int = Field(validation_alias=AliasChoices("tmdb_id", "id"))
    title: str
    original_title: str | None = None
    overview: str | None = None
    release_date: date | None = None
    vote_average: Decimal | None = None
    genre_ids: list[int] = []

    poster_path: str | None = Field(default=None, exclude=True)
    backdrop_path: str | None = Field(default=None, exclude=True)

    @field_validator("release_date", mode="before")
    @classmethod
    def _empty_date_to_none(cls, v):
        return v or None

    @computed_field  # type: ignore[prop-decorator]
    @property
    def poster_url(self) -> str | None:
        return _image_url(self.poster_path, "w500")

    @computed_field  # type: ignore[prop-decorator]
    @property
    def backdrop_url(self) -> str | None:
        return _image_url(self.backdrop_path, "w1280")


class PagedMovies(BaseModel):
    page: int
    total_pages: int
    total_results: int
    results: list[MovieSummary]
