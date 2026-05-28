# Sync TMDB movie genres into genres + genre_content.
# Usage: docker compose exec api python -m app.scripts.sync_genres [language]
#   e.g. python -m app.scripts.sync_genres fr-FR

from __future__ import annotations

import logging
import sys

from sqlalchemy.dialects.postgresql import insert

from app.db import SessionLocal
from app.integrations.tmdb import TMDBClient, TMDBError
from app.models.genre import Genre
from app.models.genre_content import GenreContent
from app.services.localization import to_iso2

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger("sync_genres")


def sync_genres(language: str = "fr-FR") -> int:
    iso = to_iso2(language)
    with TMDBClient() as tmdb:
        payload = tmdb.list_genres(language=language)

    genres = payload.get("genres", [])
    if not genres:
        logger.warning("TMDB returned no genres — nothing to sync")
        return 0

    with SessionLocal() as db:
        db.execute(
            insert(Genre)
            .values([{"tmdb_id": g["id"]} for g in genres])
            .on_conflict_do_nothing(index_elements=[Genre.tmdb_id])
        )
        gc = insert(GenreContent).values(
            [
                {"tmdb_id": g["id"], "language_iso": iso, "name": g["name"]}
                for g in genres
            ]
        )
        gc = gc.on_conflict_do_update(
            index_elements=[GenreContent.tmdb_id, GenreContent.language_iso],
            set_={"name": gc.excluded.name},
        )
        db.execute(gc)
        db.commit()

    logger.info("Synced %d genres (%s)", len(genres), iso)
    return len(genres)


if __name__ == "__main__":
    lang = sys.argv[1] if len(sys.argv) > 1 else "fr-FR"
    try:
        sync_genres(lang)
    except TMDBError as exc:
        logger.error("TMDB error: %s", exc)
        sys.exit(1)
