from fastapi import APIRouter

from app.deps import CurrentUser, DbSession
from app.schemas.movie import MovieSummary
from app.schemas.user import UserOut, UserUpdate
from app.schemas.user_movie import RatingWithMovieOut
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
