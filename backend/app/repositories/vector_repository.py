"""Repository for pgvector-based similarity queries on the ``vecteur`` table.

The table lives in ``public.vecteur`` and was loaded from Issame's dump.
It is NOT managed by Alembic — it has its own ``movie_id`` PK (= tmdb_id)
and a ``full_vector vector(406)`` column indexed by pgvector.

Two public methods:
* ``similar`` — given one movie, return its N nearest neighbours.
* ``personal`` — given a list of liked/rated movie IDs, aggregate
  multi-vector neighbours and return top-N recommendations.
"""

from __future__ import annotations

import uuid

from sqlalchemy import func, text, union_all, select
from sqlalchemy.orm import Session

from app.models.favorite import Favorite
from app.models.rating import Rating
from app.models.watched import WatchedItem
from app.models.watchlist import WatchlistItem


class VectorRepository:
    def __init__(self, db: Session):
        self.db = db

    # ------------------------------------------------------------------
    # 1. Similar movies (for the movie detail page)
    # ------------------------------------------------------------------

    def similar(self, tmdb_id: int, *, limit: int = 10) -> list[int]:
        """Return *limit* tmdb_ids most similar to *tmdb_id* using cosine
        distance (``<=>``) on ``full_vector``.  Returns an empty list when
        the movie has no vector (not in the vecteur table)."""

        row = self.db.execute(
            text("SELECT full_vector FROM public.vecteur WHERE movie_id = :mid"),
            {"mid": tmdb_id},
        ).fetchone()

        if row is None or row[0] is None:
            return []

        rows = self.db.execute(
            text("""
                SELECT v.movie_id
                FROM public.vecteur v
                JOIN movies m ON m.tmdb_id = v.movie_id
                WHERE v.movie_id != :mid
                  AND m.poster_path IS NOT NULL
                ORDER BY v.full_vector <=> CAST(:vec AS vector)
                LIMIT :lim
            """),
            {"mid": tmdb_id, "vec": row[0], "lim": limit},
        ).fetchall()

        return [r[0] for r in rows]

    # ------------------------------------------------------------------
    # 2. Personal recommendations (multi-vector aggregation)
    # ------------------------------------------------------------------

    def personal(
        self,
        user_id: uuid.UUID,
        *,
        limit: int = 20,
        top_n_per_query: int = 20,
    ) -> list[int]:
        """Build personal recommendations from the user's positive signals
        (favorites + high ratings) using multi-vector aggregation.

        For each liked movie we fetch its *top_n_per_query* nearest
        neighbours, then rank candidates by a weighted combination of
        average similarity score (70 %) and frequency of appearance (30 %).
        Movies the user already interacted with are excluded.

        Returns up to *limit* tmdb_ids, best first.
        """

        # --- 10 most recent liked movies (favorites + ratings >= 8/10) ---
        fav = select(
            Favorite.movie_id.label("movie_id"),
            Favorite.created_at.label("interaction_date"),
        ).where(Favorite.user_id == user_id)

        high_rated = select(
            Rating.movie_id.label("movie_id"),
            Rating.updated_at.label("interaction_date"),
        ).where(Rating.user_id == user_id, Rating.rating >= 8)

        combined = union_all(fav, high_rated).subquery()

        liked_rows = self.db.execute(
            select(combined.c.movie_id)
            .group_by(combined.c.movie_id)
            .order_by(func.max(combined.c.interaction_date).desc())
            .limit(10)
        ).fetchall()
        liked_ids = [r[0] for r in liked_rows]

        if not liked_ids:
            return []

        # --- movies the user already interacted with (to exclude) ---
        seen_q = union_all(
            select(Favorite.movie_id.label("movie_id")).where(Favorite.user_id == user_id),
            select(Rating.movie_id.label("movie_id")).where(Rating.user_id == user_id),
            select(WatchedItem.movie_id.label("movie_id")).where(WatchedItem.user_id == user_id),
            select(WatchlistItem.movie_id.label("movie_id")).where(WatchlistItem.user_id == user_id),
        ).subquery()
        seen_rows = self.db.execute(select(seen_q.c.movie_id)).fetchall()
        seen_ids = {r[0] for r in seen_rows}

        # --- multi-vector aggregation ---
        # {movie_id: [distance1, distance2, ...]}
        candidates: dict[int, list[float]] = {}

        for mid in liked_ids:
            vec_row = self.db.execute(
                text("SELECT full_vector FROM public.vecteur WHERE movie_id = :mid"),
                {"mid": mid},
            ).fetchone()
            if vec_row is None or vec_row[0] is None:
                continue

            neighbours = self.db.execute(
                text("""
                    SELECT v.movie_id,
                           (v.full_vector <=> CAST(:vec AS vector)) AS dist
                    FROM public.vecteur v
                    JOIN movies m ON m.tmdb_id = v.movie_id
                    WHERE v.movie_id != ALL(:excluded)
                      AND m.poster_path IS NOT NULL
                    ORDER BY v.full_vector <=> CAST(:vec AS vector)
                    LIMIT :lim
                """),
                {
                    "vec": vec_row[0],
                    "excluded": liked_ids,
                    "lim": top_n_per_query,
                },
            ).fetchall()

            for nb in neighbours:
                candidates.setdefault(nb[0], []).append(float(nb[1]))

        if not candidates:
            return []

        # --- scoring: avg_similarity * 0.7  +  frequency_norm * 0.3 ---
        # Lower distance = more similar, so we invert: similarity = 1 - dist
        n_queries = len(liked_ids)
        scored: list[tuple[int, float]] = []
        for mid, dists in candidates.items():
            if mid in seen_ids:
                continue
            avg_sim = 1.0 - (sum(dists) / len(dists))
            freq_norm = len(dists) / n_queries
            score = avg_sim * 0.7 + freq_norm * 0.3
            scored.append((mid, score))

        scored.sort(key=lambda x: x[1], reverse=True)
        return [mid for mid, _ in scored[:limit]]
