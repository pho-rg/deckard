import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: EmailStr
    username: str
    language: str
    region: str
    created_at: datetime


class UserUpdate(BaseModel):

    language: str | None = Field(
        default=None,
        description="BCP-47-ish language tag, e.g. fr-FR, en-US",
        pattern=r"^[a-z]{2}-[A-Z]{2}$",
    )
    region: str | None = Field(
        default=None,
        description="ISO 3166-1 alpha-2 country code, e.g. FR, US",
        pattern=r"^[A-Z]{2}$",
    )
