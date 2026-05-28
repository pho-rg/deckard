from datetime import datetime, timezone
from typing import Any

from sqlalchemy import delete, func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session, joinedload, selectinload

from app.models.featured_movie import FeaturedMovie
from app.models.genre import Genre
from app.models.genre_content import GenreContent
from app.models.movie import Movie, MovieStatus
from app.models.movie_cast import MovieCast
from app.models.movie_content import MovieContent
from app.models.movie_crew import MovieCrew
from app.models.movie_genre import MovieGenre
from app.models.person import Person
from app.models.person_content import PersonContent
from app.models.video import Video

# Eager-load everything the presenter needs to localize a full movie.
_FULL_OPTIONS = (
    selectinload(Movie.contents),
    selectinload(Movie.videos),
    selectinload(Movie.genres).selectinload(Genre.contents),
    selectinload(Movie.cast).joinedload(MovieCast.person).selectinload(Person.contents),
    selectinload(Movie.crew).joinedload(MovieCrew.person).selectinload(Person.contents),
)


class MovieRepository:
    def __init__(self, db: Session):
        self.db = db

    # ------------ reads ------------

    def get_full(self, tmdb_id: int) -> Movie | None:
        return self.db.scalar(
            select(Movie).where(Movie.tmdb_id == tmdb_id).options(*_FULL_OPTIONS)
        )

    def exists(self, tmdb_id: int) -> bool:
        return self.db.scalar(
            select(Movie.tmdb_id).where(Movie.tmdb_id == tmdb_id).limit(1)
        ) is not None

    def get_featured(self) -> Movie | None:
        now = func.now()
        active = self.db.scalar(
            select(Movie)
            .join(FeaturedMovie, FeaturedMovie.movie_id == Movie.tmdb_id)
            .where(FeaturedMovie.starts_at <= now, FeaturedMovie.ends_at >= now)
            .order_by(FeaturedMovie.starts_at.desc())
            .limit(1)
            .options(*_FULL_OPTIONS)
        )
        if active is not None:
            return active
        return self.db.scalar(
            select(Movie)
            .join(FeaturedMovie, FeaturedMovie.movie_id == Movie.tmdb_id)
            .order_by(FeaturedMovie.created_at.desc())
            .limit(1)
            .options(*_FULL_OPTIONS)
        )

    # ------------ upserts (TMDB safety-net sync) ------------

    def upsert_movie(self, payload: dict[str, Any], language_iso: str) -> None:
        now = datetime.now(timezone.utc)
        stmt = insert(Movie).values(
            tmdb_id=payload["id"],
            imdb_id=payload.get("imdb_id"),
            original_title=payload.get("original_title"),
            release_date=payload.get("release_date") or None,
            runtime=payload.get("runtime"),
            poster_path=payload.get("poster_path"),
            backdrop_path=payload.get("backdrop_path"),
            original_language=payload.get("original_language"),
            vote_average=payload.get("vote_average"),
            status=_map_status(payload.get("status")),
            updated_at=now,
        )
        stmt = stmt.on_conflict_do_update(
            index_elements=[Movie.tmdb_id],
            set_={
                "imdb_id": stmt.excluded.imdb_id,
                "original_title": stmt.excluded.original_title,
                "release_date": stmt.excluded.release_date,
                "runtime": stmt.excluded.runtime,
                "poster_path": stmt.excluded.poster_path,
                "backdrop_path": stmt.excluded.backdrop_path,
                "original_language": stmt.excluded.original_language,
                "vote_average": stmt.excluded.vote_average,
                "status": stmt.excluded.status,
                "updated_at": stmt.excluded.updated_at,
            },
        )
        self.db.execute(stmt)

        title = payload.get("title") or payload.get("original_title") or ""
        content = insert(MovieContent).values(
            tmdb_id=payload["id"],
            language_iso=language_iso,
            title=title,
            overview=payload.get("overview") or None,
            tag_line=payload.get("tagline") or None,
        )
        content = content.on_conflict_do_update(
            index_elements=[MovieContent.tmdb_id, MovieContent.language_iso],
            set_={
                "title": content.excluded.title,
                "overview": content.excluded.overview,
                "tag_line": content.excluded.tag_line,
            },
        )
        self.db.execute(content)

    def replace_genres(
        self, movie_id: int, genres_payload: list[dict[str, Any]], language_iso: str
    ) -> None:
        if genres_payload:
            self.db.execute(
                insert(Genre)
                .values([{"tmdb_id": g["id"]} for g in genres_payload])
                .on_conflict_do_nothing(index_elements=[Genre.tmdb_id])
            )
            gc = insert(GenreContent).values(
                [
                    {"tmdb_id": g["id"], "language_iso": language_iso, "name": g["name"]}
                    for g in genres_payload
                ]
            )
            gc = gc.on_conflict_do_update(
                index_elements=[GenreContent.tmdb_id, GenreContent.language_iso],
                set_={"name": gc.excluded.name},
            )
            self.db.execute(gc)

        self.db.execute(delete(MovieGenre).where(MovieGenre.movie_id == movie_id))
        if genres_payload:
            self.db.execute(
                insert(MovieGenre).values(
                    [{"movie_id": movie_id, "genre_id": g["id"]} for g in genres_payload]
                )
            )

    def replace_credits(
        self, movie_id: int, credits_payload: dict[str, Any], language_iso: str
    ) -> None:
        cast = credits_payload.get("cast", [])
        crew = credits_payload.get("crew", [])

        # Upsert persons (only fields credits provides — don't clobber rich data).
        people: dict[int, dict[str, Any]] = {}
        names: dict[int, str] = {}
        for entry in (*cast, *crew):
            pid = entry["id"]
            people[pid] = {
                "tmdb_id": pid,
                "gender": entry.get("gender"),
                "known_for_department": entry.get("known_for_department"),
                "profile_path": entry.get("profile_path"),
            }
            names[pid] = entry.get("name") or ""

        if people:
            p_stmt = insert(Person).values(list(people.values()))
            p_stmt = p_stmt.on_conflict_do_update(
                index_elements=[Person.tmdb_id],
                set_={
                    "gender": p_stmt.excluded.gender,
                    "known_for_department": p_stmt.excluded.known_for_department,
                    "profile_path": p_stmt.excluded.profile_path,
                },
            )
            self.db.execute(p_stmt)

            pc_stmt = insert(PersonContent).values(
                [
                    {"tmdb_id": pid, "language_iso": language_iso, "name": name}
                    for pid, name in names.items()
                ]
            )
            pc_stmt = pc_stmt.on_conflict_do_update(
                index_elements=[PersonContent.tmdb_id, PersonContent.language_iso],
                set_={"name": pc_stmt.excluded.name},
            )
            self.db.execute(pc_stmt)

        self.db.execute(delete(MovieCast).where(MovieCast.movie_id == movie_id))
        self.db.execute(delete(MovieCrew).where(MovieCrew.movie_id == movie_id))

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

    def replace_video(
        self, movie_id: int, videos_payload: dict[str, Any], language_iso: str
    ) -> None:
        key = _pick_trailer(videos_payload.get("results", []))
        self.db.execute(
            delete(Video).where(
                Video.tmdb_id == movie_id, Video.language_iso == language_iso
            )
        )
        if key:
            self.db.execute(
                insert(Video).values(
                    tmdb_id=movie_id, language_iso=language_iso, youtube_key=key
                )
            )


def _map_status(raw: str | None) -> MovieStatus | None:
    if raw is None:
        return None
    return MovieStatus.released if raw == "Released" else MovieStatus.not_released


def _pick_trailer(results: list[dict[str, Any]]) -> str | None:
    youtube = [v for v in results if v.get("site") == "YouTube" and v.get("key")]
    trailers = [v for v in youtube if v.get("type") == "Trailer"]
    official = [v for v in trailers if v.get("official")]
    chosen = official or trailers or youtube
    return chosen[0]["key"] if chosen else None
