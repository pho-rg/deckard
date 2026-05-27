from sqlalchemy.orm import Session

from app.models.movie import Movie
from app.models.user import User
from app.repositories.recommendation_repository import RecommendationRepository


class RecommendationService:
    def __init__(self, db: Session):
        self.repo = RecommendationRepository(db)

    def from_friends(self, user: User, *, limit: int = 10) -> list[Movie]:
        return self.repo.from_friends(user.id, limit=limit)
