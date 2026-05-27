import uuid

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.models.friendship import Friendship, FriendshipStatus
from app.models.user import User


class FriendshipRepository:
    def __init__(self, db: Session):
        self.db = db

    def get(self, requester_id: uuid.UUID, addressee_id: uuid.UUID) -> Friendship | None:
        return self.db.scalar(
            select(Friendship).where(
                Friendship.requester_id == requester_id,
                Friendship.addressee_id == addressee_id,
            )
        )

    def is_accepted(self, requester_id: uuid.UUID, addressee_id: uuid.UUID) -> bool:
        # True iff requester has addressee as an accepted friend (asymmetric)
        return self.db.scalar(
            select(Friendship.requester_id)
            .where(
                Friendship.requester_id == requester_id,
                Friendship.addressee_id == addressee_id,
                Friendship.status == FriendshipStatus.accepted,
            )
            .limit(1)
        ) is not None

    def list_friends(self, user_id: uuid.UUID) -> list[User]:
        # Users that user_id befriended (i.e. requester=user_id, accepted)
        return list(
            self.db.scalars(
                select(User)
                .join(Friendship, Friendship.addressee_id == User.id)
                .where(
                    Friendship.requester_id == user_id,
                    Friendship.status == FriendshipStatus.accepted,
                )
                .order_by(User.username)
            )
        )

    def list_pending_incoming(self, user_id: uuid.UUID) -> list[Friendship]:
        return list(
            self.db.scalars(
                select(Friendship)
                .where(
                    Friendship.addressee_id == user_id,
                    Friendship.status == FriendshipStatus.pending,
                )
                .order_by(Friendship.created_at.desc())
            )
        )

    def list_pending_outgoing(self, user_id: uuid.UUID) -> list[Friendship]:
        return list(
            self.db.scalars(
                select(Friendship)
                .where(
                    Friendship.requester_id == user_id,
                    Friendship.status == FriendshipStatus.pending,
                )
                .order_by(Friendship.created_at.desc())
            )
        )

    def create(
        self, requester_id: uuid.UUID, addressee_id: uuid.UUID
    ) -> Friendship:
        row = Friendship(
            requester_id=requester_id,
            addressee_id=addressee_id,
            status=FriendshipStatus.pending,
        )
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        return row

    def set_status(
        self,
        requester_id: uuid.UUID,
        addressee_id: uuid.UUID,
        status: FriendshipStatus,
    ) -> Friendship | None:
        row = self.get(requester_id, addressee_id)
        if row is None:
            return None
        row.status = status
        self.db.commit()
        self.db.refresh(row)
        return row

    def delete(self, requester_id: uuid.UUID, addressee_id: uuid.UUID) -> bool:
        result = self.db.execute(
            delete(Friendship).where(
                Friendship.requester_id == requester_id,
                Friendship.addressee_id == addressee_id,
            )
        )
        self.db.commit()
        return result.rowcount > 0
