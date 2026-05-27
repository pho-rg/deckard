from fastapi import APIRouter, HTTPException, Query, status

from app.deps import CurrentUser, DbSession
from app.integrations.tmdb import TMDBNotFound, TMDBRateLimited, TMDBUnavailable
from app.schemas.movie import MovieOut, PagedMovies
from app.schemas.user_movie import RatingIn, UserStateOut
from app.services.movie_service import MovieService
from app.services.user_movie_service import UserMovieService

router = APIRouter(prefix="/movies", tags=["movies"])


# ---- Static paths MUST come before /{tmdb_id} (FastAPI matches in order). ----


@router.get("/search", response_model=PagedMovies)
def search_movies(
    db: DbSession,
    current_user: CurrentUser,
    q: str = Query(min_length=1, max_length=200, description="Search query"),
    page: int = Query(default=1, ge=1, le=500),
):
    try:
        return MovieService(db).search_movies(q, page=page, language=current_user.language)
    except (TMDBRateLimited, TMDBUnavailable) as exc:
        _raise_upstream(exc)


@router.get("/trending", response_model=PagedMovies)
def list_trending(db: DbSession, current_user: CurrentUser):
    try:
        return MovieService(db).list_trending(language=current_user.language)
    except (TMDBRateLimited, TMDBUnavailable) as exc:
        _raise_upstream(exc)


@router.get("/now-playing", response_model=PagedMovies)
def list_now_playing(
    db: DbSession,
    current_user: CurrentUser,
    page: int = Query(default=1, ge=1, le=500),
):
    try:
        return MovieService(db).list_now_playing(
            region=current_user.region,
            page=page,
            language=current_user.language,
        )
    except (TMDBRateLimited, TMDBUnavailable) as exc:
        _raise_upstream(exc)


# ---- /{tmdb_id} ----


@router.get("/{tmdb_id}", response_model=MovieOut)
def get_movie(tmdb_id: int, db: DbSession, current_user: CurrentUser):
    try:
        return MovieService(db).get_movie_details(tmdb_id, language=current_user.language)
    except TMDBNotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Movie not found"
        ) from None
    except (TMDBRateLimited, TMDBUnavailable) as exc:
        _raise_upstream(exc)


@router.get("/{tmdb_id}/user-state", response_model=UserStateOut)
def get_user_state(tmdb_id: int, db: DbSession, current_user: CurrentUser):
    return UserMovieService(db).get_user_state(current_user, tmdb_id)


# ---- Favorites ----


@router.post("/{tmdb_id}/favorite", status_code=status.HTTP_204_NO_CONTENT)
def add_favorite(tmdb_id: int, db: DbSession, current_user: CurrentUser):
    try:
        UserMovieService(db).add_favorite(current_user, tmdb_id)
    except TMDBNotFound:
        raise HTTPException(404, detail="Movie not found") from None
    except (TMDBRateLimited, TMDBUnavailable) as exc:
        _raise_upstream(exc)


@router.delete("/{tmdb_id}/favorite", status_code=status.HTTP_204_NO_CONTENT)
def remove_favorite(tmdb_id: int, db: DbSession, current_user: CurrentUser):
    UserMovieService(db).remove_favorite(current_user, tmdb_id)


# ---- Watchlist ----


@router.post("/{tmdb_id}/watchlist", status_code=status.HTTP_204_NO_CONTENT)
def add_to_watchlist(tmdb_id: int, db: DbSession, current_user: CurrentUser):
    try:
        UserMovieService(db).add_to_watchlist(current_user, tmdb_id)
    except TMDBNotFound:
        raise HTTPException(404, detail="Movie not found") from None
    except (TMDBRateLimited, TMDBUnavailable) as exc:
        _raise_upstream(exc)


@router.delete("/{tmdb_id}/watchlist", status_code=status.HTTP_204_NO_CONTENT)
def remove_from_watchlist(tmdb_id: int, db: DbSession, current_user: CurrentUser):
    UserMovieService(db).remove_from_watchlist(current_user, tmdb_id)


# ---- Watched ----


@router.post("/{tmdb_id}/watched", status_code=status.HTTP_204_NO_CONTENT)
def mark_watched(tmdb_id: int, db: DbSession, current_user: CurrentUser):
    try:
        UserMovieService(db).mark_watched(current_user, tmdb_id)
    except TMDBNotFound:
        raise HTTPException(404, detail="Movie not found") from None
    except (TMDBRateLimited, TMDBUnavailable) as exc:
        _raise_upstream(exc)


@router.delete("/{tmdb_id}/watched", status_code=status.HTTP_204_NO_CONTENT)
def unmark_watched(tmdb_id: int, db: DbSession, current_user: CurrentUser):
    UserMovieService(db).unmark_watched(current_user, tmdb_id)


# ---- Rating ----


@router.put("/{tmdb_id}/rating", status_code=status.HTTP_204_NO_CONTENT)
def set_rating(
    tmdb_id: int,
    payload: RatingIn,
    db: DbSession,
    current_user: CurrentUser,
):
    try:
        UserMovieService(db).set_rating(current_user, tmdb_id, payload.stars)
    except TMDBNotFound:
        raise HTTPException(404, detail="Movie not found") from None
    except (TMDBRateLimited, TMDBUnavailable) as exc:
        _raise_upstream(exc)


@router.delete("/{tmdb_id}/rating", status_code=status.HTTP_204_NO_CONTENT)
def remove_rating(tmdb_id: int, db: DbSession, current_user: CurrentUser):
    UserMovieService(db).remove_rating(current_user, tmdb_id)


# ---- helpers ----


def _raise_upstream(exc: Exception):
    if isinstance(exc, TMDBRateLimited):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="TMDB rate limit hit, please retry shortly",
        ) from None
    raise HTTPException(
        status_code=status.HTTP_502_BAD_GATEWAY, detail="TMDB unavailable"
    ) from None
