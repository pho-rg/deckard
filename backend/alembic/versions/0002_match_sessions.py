"""match sessions

Revision ID: 0002
Revises: 0001
Create Date: 2026-06-18 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = '0002'
down_revision: Union[str, None] = '0001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'match_sessions',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('code', sa.String(length=8), nullable=False),
        sa.Column('host_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            'status',
            sa.Enum('not_started', 'in_progress', 'finished', name='match_status'),
            nullable=False,
        ),
        sa.Column('choices_received', sa.Integer(), server_default='0', nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['host_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_match_sessions_code', 'match_sessions', ['code'], unique=True)

    op.create_table(
        'match_participants',
        sa.Column('session_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('joined_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('has_submitted', sa.Boolean(), server_default='false', nullable=False),
        sa.ForeignKeyConstraint(['session_id'], ['match_sessions.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('session_id', 'user_id'),
    )

    op.create_table(
        'match_movies',
        sa.Column('session_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('movie_id', sa.Integer(), nullable=False),
        sa.Column('position', sa.Integer(), server_default='0', nullable=False),
        sa.Column('eliminated', sa.Boolean(), server_default='false', nullable=False),
        sa.ForeignKeyConstraint(['session_id'], ['match_sessions.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['movie_id'], ['movies.tmdb_id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('session_id', 'movie_id'),
    )


def downgrade() -> None:
    op.drop_table('match_movies')
    op.drop_table('match_participants')
    op.drop_index('ix_match_sessions_code', table_name='match_sessions')
    op.drop_table('match_sessions')
    sa.Enum(name='match_status').drop(op.get_bind(), checkfirst=True)
