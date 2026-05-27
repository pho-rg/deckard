import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class UserPublicOut(BaseModel):
    # Public projection — what others can see about a user
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    username: str


class FriendRequestCreate(BaseModel):
    username: str = Field(min_length=3, max_length=64)


class FriendRequestOut(BaseModel):
    # A pending request, either incoming or outgoing
    model_config = ConfigDict(from_attributes=True)

    requester: UserPublicOut
    addressee: UserPublicOut
    created_at: datetime


class FriendRequestsListing(BaseModel):
    incoming: list[FriendRequestOut]
    outgoing: list[FriendRequestOut]
