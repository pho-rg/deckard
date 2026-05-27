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


def _image_url(path: str | None, size: str) -> str | None:
    if not path:
        return None
    return f"{settings.tmdb_image_base_url}/{size}{path}"


class GenreOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    tmdb_id: int
    name: str


class PersonOut(BaseModel):
    """A cast/crew member as exposed by the API.

    The raw ``profile_path`` is hidden; a fully composed ``profile_url`` is
    returned so the front never needs to know the TMDB CDN.
    """

    model_config = ConfigDict(from_attributes=True)

    tmdb_id: int
    name: str
    profile_path: str | None = Field(default=None, exclude=True)

    @computed_field  
    @property
    def profile_url(self) -> str | None:
        return _image_url(self.profile_path, "w185")


class CastOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    person: PersonOut
    character: str | None = None
    # ORM column is ``cast_order`` (avoids the SQL reserved word); expose as ``order``.
    order: int = Field(validation_alias=AliasChoices("order", "cast_order"))


class CrewOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    person: PersonOut
    job: str
    department: str | None = None


class MovieOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    tmdb_id: int
    title: str
    original_title: str | None = None
    overview: str | None = None
    release_date: date | None = None
    runtime: int | None = None
    original_language: str | None = None
    vote_average: Decimal | None = None

    poster_path: str | None = Field(default=None, exclude=True)
    backdrop_path: str | None = Field(default=None, exclude=True)

    genres: list[GenreOut] = []
    cast: list[CastOut] = []
    crew: list[CrewOut] = []

    @computed_field  
    @property
    def poster_url(self) -> str | None:
        return _image_url(self.poster_path, "w500")

    @computed_field  
    @property
    def backdrop_url(self) -> str | None:
        return _image_url(self.backdrop_path, "w1280")


class MovieSummary(BaseModel):
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
        # TMDB returns "" instead of null for unknown release dates.
        return v or None

    @computed_field  
    @property
    def poster_url(self) -> str | None:
        return _image_url(self.poster_path, "w500")

    @computed_field  
    @property
    def backdrop_url(self) -> str | None:
        return _image_url(self.backdrop_path, "w1280")


class PagedMovies(BaseModel):

    page: int
    total_pages: int
    total_results: int
    results: list[MovieSummary]
