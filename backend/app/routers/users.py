import uuid

from fastapi import APIRouter, Query

from app.deps import CurrentUser, DbSession
from app.repositories.user_repository import UserRepository
from app.schemas.friend import UserPublicOut
from app.schemas.movie import MovieSummary
from app.schemas.user import UserOut, UserUpdate
from app.schemas.user_movie import RatingWithMovieOut
from app.services.friendship_service import FriendshipService
from app.services.user_movie_service import UserMovieService

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserOut)
def get_me(current_user: CurrentUser):
    return current_user


@router.put("/me", response_model=UserOut)
def update_me(payload: UserUpdate, db: DbSession, current_user: CurrentUser):
    if payload.language is not None:
        current_user.language = payload.language
    if payload.region is not None:
        current_user.region = payload.region
    db.commit()
    db.refresh(current_user)
    return current_user


@router.get("/me/favorites", response_model=list[MovieSummary])
def list_favorites(db: DbSession, current_user: CurrentUser):
    return UserMovieService(db).list_favorites(current_user)


@router.get("/me/watchlist", response_model=list[MovieSummary])
def list_watchlist(db: DbSession, current_user: CurrentUser):
    return UserMovieService(db).list_watchlist(current_user)


@router.get("/me/watched", response_model=list[MovieSummary])
def list_watched(db: DbSession, current_user: CurrentUser):
    return UserMovieService(db).list_watched(current_user)


@router.get("/me/ratings", response_model=list[RatingWithMovieOut])
def list_ratings(db: DbSession, current_user: CurrentUser):
    return UserMovieService(db).list_ratings(current_user)


@router.get("/search", response_model=list[UserPublicOut])
def search_users(
    db: DbSession,
    current_user: CurrentUser,
    q: str = Query(min_length=2, max_length=64, description="Partial username, case-insensitive"),
    limit: int = Query(default=20, ge=1, le=50),
):
    return UserRepository(db).search_by_username(
        q, limit=limit, exclude_user_id=current_user.id
    )


# ---- Other users' collections (friendship) ----


@router.get("/{user_id}/favorites", response_model=list[MovieSummary])
def list_other_favorites(
    user_id: uuid.UUID, db: DbSession, current_user: CurrentUser
):
    FriendshipService(db).assert_can_view_profile(current_user, user_id)
    return UserMovieService(db).list_favorites_for(user_id)


@router.get("/{user_id}/watchlist", response_model=list[MovieSummary])
def list_other_watchlist(
    user_id: uuid.UUID, db: DbSession, current_user: CurrentUser
):
    FriendshipService(db).assert_can_view_profile(current_user, user_id)
    return UserMovieService(db).list_watchlist_for(user_id)


@router.get("/{user_id}/watched", response_model=list[MovieSummary])
def list_other_watched(
    user_id: uuid.UUID, db: DbSession, current_user: CurrentUser
):
    FriendshipService(db).assert_can_view_profile(current_user, user_id)
    return UserMovieService(db).list_watched_for(user_id)


@router.get("/{user_id}/ratings", response_model=list[RatingWithMovieOut])
def list_other_ratings(
    user_id: uuid.UUID, db: DbSession, current_user: CurrentUser
):
    FriendshipService(db).assert_can_view_profile(current_user, user_id)
    return UserMovieService(db).list_ratings_for(user_id)
