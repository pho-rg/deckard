from sqlalchemy import case, func, select, update
from sqlalchemy.orm import Session, joinedload, selectinload

from app.models.featured_movie import FeaturedMovie
from app.models.genre import Genre
from app.models.movie import Movie
from app.models.movie_cast import MovieCast
from app.models.movie_content import MovieContent
from app.models.movie_crew import MovieCrew
from app.models.person import Person

# Eager-load everything the presenter needs to localize a full movie.
_FULL_OPTIONS = (
    selectinload(Movie.contents),
    selectinload(Movie.videos),
    selectinload(Movie.genres).selectinload(Genre.contents),
    selectinload(Movie.cast).joinedload(MovieCast.person),
    selectinload(Movie.crew).joinedload(MovieCrew.person),
)

# Lighter eager-load for list/summary shapes.
_SUMMARY_OPTIONS = (
    selectinload(Movie.contents),
    selectinload(Movie.genres).selectinload(Genre.contents),
)


class MovieRepository:
    def __init__(self, db: Session):
        self.db = db

    # ------------ reads ------------

    def set_vote_average(self, tmdb_id: int, value: float | None) -> None:
        # Persist the community rating average onto the movie row.
        self.db.execute(
            update(Movie).where(Movie.tmdb_id == tmdb_id).values(vote_average=value)
        )
        self.db.commit()

    def get_full(self, tmdb_id: int) -> Movie | None:
        return self.db.scalar(
            select(Movie).where(Movie.tmdb_id == tmdb_id).options(*_FULL_OPTIONS)
        )

    def exists(self, tmdb_id: int) -> bool:
        return self.db.scalar(
            select(Movie.tmdb_id).where(Movie.tmdb_id == tmdb_id).limit(1)
        ) is not None

    def list_by_ids(self, tmdb_ids: list[int]) -> list[Movie]:
        # Fetch movies by tmdb_id, summary-eager-loaded. DB order (caller reorders).
        if not tmdb_ids:
            return []
        return list(
            self.db.scalars(
                select(Movie)
                .where(Movie.tmdb_id.in_(tmdb_ids))
                .options(*_SUMMARY_OPTIONS)
            ).unique()
        )

    def existing_ids(self, tmdb_ids: list[int]) -> set[int]:
        # Subset of the given ids that actually exist in our catalogue.
        if not tmdb_ids:
            return set()
        return set(
            self.db.scalars(
                select(Movie.tmdb_id).where(Movie.tmdb_id.in_(tmdb_ids))
            )
        )

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

    def search(
        self, query: str, *, page: int = 1, page_size: int = 20
    ) -> tuple[list[Movie], int]:
        """Full-catalogue search on localized titles (movie_content).

        Searches across all languages so "Interstellar", "Le Parrain",
        "The Godfather" all work regardless of the user's locale.
        Ranked by textual relevance (exact → prefix → substring), then
        by vote_average / release_date as tiebreakers.
        Deduplication via GROUP BY tmdb_id (a movie may match in several
        languages).
        """
        q = query.strip()
        pattern = f"%{q}%"
        q_lower = q.lower()

        match = MovieContent.title.ilike(pattern)

        relevance = case(
            (func.lower(MovieContent.title) == q_lower, 0),
            (func.lower(MovieContent.title).like(f"{q_lower}%"), 1),
            else_=2,
        )

        # Best (lowest) relevance per movie.
        ranked = (
            select(
                MovieContent.tmdb_id.label("tmdb_id"),
                func.min(relevance).label("relevance"),
            )
            .where(match)
            .group_by(MovieContent.tmdb_id)
            .subquery()
        )

        total = self.db.scalar(select(func.count()).select_from(ranked)) or 0
        if total == 0:
            return [], 0

        # Popularity proxy: number of cast entries. Well-known movies have
        # far more cast members imported than obscure ones (e.g. Fight Club
        # 1999 has 50+ cast vs a random documentary with 3).
        cast_counts = (
            select(
                MovieCast.movie_id.label("mid"),
                func.count().label("n"),
            )
            .where(MovieCast.movie_id.in_(select(ranked.c.tmdb_id)))
            .group_by(MovieCast.movie_id)
            .subquery()
        )

        rows = (
            self.db.scalars(
                select(Movie)
                .join(ranked, ranked.c.tmdb_id == Movie.tmdb_id)
                .outerjoin(cast_counts, cast_counts.c.mid == Movie.tmdb_id)
                .options(*_SUMMARY_OPTIONS)
                .order_by(
                    ranked.c.relevance.asc(),
                    func.coalesce(cast_counts.c.n, 0).desc(),
                    Movie.vote_average.desc().nullslast(),
                    Movie.release_date.desc().nullslast(),
                    Movie.tmdb_id.desc(),
                )
                .limit(page_size)
                .offset((page - 1) * page_size)
            )
            .unique()
            .all()
        )
        return list(rows), total

    # ------------ people ------------

    def search_persons(
        self, query: str, *, page: int = 1, page_size: int = 20
    ) -> tuple[list[Person], int]:
        """Search the catalogue's persons (cast & crew) by name.

        Two-pass approach to stay fast on broad queries like "Christopher"
        (tens of thousands of matches): fetch prefix matches first (most
        relevant), then fill with substring matches if needed. No COUNT(*)
        — the frontend doesn't paginate person results.
        """
        q = query.strip()
        q_lower = q.lower()

        # Pass 1: prefix matches ("Nolan ..." comes before "Christopher Nolan")
        prefix = Person.name.ilike(f"{q}%")
        rows = list(self.db.scalars(
            select(Person)
            .where(prefix)
            .order_by(Person.name.asc())
            .limit(page_size)
        ).all())

        if len(rows) < page_size:
            # Pass 2: substring matches (excludes already-found ids)
            existing_ids = [p.tmdb_id for p in rows]
            substring = Person.name.ilike(f"%{q}%")
            remaining = page_size - len(rows)
            more = self.db.scalars(
                select(Person)
                .where(substring, Person.tmdb_id.notin_(existing_ids) if existing_ids else True)
                .order_by(Person.name.asc())
                .limit(remaining)
            ).all()
            rows.extend(more)

        return rows, len(rows)

    def get_person(self, person_id: int) -> Person | None:
        return self.db.get(Person, person_id)

    # ------------ similar (v1: random) ------------

    def random_movies(self, *, limit: int = 10) -> list[Movie]:
        """Random movies from the catalogue (used for the group match list,
        v1). To be replaced by an AI 'common taste' model later."""
        return list(
            self.db.scalars(
                select(Movie)
                .order_by(func.random())
                .limit(limit)
                .options(*_SUMMARY_OPTIONS)
            ).unique()
        )

    def random_similar(self, tmdb_id: int, *, limit: int = 10) -> list[Movie]:
        """V1 of "similar movies": random movies (excluding the current one).
        To be replaced by an AI model later."""
        return list(
            self.db.scalars(
                select(Movie)
                .where(Movie.tmdb_id != tmdb_id)
                .order_by(func.random())
                .limit(limit)
                .options(*_SUMMARY_OPTIONS)
            ).unique()
        )

    def filmography(self, person_id: int, *, limit: int = 100) -> list[Movie]:
        """Movies featuring the person as either cast or crew."""
        cast_ids = select(MovieCast.movie_id).where(
            MovieCast.person_id == person_id
        )
        crew_ids = select(MovieCrew.movie_id).where(
            MovieCrew.person_id == person_id
        )
        movie_ids = cast_ids.union(crew_ids).subquery()

        rows = (
            self.db.scalars(
                select(Movie)
                .where(Movie.tmdb_id.in_(select(movie_ids.c.movie_id)))
                .options(*_SUMMARY_OPTIONS)
                .order_by(
                    Movie.release_date.desc().nullslast(), Movie.tmdb_id.desc()
                )
                .limit(limit)
            )
            .unique()
            .all()
        )
        return list(rows)
