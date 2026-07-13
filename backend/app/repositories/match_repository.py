import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import delete, or_, select, update
from sqlalchemy.orm import Session, joinedload, selectinload

from app.models.match import (
    MatchMovie,
    MatchParticipant,
    MatchSession,
    MatchStatus,
)
from app.models.movie import Movie

_FULL = (
    selectinload(MatchSession.participants).joinedload(MatchParticipant.user),
    selectinload(MatchSession.movies)
    .joinedload(MatchMovie.movie)
    .selectinload(Movie.contents),
)


class MatchRepository:
    def __init__(self, db: Session):
        self.db = db

    # ---- reads ----

    def get(self, session_id: uuid.UUID) -> MatchSession | None:
        return self.db.scalar(
            select(MatchSession)
            .where(MatchSession.id == session_id)
            .options(*_FULL)
        )

    def get_by_code(self, code: str) -> MatchSession | None:
        return self.db.scalar(
            select(MatchSession)
            .where(MatchSession.code == code)
            .options(*_FULL)
        )

    def code_exists(self, code: str) -> bool:
        return self.db.scalar(
            select(MatchSession.id).where(MatchSession.code == code).limit(1)
        ) is not None

    def is_participant(self, session_id: uuid.UUID, user_id: uuid.UUID) -> bool:
        return self.db.scalar(
            select(MatchParticipant.user_id)
            .where(
                MatchParticipant.session_id == session_id,
                MatchParticipant.user_id == user_id,
            )
            .limit(1)
        ) is not None

    def participant_count(self, session_id: uuid.UUID) -> int:
        return len(
            self.db.scalars(
                select(MatchParticipant.user_id).where(
                    MatchParticipant.session_id == session_id
                )
            ).all()
        )

    # ---- writes ----

    def create_session(
        self, *, host_id: uuid.UUID, code: str
    ) -> MatchSession:
        session = MatchSession(
            code=code, host_id=host_id, status=MatchStatus.not_started
        )
        self.db.add(session)
        self.db.flush()
        self.db.add(
            MatchParticipant(session_id=session.id, user_id=host_id)
        )
        self.db.commit()
        return session

    def add_participant(
        self, session_id: uuid.UUID, user_id: uuid.UUID
    ) -> None:
        if not self.is_participant(session_id, user_id):
            self.db.add(
                MatchParticipant(session_id=session_id, user_id=user_id)
            )
            self.db.commit()

    def set_movies(
        self, session_id: uuid.UUID, movie_ids: list[int]
    ) -> None:
        # Replace any previous voting list with a fresh one.
        self.db.execute(
            delete(MatchMovie).where(MatchMovie.session_id == session_id)
        )
        for position, movie_id in enumerate(movie_ids):
            self.db.add(
                MatchMovie(
                    session_id=session_id,
                    movie_id=movie_id,
                    position=position,
                )
            )
        self.db.commit()

    def eliminate_movies(
        self, session_id: uuid.UUID, movie_ids: list[int]
    ) -> None:
        if not movie_ids:
            return
        self.db.execute(
            update(MatchMovie)
            .where(
                MatchMovie.session_id == session_id,
                MatchMovie.movie_id.in_(movie_ids),
            )
            .values(eliminated=True)
        )
        self.db.commit()

    def mark_submitted(
        self, session_id: uuid.UUID, user_id: uuid.UUID
    ) -> None:
        self.db.execute(
            update(MatchParticipant)
            .where(
                MatchParticipant.session_id == session_id,
                MatchParticipant.user_id == user_id,
            )
            .values(has_submitted=True)
        )
        self.db.commit()

    def reset_run(self, session_id: uuid.UUID) -> None:
        # New voting run: clear submissions + eliminations + counter.
        self.db.execute(
            update(MatchParticipant)
            .where(MatchParticipant.session_id == session_id)
            .values(has_submitted=False)
        )
        self.db.execute(
            update(MatchMovie)
            .where(MatchMovie.session_id == session_id)
            .values(eliminated=False)
        )
        self.db.execute(
            update(MatchSession)
            .where(MatchSession.id == session_id)
            .values(choices_received=0)
        )
        self.db.commit()

    def increment_choices(self, session_id: uuid.UUID) -> int:
        # Returns the post-increment count straight from the DB — the caller
        # needs the authoritative value to decide whether everyone has voted,
        # and SQLAlchemy's implicit session-sync on bulk updates can already
        # have mutated any in-memory MatchSession.choices_received by the time
        # this returns (would otherwise double-count).
        new_value = self.db.scalar(
            update(MatchSession)
            .where(MatchSession.id == session_id)
            .values(choices_received=MatchSession.choices_received + 1)
            .returning(MatchSession.choices_received)
        )
        self.db.commit()
        return new_value

    def set_status(
        self, session_id: uuid.UUID, status: MatchStatus
    ) -> None:
        self.db.execute(
            update(MatchSession)
            .where(MatchSession.id == session_id)
            .values(status=status)
        )
        self.db.commit()

    def delete(self, session_id: uuid.UUID) -> None:
        self.db.execute(
            delete(MatchSession).where(MatchSession.id == session_id)
        )
        self.db.commit()

    def delete_stale(self, *, max_age_minutes: int = 60) -> int:
        """Remove sessions that have been idle too long: never-started waiting
        rooms and already-finished sessions older than the cutoff."""
        cutoff = datetime.now(timezone.utc) - timedelta(minutes=max_age_minutes)
        result = self.db.execute(
            delete(MatchSession).where(
                or_(
                    MatchSession.status == MatchStatus.not_started,
                    MatchSession.status == MatchStatus.finished,
                ),
                MatchSession.updated_at < cutoff,
            )
        )
        self.db.commit()
        return result.rowcount
