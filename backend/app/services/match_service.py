from __future__ import annotations

import random
import uuid

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.match import MatchSession, MatchStatus
from app.models.user import User
from app.repositories.match_repository import MatchRepository
from app.repositories.movie_repository import MovieRepository
from app.schemas.friend import UserPublicOut
from app.schemas.match import MatchSessionOut
from app.services import presenter
from app.services.localization import to_iso2

# Unambiguous alphabet (no O/0, I/1) for human-friendly join codes.
_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
_CODE_LEN = 6
_MATCH_MOVIE_COUNT = 10


class MatchService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = MatchRepository(db)
        self.movies = MovieRepository(db)

    # ---- public API ----

    def create(self, host: User) -> MatchSessionOut:
        code = self._generate_code()
        session = self.repo.create_session(host_id=host.id, code=code)
        return self._present(self.repo.get(session.id), host)

    def join(self, user: User, code: str) -> MatchSessionOut:
        session = self.repo.get_by_code(code.strip().upper())
        if session is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Match not found")
        if session.status != MatchStatus.not_started:
            raise HTTPException(
                status.HTTP_409_CONFLICT, "This match has already started"
            )
        self.repo.add_participant(session.id, user.id)
        return self._present(self.repo.get(session.id), user)

    def get(self, user: User, session_id: uuid.UUID) -> MatchSessionOut:
        session = self._require_participant(session_id, user)
        return self._present(session, user)

    def start(self, user: User, session_id: uuid.UUID) -> MatchSessionOut:
        session = self._require_session(session_id)
        self._require_host(session, user)
        if session.status != MatchStatus.not_started:
            raise HTTPException(
                status.HTTP_409_CONFLICT, "Match has already been started"
            )
        self._new_run(session_id)
        return self._present(self.repo.get(session_id), user)

    def relaunch(self, user: User, session_id: uuid.UUID) -> MatchSessionOut:
        session = self._require_session(session_id)
        self._require_host(session, user)
        if session.status != MatchStatus.finished:
            raise HTTPException(
                status.HTTP_409_CONFLICT, "Match is not finished"
            )
        self._new_run(session_id)
        return self._present(self.repo.get(session_id), user)

    def submit_choices(
        self, user: User, session_id: uuid.UUID, rejected_ids: list[int]
    ) -> MatchSessionOut:
        session = self._require_participant(session_id, user)
        if session.status != MatchStatus.in_progress:
            raise HTTPException(
                status.HTTP_409_CONFLICT, "Match is not in the voting phase"
            )
        participant = next(
            (p for p in session.participants if p.user_id == user.id), None
        )
        if participant is not None and participant.has_submitted:
            raise HTTPException(
                status.HTTP_409_CONFLICT, "Choices already submitted"
            )

        # Eliminate the rejected movies that actually belong to this session.
        valid_ids = {m.movie_id for m in session.movies}
        to_eliminate = [i for i in rejected_ids if i in valid_ids]
        self.repo.eliminate_movies(session_id, to_eliminate)
        self.repo.mark_submitted(session_id, user.id)
        self.repo.increment_choices(session_id)

        # Everyone has voted → finish the session.
        total = len(session.participants)
        if session.choices_received + 1 >= total:
            self.repo.set_status(session_id, MatchStatus.finished)

        return self._present(self.repo.get(session_id), user)

    def delete(self, user: User, session_id: uuid.UUID) -> None:
        session = self._require_session(session_id)
        self._require_host(session, user)
        self.repo.delete(session_id)

    def cleanup(self) -> int:
        # Purge idle waiting rooms and finished sessions older than 1h.
        return self.repo.delete_stale(max_age_minutes=60)

    # ---- internals ----

    def _new_run(self, session_id: uuid.UUID) -> None:
        # V1: random movies as the "common recommendation". An AI model that
        # blends the participants' tastes will replace random_movies later.
        movies = self.movies.random_movies(limit=_MATCH_MOVIE_COUNT)
        self.repo.set_movies(session_id, [m.tmdb_id for m in movies])
        self.repo.reset_run(session_id)
        self.repo.set_status(session_id, MatchStatus.in_progress)

    def _generate_code(self) -> str:
        for _ in range(20):
            code = "".join(random.choices(_CODE_ALPHABET, k=_CODE_LEN))
            if not self.repo.code_exists(code):
                return code
        raise HTTPException(
            status.HTTP_500_INTERNAL_SERVER_ERROR,
            "Could not allocate a match code",
        )

    def _require_session(self, session_id: uuid.UUID) -> MatchSession:
        session = self.repo.get(session_id)
        if session is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Match not found")
        return session

    def _require_participant(
        self, session_id: uuid.UUID, user: User
    ) -> MatchSession:
        session = self._require_session(session_id)
        if not any(p.user_id == user.id for p in session.participants):
            raise HTTPException(
                status.HTTP_403_FORBIDDEN, "You are not in this match"
            )
        return session

    def _require_host(self, session: MatchSession, user: User) -> None:
        if session.host_id != user.id:
            raise HTTPException(
                status.HTTP_403_FORBIDDEN,
                "Only the match host can do this",
            )

    def _present(self, session: MatchSession, user: User) -> MatchSessionOut:
        iso = to_iso2(user.language)
        ordered = sorted(session.movies, key=lambda m: m.position)

        # The voting list is hidden until the match starts ("vide tant que tout
        # le monde n'est pas là").
        if session.status == MatchStatus.not_started:
            movies = []
        else:
            movies = [presenter.movie_card(m.movie, iso) for m in ordered]

        if session.status == MatchStatus.finished:
            result = [
                presenter.movie_card(m.movie, iso)
                for m in ordered
                if not m.eliminated
            ]
        else:
            result = []

        participants = [
            UserPublicOut(id=p.user.id, username=p.user.username)
            for p in session.participants
        ]

        return MatchSessionOut(
            id=session.id,
            code=session.code,
            status=session.status,
            created_at=session.created_at,
            host=UserPublicOut(
                id=session.host.id, username=session.host.username
            ),
            participants=participants,
            participant_count=len(participants),
            choices_received=session.choices_received,
            movies=movies,
            result=result,
        )
