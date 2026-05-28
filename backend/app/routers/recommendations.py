from fastapi import APIRouter, Query

from app.deps import CurrentUser, DbSession
from app.schemas.movie import MovieCard
from app.services.recommendation_service import RecommendationService

router = APIRouter(prefix="/recommendations", tags=["recommendations"])


@router.get("/from-friends", response_model=list[MovieCard])
def recommendations_from_friends(
    db: DbSession,
    current_user: CurrentUser,
    limit: int = Query(default=10, ge=1, le=50),
):
    return RecommendationService(db).from_friends(current_user, limit=limit)
