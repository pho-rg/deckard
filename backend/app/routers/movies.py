from fastapi import APIRouter, HTTPException, status

from app.deps import CurrentUser, DbSession
from app.integrations.tmdb import TMDBNotFound, TMDBRateLimited, TMDBUnavailable
from app.schemas.movie import MovieOut
from app.services.movie_service import MovieService

router = APIRouter(prefix="/movies", tags=["movies"])


@router.get("/{tmdb_id}", response_model=MovieOut)
def get_movie(tmdb_id: int, db: DbSession, current_user: CurrentUser):
    try:
        return MovieService(db).get_movie_details(tmdb_id, language=current_user.language)
    except TMDBNotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Movie not found"
        ) from None
    except TMDBRateLimited:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="TMDB rate limit hit, please retry shortly",
        ) from None
    except TMDBUnavailable:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail="TMDB unavailable"
        ) from None
