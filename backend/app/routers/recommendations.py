from fastapi import APIRouter, Query

from app.deps import CurrentUser, DbSession
from app.schemas.movie import MovieCard
from app.services.recommendation_service import RecommendationService

router = APIRouter(prefix="/recommendations", tags=["recommendations"])


@router.get("", response_model=list[MovieCard])
def personal_recommendations(
    db: DbSession,
    current_user: CurrentUser,
    limit: int = Query(default=20, ge=1, le=50),
):
    # V1: random unseen movies from our catalogue (AI model to come later).
    return RecommendationService(db).personal(current_user, limit=limit)


@router.get("/from-friends", response_model=list[MovieCard])
def recommendations_from_friends(
    db: DbSession,
    current_user: CurrentUser,
    limit: int = Query(default=10, ge=1, le=50),
):
    return RecommendationService(db).from_friends(current_user, limit=limit)
