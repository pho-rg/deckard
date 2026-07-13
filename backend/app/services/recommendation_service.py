from sqlalchemy.orm import Session

from app.config import settings
from app.models.user import User
from app.repositories.recommendation_repository import RecommendationRepository
from app.repositories.rating_repository import RatingRepository
from app.repositories.movie_repository import MovieRepository
from app.repositories.vector_repository import VectorRepository
from app.schemas.movie import MovieCard
from app.services import presenter
from app.services.localization import to_iso2
from app.services.ml_recommender import get_recommendations


class RecommendationService:
    def __init__(self, db: Session):
        self.repo = RecommendationRepository(db)
        self.ratings = RatingRepository(db)
        self.movies = MovieRepository(db)
        self.vectors = VectorRepository(db)

    def personal(self, user: User, *, limit: int = 20) -> list[MovieCard]:
        iso = to_iso2(user.language)

        if settings.reco_engine == "pgvector":
            return self._personal_pgvector(user, iso=iso, limit=limit)
        return self._personal_svd(user, iso=iso, limit=limit)

    def _personal_svd(self, user: User, *, iso: str, limit: int) -> list[MovieCard]:
        """Existing SVD/matrix-factorisation model (from S3)."""
        ratings = self.ratings.list_for_user(user.id)
        user_ratings = {r.movie_id: float(r.rating) / 2.0 for r in ratings}
        recommended_ids = get_recommendations([user_ratings], top_x=limit)

        movies_unord = self.movies.list_by_ids(recommended_ids)
        by_id = {m.tmdb_id: m for m in movies_unord}
        ordered = [by_id[tid] for tid in recommended_ids if tid in by_id]
        return [presenter.movie_card(m, iso) for m in ordered]

    def _personal_pgvector(self, user: User, *, iso: str, limit: int) -> list[MovieCard]:
        """pgvector content-based model (multi-vector aggregation)."""
        recommended_ids = self.vectors.personal(user.id, limit=limit)

        if not recommended_ids:
            # Fallback: user has no favorites/ratings → random unseen
            movies = self.repo.random_unseen(user.id, limit=limit)
            return [presenter.movie_card(m, iso) for m in movies]

        movies_unord = self.movies.list_by_ids(recommended_ids)
        by_id = {m.tmdb_id: m for m in movies_unord}
        # Filter out movies without poster, cap to requested limit
        ordered = [by_id[tid] for tid in recommended_ids
                   if tid in by_id and by_id[tid].poster_path][:limit]
        return [presenter.movie_card(m, iso) for m in ordered]

    def from_friends(self, user: User, *, limit: int = 10) -> list[MovieCard]:
        iso = to_iso2(user.language)
        movies = self.repo.from_friends(user.id, limit=limit)
        return [presenter.movie_card(m, iso) for m in movies]
