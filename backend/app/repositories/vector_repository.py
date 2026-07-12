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

from sqlalchemy import text, union_all, select
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
                SELECT movie_id
                FROM public.vecteur
                WHERE movie_id != :mid
                ORDER BY full_vector <=> CAST(:vec AS vector)
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

        # --- liked movie ids (favorites + ratings >= 7/10 i.e. 3.5 stars) ---
        fav_ids = (
            select(Favorite.movie_id.label("movie_id"))
            .where(Favorite.user_id == user_id)
        )
        high_rated_ids = (
            select(Rating.movie_id.label("movie_id"))
            .where(Rating.user_id == user_id, Rating.rating >= 7)
        )
        liked_q = union_all(fav_ids, high_rated_ids).subquery()
        liked_rows = self.db.execute(select(liked_q.c.movie_id)).fetchall()
        liked_ids = list({r[0] for r in liked_rows})

        if not liked_ids:
            return []

        # Cap the number of seed movies to avoid too many vector scans
        if len(liked_ids) > 10:
            liked_ids = liked_ids[:10]

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
                    SELECT movie_id,
                           (full_vector <=> CAST(:vec AS vector)) AS dist
                    FROM public.vecteur
                    WHERE movie_id != ALL(:excluded)
                    ORDER BY full_vector <=> CAST(:vec AS vector)
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
