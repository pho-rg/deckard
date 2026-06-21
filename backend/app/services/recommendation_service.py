from sqlalchemy.orm import Session

from app.models.user import User
from app.repositories.recommendation_repository import RecommendationRepository
from app.schemas.movie import MovieCard
from app.services import presenter
from app.services.localization import to_iso2


class RecommendationService:
    def __init__(self, db: Session):
        self.repo = RecommendationRepository(db)

    def personal(self, user: User, *, limit: int = 20) -> list[MovieCard]:
        # V1: random unseen movies. Will be backed by an AI model later.
        iso = to_iso2(user.language)
        movies = self.repo.random_unseen(user.id, limit=limit)
        return [presenter.movie_card(m, iso) for m in movies]

    def from_friends(self, user: User, *, limit: int = 10) -> list[MovieCard]:
        iso = to_iso2(user.language)
        movies = self.repo.from_friends(user.id, limit=limit)
        return [presenter.movie_card(m, iso) for m in movies]
