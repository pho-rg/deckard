"""search trigram indexes

Revision ID: 0003
Revises: 0002
Create Date: 2026-07-09 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op


revision: str = '0003'
down_revision: Union[str, None] = '0002'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # La recherche catalogue (MovieRepository.search) filtre avec
    # ILIKE '%query%' sur ces deux colonnes. Un index btree classique ne sert
    # à rien pour un pattern avec joker en tête ('%...') — sans index adapté,
    # chaque recherche fait un scan séquentiel complet des deux tables, ce
    # qui devient très lent (voire perçu comme un chargement infini côté
    # app) à mesure que le catalogue grossit.
    op.execute('CREATE EXTENSION IF NOT EXISTS pg_trgm')
    op.execute(
        'CREATE INDEX ix_movie_content_title_trgm ON movie_content '
        'USING gin (title gin_trgm_ops)'
    )
    op.execute(
        'CREATE INDEX ix_movies_original_title_trgm ON movies '
        'USING gin (original_title gin_trgm_ops)'
    )


def downgrade() -> None:
    op.execute('DROP INDEX IF EXISTS ix_movies_original_title_trgm')
    op.execute('DROP INDEX IF EXISTS ix_movie_content_title_trgm')
