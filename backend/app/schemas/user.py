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
    needs_onboarding: bool = Field(
        default=False,
        description="True when the user has no favorites yet → show onboarding",
    )


class PasswordChange(BaseModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


class UserProfileOut(BaseModel):
    """Public profile projection for a friend (no email)."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    username: str
    created_at: datetime


class UserUpdate(BaseModel):

    username: str | None = Field(
        default=None,
        min_length=3,
        max_length=64,
        description="Display name; must be unique",
    )
    email: EmailStr | None = Field(
        default=None,
        description="Account email; must be unique",
    )
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
