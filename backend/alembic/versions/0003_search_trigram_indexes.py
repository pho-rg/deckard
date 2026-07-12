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
    # ILIKE '%query%' sur movie_content.title. Un index btree classique ne
    # sert à rien pour un pattern avec joker en tête ('%...') — sans index
    # adapté, chaque recherche fait un scan séquentiel complet, ce qui
    # devient très lent (chargement infini côté app) quand le catalogue
    # grossit. Le GIN trigram résout ça.
    op.execute('CREATE EXTENSION IF NOT EXISTS pg_trgm')
    op.execute(
        'CREATE INDEX IF NOT EXISTS ix_movie_content_title_trgm ON movie_content '
        'USING gin (title gin_trgm_ops)'
    )
    op.execute(
        'CREATE INDEX IF NOT EXISTS ix_persons_name_trgm ON persons '
        'USING gin (name gin_trgm_ops)'
    )
    # Nettoyage : l'ancien index sur movies.original_title n'est plus
    # utilisé (la recherche passe uniquement par movie_content.title).
    op.execute('DROP INDEX IF EXISTS ix_movies_original_title_trgm')


def downgrade() -> None:
    op.execute('DROP INDEX IF EXISTS ix_persons_name_trgm')
    op.execute('DROP INDEX IF EXISTS ix_movie_content_title_trgm')
    # Restaurer l'ancien index si on rollback.
    op.execute('CREATE EXTENSION IF NOT EXISTS pg_trgm')
    op.execute(
        'CREATE INDEX IF NOT EXISTS ix_movies_original_title_trgm ON movies '
        'USING gin (original_title gin_trgm_ops)'
    )
