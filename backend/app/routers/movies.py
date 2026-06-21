from fastapi import APIRouter, HTTPException, Query, status

from app.deps import CurrentUser, DbSession
from app.integrations.tmdb import TMDBRateLimited, TMDBUnavailable
from app.schemas.movie import MovieCard, MovieDetailOut, MovieIdsIn, PagedMovies
from app.schemas.user_movie import MovieRatingsOut, RatingIn, UserStateOut
from app.services.movie_service import MovieNotFound, MovieService
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
    # DB-backed: searches our imported catalogue, no TMDB call.
    return MovieService(db).search_movies(q, page=page, language=current_user.language)


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
            region=current_user.region, page=page, language=current_user.language
        )
    except (TMDBRateLimited, TMDBUnavailable) as exc:
        _raise_upstream(exc)


@router.post("/by-ids", response_model=list[MovieCard])
def get_movies_by_ids(
    payload: MovieIdsIn, db: DbSession, current_user: CurrentUser
):
    # DB-backed batch resolve for the onboarding grid (fixed tmdb_id list).
    return MovieService(db).cards_by_ids(
        payload.tmdb_ids, language=current_user.language
    )


@router.get("/featured", response_model=MovieDetailOut)
def get_featured(db: DbSession, current_user: CurrentUser):
    movie = MovieService(db).get_featured(language=current_user.language)
    if movie is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="No featured movie configured"
        )
    return movie


# ---- /{tmdb_id} ----


@router.get("/{tmdb_id}", response_model=MovieDetailOut)
def get_movie(tmdb_id: int, db: DbSession, current_user: CurrentUser):
    try:
        return MovieService(db).get_movie_details(tmdb_id, language=current_user.language)
    except MovieNotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Movie not found"
        ) from None


@router.get("/{tmdb_id}/user-state", response_model=UserStateOut)
def get_user_state(tmdb_id: int, db: DbSession, current_user: CurrentUser):
    return UserMovieService(db).get_user_state(current_user, tmdb_id)


@router.get("/{tmdb_id}/reviews", response_model=MovieRatingsOut)
def get_movie_reviews(tmdb_id: int, db: DbSession, current_user: CurrentUser):
    # Public: aggregate ratings + text reviews from all users.
    return MovieService(db).get_movie_ratings(tmdb_id)


@router.get("/{tmdb_id}/similar", response_model=list[MovieCard])
def get_similar_movies(
    tmdb_id: int,
    db: DbSession,
    current_user: CurrentUser,
    limit: int = Query(default=10, ge=1, le=30),
):
    # V1: random movies from our catalogue (AI model to come later).
    return MovieService(db).list_similar(
        tmdb_id, limit=limit, language=current_user.language
    )


# ---- Favorites ----


@router.post("/{tmdb_id}/favorite", status_code=status.HTTP_204_NO_CONTENT)
def add_favorite(tmdb_id: int, db: DbSession, current_user: CurrentUser):
    try:
        UserMovieService(db).add_favorite(current_user, tmdb_id)
    except MovieNotFound:
        raise HTTPException(404, detail="Movie not found") from None


@router.delete("/{tmdb_id}/favorite", status_code=status.HTTP_204_NO_CONTENT)
def remove_favorite(tmdb_id: int, db: DbSession, current_user: CurrentUser):
    UserMovieService(db).remove_favorite(current_user, tmdb_id)


# ---- Watchlist ----


@router.post("/{tmdb_id}/watchlist", status_code=status.HTTP_204_NO_CONTENT)
def add_to_watchlist(tmdb_id: int, db: DbSession, current_user: CurrentUser):
    try:
        UserMovieService(db).add_to_watchlist(current_user, tmdb_id)
    except MovieNotFound:
        raise HTTPException(404, detail="Movie not found") from None


@router.delete("/{tmdb_id}/watchlist", status_code=status.HTTP_204_NO_CONTENT)
def remove_from_watchlist(tmdb_id: int, db: DbSession, current_user: CurrentUser):
    UserMovieService(db).remove_from_watchlist(current_user, tmdb_id)


# ---- Watched ----


@router.post("/{tmdb_id}/watched", status_code=status.HTTP_204_NO_CONTENT)
def mark_watched(tmdb_id: int, db: DbSession, current_user: CurrentUser):
    try:
        UserMovieService(db).mark_watched(current_user, tmdb_id)
    except MovieNotFound:
        raise HTTPException(404, detail="Movie not found") from None


@router.delete("/{tmdb_id}/watched", status_code=status.HTTP_204_NO_CONTENT)
def unmark_watched(tmdb_id: int, db: DbSession, current_user: CurrentUser):
    UserMovieService(db).unmark_watched(current_user, tmdb_id)


# ---- Rating ----


@router.put("/{tmdb_id}/rating", status_code=status.HTTP_204_NO_CONTENT)
def set_rating(
    tmdb_id: int, payload: RatingIn, db: DbSession, current_user: CurrentUser
):
    try:
        UserMovieService(db).set_rating(
            current_user, tmdb_id, payload.stars, payload.review
        )
    except MovieNotFound:
        raise HTTPException(404, detail="Movie not found") from None


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
