"""index ratings.movie_id for fast review queries

Revision ID: 0004
Revises: 0003
Create Date: 2026-07-11 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op


revision: str = '0004'
down_revision: Union[str, None] = '0003'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # The composite PK is (user_id, movie_id) so queries filtering only by
    # movie_id (stats_for_movie, list_reviews_for_movie) do a seq-scan.
    op.execute(
        'CREATE INDEX IF NOT EXISTS ix_ratings_movie_id ON ratings (movie_id)'
    )


def downgrade() -> None:
    op.execute('DROP INDEX IF EXISTS ix_ratings_movie_id')
