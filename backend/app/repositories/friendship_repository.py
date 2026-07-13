import uuid

from sqlalchemy import and_, delete, or_, select, union_all
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

    def is_accepted(self, user_a: uuid.UUID, user_b: uuid.UUID) -> bool:
        # Accepted friendship is mutual regardless of who originally requested it.
        return self.db.scalar(
            select(Friendship.status)
            .where(
                or_(
                    and_(
                        Friendship.requester_id == user_a,
                        Friendship.addressee_id == user_b,
                    ),
                    and_(
                        Friendship.requester_id == user_b,
                        Friendship.addressee_id == user_a,
                    ),
                ),
                Friendship.status == FriendshipStatus.accepted,
            )
            .limit(1)
        ) is not None

    def friend_ids_subquery(self, user_id: uuid.UUID):
        # A friendship row only records who originally sent the request, but
        # once accepted the relationship is mutual — resolve the other side
        # from either column.
        return union_all(
            select(Friendship.addressee_id.label("friend_id")).where(
                Friendship.requester_id == user_id,
                Friendship.status == FriendshipStatus.accepted,
            ),
            select(Friendship.requester_id.label("friend_id")).where(
                Friendship.addressee_id == user_id,
                Friendship.status == FriendshipStatus.accepted,
            ),
        ).subquery()

    def list_friends(self, user_id: uuid.UUID) -> list[User]:
        friend_ids = self.friend_ids_subquery(user_id)
        return list(
            self.db.scalars(
                select(User)
                .join(friend_ids, friend_ids.c.friend_id == User.id)
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
