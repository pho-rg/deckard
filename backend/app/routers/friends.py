import uuid

from fastapi import APIRouter, status

from app.deps import CurrentUser, DbSession
from app.schemas.friend import (
    FriendRequestCreate,
    FriendRequestOut,
    FriendRequestsListing,
    UserPublicOut,
)
from app.schemas.movie import MovieCard
from app.services.friendship_service import FriendshipService
from app.services.user_movie_service import UserMovieService

router = APIRouter(prefix="/friends", tags=["friends"])


@router.get("", response_model=list[UserPublicOut])
def list_friends(db: DbSession, current_user: CurrentUser):
    return FriendshipService(db).list_friends(current_user)


@router.get("/popular", response_model=list[MovieCard])
def popular_with_friends(db: DbSession, current_user: CurrentUser):
    # Movies recently watched across the user's friends.
    return UserMovieService(db).popular_among_friends(current_user)


@router.post(
    "/requests",
    response_model=FriendRequestOut,
    status_code=status.HTTP_201_CREATED,
)
def send_friend_request(
    payload: FriendRequestCreate, db: DbSession, current_user: CurrentUser
):
    return FriendshipService(db).send_request(current_user, payload.username)


@router.get("/requests", response_model=FriendRequestsListing)
def list_friend_requests(db: DbSession, current_user: CurrentUser):
    return FriendshipService(db).list_pending(current_user)


@router.post(
    "/requests/{requester_id}/accept",
    response_model=FriendRequestOut,
)
def accept_friend_request(
    requester_id: uuid.UUID, db: DbSession, current_user: CurrentUser
):
    return FriendshipService(db).accept_request(current_user, requester_id)


@router.post(
    "/requests/{requester_id}/reject",
    response_model=FriendRequestOut,
)
def reject_friend_request(
    requester_id: uuid.UUID, db: DbSession, current_user: CurrentUser
):
    return FriendshipService(db).reject_request(current_user, requester_id)


@router.delete("/{addressee_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_friendship(
    addressee_id: uuid.UUID, db: DbSession, current_user: CurrentUser
):
    # Deletes the row where the current user is the requester (any status).
    # Works for both "cancel my outgoing request" and "unfriend".
    FriendshipService(db).remove_outgoing(current_user, addressee_id)
