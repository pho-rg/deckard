# Asymetric friendship allowed

from __future__ import annotations

import uuid

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.friendship import Friendship, FriendshipStatus
from app.models.user import User
from app.repositories.friendship_repository import FriendshipRepository
from app.repositories.user_repository import UserRepository


class FriendshipService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = FriendshipRepository(db)
        self.users = UserRepository(db)

    # ------------ mutations ------------

    def send_request(self, sender: User, target_username: str) -> Friendship:
        target = self.users.get_by_username(target_username)
        if target is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
            )
        if target.id == sender.id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot befriend yourself",
            )

        existing = self.repo.get(sender.id, target.id)
        if existing:
            if existing.status == FriendshipStatus.pending:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Friend request already pending",
                )
            if existing.status == FriendshipStatus.accepted:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="User is already your friend",
                )
            if existing.status == FriendshipStatus.blocked:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Cannot send a request to this user",
                )
            # rejected: allow re-trying by flipping back to pending
            existing.status = FriendshipStatus.pending
            self.db.commit()
            self.db.refresh(existing)
            return existing

        return self.repo.create(sender.id, target.id)

    def accept_request(
        self, addressee: User, requester_id: uuid.UUID
    ) -> Friendship:
        row = self.repo.get(requester_id, addressee.id)
        if row is None or row.status != FriendshipStatus.pending:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No pending request from this user",
            )
        return self.repo.set_status(
            requester_id, addressee.id, FriendshipStatus.accepted
        )

    def reject_request(
        self, addressee: User, requester_id: uuid.UUID
    ) -> Friendship:
        row = self.repo.get(requester_id, addressee.id)
        if row is None or row.status != FriendshipStatus.pending:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No pending request from this user",
            )
        return self.repo.set_status(
            requester_id, addressee.id, FriendshipStatus.rejected
        )

    def remove_outgoing(self, requester: User, addressee_id: uuid.UUID) -> None:
        # Works for both cancel pending and unfriend — deletes the row I'm the requester of
        self.repo.delete(requester.id, addressee_id)

    # ------------ reads ------------

    def list_friends(self, user: User) -> list[User]:
        return self.repo.list_friends(user.id)

    def list_pending(self, user: User) -> dict:
        return {
            "incoming": self.repo.list_pending_incoming(user.id),
            "outgoing": self.repo.list_pending_outgoing(user.id),
        }

    # ------------ gating ------------

    def assert_can_view_profile(
        self, viewer: User, target_id: uuid.UUID
    ) -> None:
        if viewer.id == target_id:
            return
        if not self.repo.is_accepted(viewer.id, target_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only view profiles of your friends",
            )
