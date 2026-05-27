from __future__ import annotations

from datetime import date
from decimal import Decimal

from pydantic import AliasChoices, BaseModel, ConfigDict, Field, computed_field

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

    @computed_field  # type: ignore[prop-decorator]
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

    @computed_field  # type: ignore[prop-decorator]
    @property
    def poster_url(self) -> str | None:
        return _image_url(self.poster_path, "w500")

    @computed_field  # type: ignore[prop-decorator]
    @property
    def backdrop_url(self) -> str | None:
        return _image_url(self.backdrop_path, "w1280")
