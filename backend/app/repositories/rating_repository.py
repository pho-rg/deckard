import uuid
from datetime import datetime, timezone

from sqlalchemy import delete, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.orm import Session, joinedload, selectinload

from app.models.movie import Movie
from app.models.rating import Rating


class RatingRepository:
    def __init__(self, db: Session):
        self.db = db

    def get(self, user_id: uuid.UUID, movie_id: int) -> Rating | None:
        return self.db.scalar(
            select(Rating).where(
                Rating.user_id == user_id, Rating.movie_id == movie_id
            )
        )

    def upsert(
        self,
        user_id: uuid.UUID,
        movie_id: int,
        half_stars: int,
        review: str | None = None,
    ) -> None:
        now = datetime.now(timezone.utc)
        stmt = pg_insert(Rating).values(
            user_id=user_id,
            movie_id=movie_id,
            rating=half_stars,
            review=review,
            created_at=now,
            updated_at=now,
        )
        stmt = stmt.on_conflict_do_update(
            index_elements=[Rating.user_id, Rating.movie_id],
            set_={
                "rating": stmt.excluded.rating,
                "review": stmt.excluded.review,
                "updated_at": stmt.excluded.updated_at,
            },
        )
        self.db.execute(stmt)
        self.db.commit()

    def remove(self, user_id: uuid.UUID, movie_id: int) -> bool:
        result = self.db.execute(
            delete(Rating).where(
                Rating.user_id == user_id, Rating.movie_id == movie_id
            )
        )
        self.db.commit()
        return result.rowcount > 0

    def list_for_user(self, user_id: uuid.UUID) -> list[Rating]:
        return list(
            self.db.scalars(
                select(Rating)
                .where(Rating.user_id == user_id)
                .order_by(Rating.updated_at.desc())
                .options(joinedload(Rating.movie).selectinload(Movie.contents))
            )
        )
