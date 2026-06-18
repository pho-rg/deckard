import uuid
from datetime import datetime, timezone

from sqlalchemy import delete, func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.orm import Session, joinedload, selectinload

from app.models.movie import Movie
from app.models.rating import Rating
from app.models.user import User


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

    # ---- public reviews for a single movie ----

    def list_reviews_for_movie(
        self, movie_id: int, *, limit: int = 100
    ) -> list[Rating]:
        # Public reviews = ratings that carry a non-empty text, newest first.
        return list(
            self.db.scalars(
                select(Rating)
                .where(
                    Rating.movie_id == movie_id,
                    Rating.review.is_not(None),
                    Rating.review != "",
                )
                .order_by(Rating.updated_at.desc())
                .options(joinedload(Rating.user))
                .limit(limit)
            )
        )

    def community_average(self, movie_id: int) -> float | None:
        """Mean of all Deckard ratings for a movie, on a 0-5 stars scale
        (rating is stored as half-stars 0-10, hence the /2). None when there
        are no ratings."""
        avg = self.db.scalar(
            select(func.avg(Rating.rating)).where(Rating.movie_id == movie_id)
        )
        return round(float(avg) / 2, 1) if avg is not None else None

    def stats_for_movie(self, movie_id: int) -> tuple[float | None, int, list[int]]:
        """Aggregate ratings for a movie: (average in 0-5 stars, count,
        distribution over the 10 half-star buckets 0.5..5.0)."""
        rows = self.db.execute(
            select(Rating.rating, func.count())
            .where(Rating.movie_id == movie_id)
            .group_by(Rating.rating)
        ).all()

        # distribution[i] = number of ratings worth (i+1) half-stars (i.e.
        # 0.5..5.0 stars). Half-star value 0 (0 stars) is not charted.
        distribution = [0] * 10
        total = 0
        weighted = 0
        for half_stars, n in rows:
            total += n
            weighted += half_stars * n
            if 1 <= half_stars <= 10:
                distribution[half_stars - 1] = n

        average = (weighted / total / 2) if total else None
        return average, total, distribution
