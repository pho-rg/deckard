# Syncrhonize TMDB movie genres
# Usage: docker compose exec api python -m app.scripts.sync_genres

from __future__ import annotations

import logging
import sys

from sqlalchemy.dialects.postgresql import insert

from app.db import SessionLocal
from app.integrations.tmdb import TMDBClient, TMDBError
from app.models.genre import Genre

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger("sync_genres")


def sync_genres() -> int:
    with TMDBClient() as tmdb:
        payload = tmdb.list_genres()

    genres = payload.get("genres", [])
    if not genres:
        logger.warning("TMDB returned no genres — nothing to sync")
        return 0

    stmt = insert(Genre).values(
        [{"tmdb_id": g["id"], "name": g["name"]} for g in genres]
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=[Genre.tmdb_id],
        set_={"name": stmt.excluded.name},
    )

    with SessionLocal() as db:
        db.execute(stmt)
        db.commit()

    logger.info("Synced %d genres", len(genres))
    return len(genres)


if __name__ == "__main__":
    try:
        sync_genres()
    except TMDBError as exc:
        logger.error("TMDB error: %s", exc)
        sys.exit(1)
