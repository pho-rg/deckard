# recommendations sourced from a user's friends' activity.

import uuid

from sqlalchemy import func, literal, select, union_all
from sqlalchemy.orm import Session, selectinload

from app.models.favorite import Favorite
from app.models.friendship import Friendship, FriendshipStatus
from app.models.genre import Genre
from app.models.movie import Movie
from app.models.rating import Rating
from app.models.watched import WatchedItem
from app.models.watchlist import WatchlistItem

# Eager-load everything `presenter.movie_card` needs to localize a card.
_CARD_OPTIONS = (
    selectinload(Movie.contents),
    selectinload(Movie.genres).selectinload(Genre.contents),
)

# Weights — favorite > high rating > watched > watchlist
_W_FAVORITE = 4
_W_HIGH_RATING = 3
_W_WATCHED = 2
_W_WATCHLIST = 1

# Half-star threshold for "high rating" — 8 = 4.0 stars
_HIGH_RATING_THRESHOLD = 8

# single SQL query as targeted method
class RecommendationRepository:
    def __init__(self, db: Session):
        self.db = db

    def random_unseen(self, user_id: uuid.UUID, *, limit: int = 20) -> list[Movie]:
        """V1 of personal recommendations: random movies the user has not yet
        interacted with. To be replaced by an AI model later."""
        my_seen = union_all(
            select(Favorite.movie_id.label("movie_id")).where(
                Favorite.user_id == user_id
            ),
            select(Rating.movie_id.label("movie_id")).where(
                Rating.user_id == user_id
            ),
            select(WatchedItem.movie_id.label("movie_id")).where(
                WatchedItem.user_id == user_id
            ),
            select(WatchlistItem.movie_id.label("movie_id")).where(
                WatchlistItem.user_id == user_id
            ),
        ).subquery()

        stmt = (
            select(Movie)
            .where(Movie.tmdb_id.notin_(select(my_seen.c.movie_id)))
            .order_by(func.random())
            .limit(limit)
            .options(*_CARD_OPTIONS)
        )
        return list(self.db.scalars(stmt))

    def from_friends(self, user_id: uuid.UUID, *, limit: int = 10) -> list[Movie]:
        friend_ids = (
            select(Friendship.addressee_id)
            .where(
                Friendship.requester_id == user_id,
                Friendship.status == FriendshipStatus.accepted,
            )
            .scalar_subquery()
        )

        # Weighted signals from friends.
        signals = union_all(
            select(
                Favorite.movie_id.label("movie_id"),
                literal(_W_FAVORITE).label("weight"),
            ).where(Favorite.user_id.in_(friend_ids)),
            select(
                Rating.movie_id.label("movie_id"),
                literal(_W_HIGH_RATING).label("weight"),
            ).where(
                Rating.user_id.in_(friend_ids),
                Rating.rating >= _HIGH_RATING_THRESHOLD,
            ),
            select(
                WatchedItem.movie_id.label("movie_id"),
                literal(_W_WATCHED).label("weight"),
            ).where(WatchedItem.user_id.in_(friend_ids)),
            select(
                WatchlistItem.movie_id.label("movie_id"),
                literal(_W_WATCHLIST).label("weight"),
            ).where(WatchlistItem.user_id.in_(friend_ids)),
        ).subquery()

        # Movies the requesting user is already done with — exclude.
        my_seen = union_all(
            select(Favorite.movie_id.label("movie_id")).where(Favorite.user_id == user_id),
            select(Rating.movie_id.label("movie_id")).where(Rating.user_id == user_id),
            select(WatchedItem.movie_id.label("movie_id")).where(WatchedItem.user_id == user_id),
            select(WatchlistItem.movie_id.label("movie_id")).where(WatchlistItem.user_id == user_id),
        ).subquery()

        scored = (
            select(
                signals.c.movie_id,
                func.sum(signals.c.weight).label("score"),
            )
            .group_by(signals.c.movie_id)
            .subquery()
        )

        stmt = (
            select(Movie)
            .join(scored, scored.c.movie_id == Movie.tmdb_id)
            .where(Movie.tmdb_id.notin_(select(my_seen.c.movie_id)))
            .order_by(scored.c.score.desc(), Movie.tmdb_id.asc())
            .limit(limit)
            .options(*_CARD_OPTIONS)
        )

        return list(self.db.scalars(stmt))
