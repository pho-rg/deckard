from sqlalchemy.orm import Session

from app.models.user import User
from app.repositories.recommendation_repository import RecommendationRepository
from app.repositories.rating_repository import RatingRepository
from app.repositories.movie_repository import MovieRepository
from app.schemas.movie import MovieCard
from app.services import presenter
from app.services.localization import to_iso2
from app.services.ml_recommender import get_recommendations

class RecommendationService:
    def __init__(self, db: Session):
        self.repo = RecommendationRepository(db)
        self.ratings = RatingRepository(db)
        self.movies = MovieRepository(db)

    def personal(self, user: User, *, limit: int = 20) -> list[MovieCard]:
        iso = to_iso2(user.language)
        
        # 1. Récupérer les notes de l'utilisateur (converties en /5.0)
        ratings = self.ratings.list_for_user(user.id)
        user_ratings = {r.movie_id: float(r.rating) / 2.0 for r in ratings}
        
        # 2. Demander les recommandations au modèle ML
        recommended_ids = get_recommendations([user_ratings], top_x=limit)
        
        # 3. Récupérer les films en base
        # Attention : list_by_ids ne garantit pas l'ordre du modèle, on le restaure manuellement
        movies_unord = self.movies.list_by_ids(recommended_ids)
        by_id = {m.tmdb_id: m for m in movies_unord}
        
        ordered_movies = [by_id[tmdb_id] for tmdb_id in recommended_ids if tmdb_id in by_id]
        
        return [presenter.movie_card(m, iso) for m in ordered_movies]

    def from_friends(self, user: User, *, limit: int = 10) -> list[MovieCard]:
        iso = to_iso2(user.language)
        movies = self.repo.from_friends(user.id, limit=limit)
        return [presenter.movie_card(m, iso) for m in movies]