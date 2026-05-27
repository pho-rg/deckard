from datetime import datetime, timezone
from typing import Any

from sqlalchemy import delete, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session, selectinload

from app.models.genre import Genre
from app.models.movie import Movie
from app.models.movie_cast import MovieCast
from app.models.movie_crew import MovieCrew
from app.models.movie_genre import MovieGenre
from app.models.person import Person


class MovieRepository:
    """Persistence for the lazy-cached movie graph (movie + genres + credits)."""

    def __init__(self, db: Session):
        self.db = db

    def get_full(self, tmdb_id: int) -> Movie | None:
        """Load a movie with genres, cast and crew eagerly."""
        return self.db.scalar(
            select(Movie)
            .where(Movie.tmdb_id == tmdb_id)
            .options(
                selectinload(Movie.genres),
                selectinload(Movie.cast).joinedload(MovieCast.person),
                selectinload(Movie.crew).joinedload(MovieCrew.person),
            )
        )

    # ------------ upserts ------------

    def upsert_movie(self, payload: dict[str, Any]) -> None:
        """Upsert the main movies row from a TMDB ``/movie/{id}`` payload."""
        stmt = insert(Movie).values(
            tmdb_id=payload["id"],
            title=payload.get("title") or payload.get("original_title") or "",
            original_title=payload.get("original_title"),
            overview=payload.get("overview") or None,
            release_date=_safe_date(payload.get("release_date")),
            runtime=payload.get("runtime"),
            poster_path=payload.get("poster_path"),
            backdrop_path=payload.get("backdrop_path"),
            original_language=payload.get("original_language"),
            vote_average=payload.get("vote_average"),
            last_synced_at=datetime.now(timezone.utc),
        )
        stmt = stmt.on_conflict_do_update(
            index_elements=[Movie.tmdb_id],
            set_={
                "title": stmt.excluded.title,
                "original_title": stmt.excluded.original_title,
                "overview": stmt.excluded.overview,
                "release_date": stmt.excluded.release_date,
                "runtime": stmt.excluded.runtime,
                "poster_path": stmt.excluded.poster_path,
                "backdrop_path": stmt.excluded.backdrop_path,
                "original_language": stmt.excluded.original_language,
                "vote_average": stmt.excluded.vote_average,
                "last_synced_at": stmt.excluded.last_synced_at,
            },
        )
        self.db.execute(stmt)

    def replace_genres(self, movie_id: int, genres_payload: list[dict[str, Any]]) -> None:
        """Replace the movie's genre links. Upserts unknown genres defensively."""
        if genres_payload:
            # Safety net: if TMDB references a genre we haven't synced yet, insert it.
            genre_stmt = insert(Genre).values(
                [{"tmdb_id": g["id"], "name": g["name"]} for g in genres_payload]
            ).on_conflict_do_nothing(index_elements=[Genre.tmdb_id])
            self.db.execute(genre_stmt)

        self.db.execute(delete(MovieGenre).where(MovieGenre.movie_id == movie_id))
        if genres_payload:
            self.db.execute(
                insert(MovieGenre).values(
                    [{"movie_id": movie_id, "genre_id": g["id"]} for g in genres_payload]
                )
            )

    def replace_credits(self, movie_id: int, credits_payload: dict[str, Any]) -> None:
        """Replace cast and crew rows wholesale + upsert any referenced persons."""
        cast = credits_payload.get("cast", [])
        crew = credits_payload.get("crew", [])

        # 1. Upsert all unique persons referenced.
        people: dict[int, dict[str, Any]] = {}
        for entry in (*cast, *crew):
            people[entry["id"]] = {
                "tmdb_id": entry["id"],
                "name": entry.get("name") or "",
                "profile_path": entry.get("profile_path"),
            }
        if people:
            person_stmt = insert(Person).values(list(people.values()))
            person_stmt = person_stmt.on_conflict_do_update(
                index_elements=[Person.tmdb_id],
                set_={
                    "name": person_stmt.excluded.name,
                    "profile_path": person_stmt.excluded.profile_path,
                },
            )
            self.db.execute(person_stmt)

        # 2. Wipe existing credits for this movie.
        self.db.execute(delete(MovieCast).where(MovieCast.movie_id == movie_id))
        self.db.execute(delete(MovieCrew).where(MovieCrew.movie_id == movie_id))

        # 3. Insert new cast (dedupe by person_id — TMDB rarely duplicates).
        seen_cast: set[int] = set()
        cast_rows: list[dict[str, Any]] = []
        for c in cast:
            if c["id"] in seen_cast:
                continue
            seen_cast.add(c["id"])
            cast_rows.append(
                {
                    "movie_id": movie_id,
                    "person_id": c["id"],
                    "character": c.get("character") or None,
                    "cast_order": c.get("order", 0),
                }
            )
        if cast_rows:
            self.db.execute(insert(MovieCast).values(cast_rows))

        # 4. Insert new crew (dedupe by (person_id, job); drop entries without a job).
        seen_crew: set[tuple[int, str]] = set()
        crew_rows: list[dict[str, Any]] = []
        for c in crew:
            job = c.get("job")
            if not job:
                continue
            key = (c["id"], job)
            if key in seen_crew:
                continue
            seen_crew.add(key)
            crew_rows.append(
                {
                    "movie_id": movie_id,
                    "person_id": c["id"],
                    "job": job,
                    "department": c.get("department"),
                }
            )
        if crew_rows:
            self.db.execute(insert(MovieCrew).values(crew_rows))


def _safe_date(raw: str | None):
    """TMDB returns ``""`` for missing dates; coerce to None."""
    if not raw:
        return None
    return raw  # SQLAlchemy parses ISO date strings just fine
