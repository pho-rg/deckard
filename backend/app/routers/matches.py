import uuid

from fastapi import APIRouter, status

from app.deps import CurrentUser, DbSession
from app.schemas.match import MatchChoicesIn, MatchJoinIn, MatchSessionOut
from app.services.match_service import MatchService

router = APIRouter(prefix="/matches", tags=["matches"])


# ---- static paths first (before /{session_id}) ----


@router.post(
    "", response_model=MatchSessionOut, status_code=status.HTTP_201_CREATED
)
def create_match(db: DbSession, current_user: CurrentUser):
    return MatchService(db).create(current_user)


@router.post("/join", response_model=MatchSessionOut)
def join_match(
    payload: MatchJoinIn, db: DbSession, current_user: CurrentUser
):
    return MatchService(db).join(current_user, payload.code)


@router.post("/cleanup")
def cleanup_matches(db: DbSession, current_user: CurrentUser):
    # Idle waiting rooms + finished sessions older than 1h. Meant to be called
    # periodically by the client.
    deleted = MatchService(db).cleanup()
    return {"deleted": deleted}


# ---- per-session ----


@router.get("/{session_id}", response_model=MatchSessionOut)
def get_match(
    session_id: uuid.UUID, db: DbSession, current_user: CurrentUser
):
    return MatchService(db).get(current_user, session_id)


@router.post("/{session_id}/start", response_model=MatchSessionOut)
def start_match(
    session_id: uuid.UUID, db: DbSession, current_user: CurrentUser
):
    return MatchService(db).start(current_user, session_id)


@router.post("/{session_id}/relaunch", response_model=MatchSessionOut)
def relaunch_match(
    session_id: uuid.UUID, db: DbSession, current_user: CurrentUser
):
    return MatchService(db).relaunch(current_user, session_id)


@router.post("/{session_id}/choices", response_model=MatchSessionOut)
def submit_choices(
    session_id: uuid.UUID,
    payload: MatchChoicesIn,
    db: DbSession,
    current_user: CurrentUser,
):
    return MatchService(db).submit_choices(
        current_user, session_id, payload.rejected_ids
    )


@router.post("/{session_id}/leave", response_model=MatchSessionOut | None)
def leave_match(
    session_id: uuid.UUID, db: DbSession, current_user: CurrentUser
):
    # Removes the caller from the session (lobby, voting or finished). Returns
    # null if that was the last participant (the session gets deleted).
    return MatchService(db).leave(current_user, session_id)


@router.delete("/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_match(
    session_id: uuid.UUID, db: DbSession, current_user: CurrentUser
):
    MatchService(db).delete(current_user, session_id)
