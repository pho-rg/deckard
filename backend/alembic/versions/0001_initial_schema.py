"""initial schema

Revision ID: 903230f947fc
Revises: 
Create Date: 2026-05-28 13:33:27.948234

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '0001'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table('genres',
    sa.Column('tmdb_id', sa.Integer(), autoincrement=False, nullable=False),
    sa.PrimaryKeyConstraint('tmdb_id')
    )

    op.create_table('genre_content',
    sa.Column('tmdb_id', sa.Integer(), autoincrement=False, nullable=False),
    sa.Column('language_iso', sa.String(length=2), nullable=False),
    sa.Column('name', sa.String(length=64), nullable=False),
    sa.ForeignKeyConstraint(['tmdb_id'], ['genres.tmdb_id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('tmdb_id', 'language_iso')
    )

    op.create_table('movies',
    sa.Column('tmdb_id', sa.Integer(), autoincrement=False, nullable=False),
    sa.Column('imdb_id', sa.String(length=32), autoincrement=False, nullable=True),
    sa.Column('original_title', sa.String(length=500), nullable=True),
    sa.Column('release_date', sa.Date(), nullable=True),
    sa.Column('runtime', sa.Integer(), nullable=True),
    sa.Column('poster_path', sa.String(length=255), nullable=True),
    sa.Column('backdrop_path', sa.String(length=255), nullable=True),
    sa.Column('original_language', sa.String(length=10), nullable=True),
    sa.Column('vote_average', sa.Numeric(precision=3, scale=1), nullable=True),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('status', sa.Enum('released', 'not_released', name='movie_status')),
    sa.PrimaryKeyConstraint('tmdb_id')
    )

    op.create_table('movie_content',
    sa.Column('tmdb_id', sa.Integer(), autoincrement=False, nullable=False),
    sa.Column('language_iso', sa.String(length=2), nullable=False),
    sa.Column('title', sa.String(length=500), nullable=False),
    sa.Column('overview', sa.Text(), nullable=True),
    sa.Column('tag_line', sa.Text(), nullable=True),
    sa.ForeignKeyConstraint(['tmdb_id'], ['movies.tmdb_id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('tmdb_id', 'language_iso')
    )

    op.create_table('video',
    sa.Column('tmdb_id', sa.Integer(), autoincrement=False, nullable=False),
    sa.Column('language_iso', sa.String(length=2), nullable=False),
    sa.Column('youtube_key', sa.String(length=500), nullable=False),
    sa.ForeignKeyConstraint(['tmdb_id'], ['movies.tmdb_id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('tmdb_id', 'language_iso')
    )

    # Embedding par film pour le modèle IA (similarité content-based).
    # vector = float array natif Postgres (REAL[]), dimension libre.
    op.create_table('movie_vector',
    sa.Column('tmdb_id', sa.Integer(), autoincrement=False, nullable=False),
    sa.Column('vector', sa.ARRAY(sa.REAL()), nullable=False),
    sa.ForeignKeyConstraint(['tmdb_id'], ['movies.tmdb_id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('tmdb_id')
    )

    op.create_table('persons',
    sa.Column('tmdb_id', sa.Integer(), autoincrement=False, nullable=False),
    sa.Column('imdb_id', sa.String(length=32), autoincrement=False, nullable=True),
    sa.Column('birthday', sa.Date(), nullable=True),
    sa.Column('deathday', sa.Date(), nullable=True),
    sa.Column('gender', sa.Integer(), nullable=True),
    sa.Column('known_for_department', sa.Text(), nullable=True),
    sa.Column('profile_path', sa.String(length=255), nullable=True),
    sa.PrimaryKeyConstraint('tmdb_id')
    )

    op.create_table('person_content',
    sa.Column('tmdb_id', sa.Integer(), autoincrement=False, nullable=False),
    sa.Column('language_iso', sa.String(length=2), nullable=False),
    sa.Column('biography', sa.Text(), nullable=True),
    sa.Column('place_of_birth', sa.Text(), nullable=True),
    sa.Column('name', sa.String(length=255), nullable=False),
    sa.ForeignKeyConstraint(['tmdb_id'], ['persons.tmdb_id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('tmdb_id', 'language_iso')
    )

    op.create_table('users',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('email', sa.String(length=255), nullable=False),
    sa.Column('username', sa.String(length=64), nullable=False),
    sa.Column('password_hash', sa.String(length=255), nullable=False),
    sa.Column('language', sa.String(length=10), server_default='fr-FR', nullable=False),
    sa.Column('region', sa.String(length=10), server_default='FR', nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)
    op.create_index(op.f('ix_users_username'), 'users', ['username'], unique=True)
    op.create_table('favorites',
    sa.Column('user_id', sa.UUID(), nullable=False),
    sa.Column('movie_id', sa.Integer(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['movie_id'], ['movies.tmdb_id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('user_id', 'movie_id')
    )
    op.create_table('featured_movies',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('movie_id', sa.Integer(), nullable=False),
    sa.Column('starts_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('ends_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['movie_id'], ['movies.tmdb_id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_table('friendships',
    sa.Column('requester_id', sa.UUID(), nullable=False),
    sa.Column('addressee_id', sa.UUID(), nullable=False),
    sa.Column('status', sa.Enum('pending', 'accepted', 'rejected', 'blocked', name='friendship_status'), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.CheckConstraint('requester_id <> addressee_id', name='ck_no_self_friendship'),
    sa.ForeignKeyConstraint(['addressee_id'], ['users.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['requester_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('requester_id', 'addressee_id')
    )
    op.create_table('movie_cast',
    sa.Column('movie_id', sa.Integer(), nullable=False),
    sa.Column('person_id', sa.Integer(), nullable=False),
    sa.Column('character', sa.String(length=255), nullable=True),
    sa.Column('cast_order', sa.Integer(), server_default='0', nullable=False),
    sa.ForeignKeyConstraint(['movie_id'], ['movies.tmdb_id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['person_id'], ['persons.tmdb_id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('movie_id', 'person_id', 'cast_order')
    )
    op.create_table('movie_crew',
    sa.Column('movie_id', sa.Integer(), nullable=False),
    sa.Column('person_id', sa.Integer(), nullable=False),
    sa.Column('job', sa.String(length=100), nullable=False),
    sa.Column('department', sa.String(length=100), nullable=True),
    sa.ForeignKeyConstraint(['movie_id'], ['movies.tmdb_id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['person_id'], ['persons.tmdb_id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('movie_id', 'person_id', 'job')
    )
    op.create_table('movie_genres',
    sa.Column('movie_id', sa.Integer(), nullable=False),
    sa.Column('genre_id', sa.Integer(), nullable=False),
    sa.ForeignKeyConstraint(['genre_id'], ['genres.tmdb_id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['movie_id'], ['movies.tmdb_id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('movie_id', 'genre_id')
    )
    op.create_table('ratings',
    sa.Column('user_id', sa.UUID(), nullable=False),
    sa.Column('movie_id', sa.Integer(), nullable=False),
    sa.Column('rating', sa.Integer(), nullable=False),
    sa.Column('review', sa.Text(), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.CheckConstraint('rating >= 0 AND rating <= 10', name='ck_ratings_range'),
    sa.ForeignKeyConstraint(['movie_id'], ['movies.tmdb_id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('user_id', 'movie_id')
    )
    op.create_table('refresh_tokens',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('user_id', sa.UUID(), nullable=False),
    sa.Column('token_hash', sa.String(length=255), nullable=False),
    sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('revoked_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_refresh_tokens_token_hash'), 'refresh_tokens', ['token_hash'], unique=True)
    op.create_index(op.f('ix_refresh_tokens_user_id'), 'refresh_tokens', ['user_id'], unique=False)
    op.create_table('watched',
    sa.Column('user_id', sa.UUID(), nullable=False),
    sa.Column('movie_id', sa.Integer(), nullable=False),
    sa.Column('watched_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['movie_id'], ['movies.tmdb_id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('user_id', 'movie_id')
    )
    op.create_table('watchlist',
    sa.Column('user_id', sa.UUID(), nullable=False),
    sa.Column('movie_id', sa.Integer(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['movie_id'], ['movies.tmdb_id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('user_id', 'movie_id')
    )

def downgrade() -> None:
    op.drop_table('watchlist')
    op.drop_table('watched')
    op.drop_index(op.f('ix_refresh_tokens_user_id'), table_name='refresh_tokens')
    op.drop_index(op.f('ix_refresh_tokens_token_hash'), table_name='refresh_tokens')
    op.drop_table('refresh_tokens')
    op.drop_table('ratings')
    op.drop_table('movie_genres')
    op.drop_table('movie_crew')
    op.drop_table('movie_cast')
    op.drop_table('friendships')
    op.drop_table('featured_movies')
    op.drop_table('favorites')
    op.drop_index(op.f('ix_users_username'), table_name='users')
    op.drop_index(op.f('ix_users_email'), table_name='users')
    op.drop_table('users')
    op.drop_table('person_content')
    op.drop_table('persons')
    op.drop_table('movie_vector')
    op.drop_table('video')
    op.drop_table('movie_content')
    op.drop_table('movies')
    op.drop_table('genre_content')
    op.drop_table('genres')
    sa.Enum(name='friendship_status').drop(op.get_bind(), checkfirst=True)
    sa.Enum(name='movie_status').drop(op.get_bind(), checkfirst=True)
