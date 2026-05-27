"""movies enrichment, genres, persons, credits, user lang/region

Revision ID: 0002
Revises: 0001
Create Date: 2026-05-23

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0002"
down_revision: Union[str, None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ---- enrich movies ----
    op.add_column("movies", sa.Column("original_title", sa.String(length=500), nullable=True))
    op.add_column("movies", sa.Column("overview", sa.Text(), nullable=True))
    op.add_column("movies", sa.Column("release_date", sa.Date(), nullable=True))
    op.add_column("movies", sa.Column("runtime", sa.Integer(), nullable=True))
    op.add_column("movies", sa.Column("poster_path", sa.String(length=255), nullable=True))
    op.add_column("movies", sa.Column("backdrop_path", sa.String(length=255), nullable=True))
    op.add_column("movies", sa.Column("original_language", sa.String(length=10), nullable=True))
    op.add_column("movies", sa.Column("vote_average", sa.Numeric(precision=3, scale=1), nullable=True))
    op.add_column(
        "movies",
        sa.Column(
            "last_synced_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )

    # ---- genres ----
    op.create_table(
        "genres",
        sa.Column("tmdb_id", sa.Integer(), autoincrement=False, nullable=False),
        sa.Column("name", sa.String(length=64), nullable=False),
        sa.PrimaryKeyConstraint("tmdb_id"),
    )

    op.create_table(
        "movie_genres",
        sa.Column("movie_id", sa.Integer(), nullable=False),
        sa.Column("genre_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["movie_id"], ["movies.tmdb_id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["genre_id"], ["genres.tmdb_id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("movie_id", "genre_id"),
    )

    # ---- persons ----
    op.create_table(
        "persons",
        sa.Column("tmdb_id", sa.Integer(), autoincrement=False, nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("profile_path", sa.String(length=255), nullable=True),
        sa.PrimaryKeyConstraint("tmdb_id"),
    )

    # ---- movie_cast ----
    op.create_table(
        "movie_cast",
        sa.Column("movie_id", sa.Integer(), nullable=False),
        sa.Column("person_id", sa.Integer(), nullable=False),
        sa.Column("character", sa.String(length=255), nullable=True),
        sa.Column("cast_order", sa.Integer(), server_default="0", nullable=False),
        sa.ForeignKeyConstraint(["movie_id"], ["movies.tmdb_id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["person_id"], ["persons.tmdb_id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("movie_id", "person_id"),
    )

    # ---- movie_crew ----
    op.create_table(
        "movie_crew",
        sa.Column("movie_id", sa.Integer(), nullable=False),
        sa.Column("person_id", sa.Integer(), nullable=False),
        sa.Column("job", sa.String(length=100), nullable=False),
        sa.Column("department", sa.String(length=100), nullable=True),
        sa.ForeignKeyConstraint(["movie_id"], ["movies.tmdb_id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["person_id"], ["persons.tmdb_id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("movie_id", "person_id", "job"),
    )

    # ---- users lang/region ----
    op.add_column(
        "users",
        sa.Column("language", sa.String(length=10), server_default="fr-FR", nullable=False),
    )
    op.add_column(
        "users",
        sa.Column("region", sa.String(length=10), server_default="FR", nullable=False),
    )


def downgrade() -> None:
    op.drop_column("users", "region")
    op.drop_column("users", "language")
    op.drop_table("movie_crew")
    op.drop_table("movie_cast")
    op.drop_table("persons")
    op.drop_table("movie_genres")
    op.drop_table("genres")
    for col in (
        "last_synced_at",
        "vote_average",
        "original_language",
        "backdrop_path",
        "poster_path",
        "runtime",
        "release_date",
        "overview",
        "original_title",
    ):
        op.drop_column("movies", col)
