"""
load_genres.py
--------------
Récupère les genres depuis l'API TMDB (fr + en) et les insère en base.

Tables alimentées :
  genres         — upsert sur tmdb_id
  genre_content  — upsert sur (tmdb_id, language_iso)

Usage :
  DATABASE_URL=postgresql://... TMDB_API_KEY=... python load_genres.py
"""

import os
import requests
from dotenv import load_dotenv
from pathlib import Path
from sqlalchemy import create_engine, text

load_dotenv(Path(__file__).resolve().parent / ".env")

TMDB_TOKEN = os.environ["TMDB_API_KEY"]
DATABASE_URL = os.environ["DATABASE_URL"]
LANGUAGES = ["fr", "en"]


def fetch_genres(language: str) -> list[dict]:
    response = requests.get(
        f"https://api.themoviedb.org/3/genre/movie/list?language={language}",
        headers={"Authorization": f"Bearer {TMDB_TOKEN}", "accept": "application/json"},
        timeout=10,
    )
    response.raise_for_status()
    return response.json()["genres"]


def load() -> None:
    engine = create_engine(DATABASE_URL, future=True)

    # Fetch pour les deux langues
    genres_by_lang: dict[str, list[dict]] = {}
    for lang in LANGUAGES:
        genres_by_lang[lang] = fetch_genres(lang)
        print(f"  {lang} : {len(genres_by_lang[lang])} genres récupérés")

    # Union des tmdb_id pour la table genres
    all_ids = {g["id"] for genres in genres_by_lang.values() for g in genres}
    genre_rows = [{"tmdb_id": gid} for gid in sorted(all_ids)]

    # Lignes genre_content
    content_rows = [
        {"tmdb_id": g["id"], "language_iso": lang, "name": g["name"]}
        for lang, genres in genres_by_lang.items()
        for g in genres
    ]

    with engine.begin() as conn:
        conn.execute(
            text("INSERT INTO genres (tmdb_id) VALUES (:tmdb_id) ON CONFLICT DO NOTHING"),
            genre_rows,
        )
        conn.execute(
            text(
                "INSERT INTO genre_content (tmdb_id, language_iso, name) "
                "VALUES (:tmdb_id, :language_iso, :name) "
                "ON CONFLICT (tmdb_id, language_iso) DO UPDATE SET name = EXCLUDED.name"
            ),
            content_rows,
        )

    print(f"{len(genre_rows)} genres insérés, {len(content_rows)} contenus insérés.")


if __name__ == "__main__":
    load()
