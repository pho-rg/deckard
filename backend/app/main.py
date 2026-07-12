import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.config import settings
from app.db import engine
from app.routers import (
    auth,
    friends,
    matches,
    movies,
    persons,
    recommendations,
    users,
)

logger = logging.getLogger(__name__)

app = FastAPI(title=settings.app_name, debug=settings.debug)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix=settings.api_v1_prefix)
app.include_router(movies.router, prefix=settings.api_v1_prefix)
app.include_router(persons.router, prefix=settings.api_v1_prefix)
app.include_router(users.router, prefix=settings.api_v1_prefix)
app.include_router(friends.router, prefix=settings.api_v1_prefix)
app.include_router(matches.router, prefix=settings.api_v1_prefix)
app.include_router(recommendations.router, prefix=settings.api_v1_prefix)


@app.on_event("startup")
def _ensure_indexes():
    """Create performance indexes that may not exist yet (idempotent)."""
    stmts = [
        "CREATE INDEX IF NOT EXISTS ix_ratings_movie_id ON ratings (movie_id)",
    ]
    try:
        with engine.connect() as conn:
            for s in stmts:
                conn.execute(text(s))
            conn.commit()
        logger.info("Startup indexes OK")
    except Exception:
        logger.warning("Could not create startup indexes", exc_info=True)


@app.get("/health", tags=["health"])
def health():
    return {"status": "ok"}
