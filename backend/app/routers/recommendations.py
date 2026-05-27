from fastapi import APIRouter, Query

from app.deps import CurrentUser, DbSession
from app.schemas.movie import MovieSummary
from app.services.recommendation_service import RecommendationService

router = APIRouter(prefix="/recommendations", tags=["recommendations"])


@router.get("/from-friends", response_model=list[MovieSummary])
def recommendations_from_friends(
    db: DbSession,
    current_user: CurrentUser,
    limit: int = Query(
        default=10,
        ge=1,
        le=50,
        description="Number of recommendations to return (short list = 10, longer = up to 50)",
    ),
):
    return RecommendationService(db).from_friends(current_user, limit=limit)
