"""
load_movies.py
--------------
Charge les fichiers raw_movie_data_*.jsonl en base PostgreSQL.
VERSION OPTIMISÉE POUR LA MÉMOIRE (Streaming par batch)
"""

import json
import os
import glob
import argparse
from datetime import date
from pathlib import Path

from sqlalchemy import create_engine, text

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
BATCH_SIZE = 500
KEPT_LANGUAGES = {"fr", "en"}
TRAILER_LANG_PREF = ["en", "fr"] # Langues pour lesquelles on veut un trailer (ordre de préférence)
DATABASE_URL = os.environ["DATABASE_URL"]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def parse_date(s: str | None) -> date | None:
    if not s:
        return None
    try:
        return date.fromisoformat(s)
    except ValueError:
        return None

def movie_status(raw: str | None) -> str:
    return "released" if raw == "Released" else "not_released"


def extract_trailers(videos: list[dict]) -> dict[str, str]:
    """
    Retourne {language_iso: youtube_key} pour les trailers officiels YouTube.
    Un seul trailer par langue (le premier rencontré).
    """
    result: dict[str, str] = {}
    for v in videos:
        if v.get("type") == "Trailer" and v.get("official") is True and v.get("site") == "YouTube":
            lang = v.get("iso_639_1", "")[:2]
            if lang in KEPT_LANGUAGES and lang not in result:
                result[lang] = v["key"]
    return result

def batch_upsert(conn, table: str, rows: list[dict], conflict_cols: list[str], update_cols: list[str]) -> None:
    if not rows:
        return
    cols = list(rows[0].keys())
    col_names = ", ".join(cols)
    placeholders = ", ".join(f":{c}" for c in cols)
    conflict = ", ".join(conflict_cols)
    updates = ", ".join(f"{c} = EXCLUDED.{c}" for c in update_cols)

    stmt = text(f"INSERT INTO {table} ({col_names}) VALUES ({placeholders}) ON CONFLICT ({conflict}) DO UPDATE SET {updates}")
    conn.execute(stmt, rows)

def batch_insert_ignore(conn, table: str, rows: list[dict], conflict_cols: list[str]) -> None:
    if not rows:
        return
    cols = list(rows[0].keys())
    col_names = ", ".join(cols)
    placeholders = ", ".join(f":{c}" for c in cols)
    conflict = ", ".join(conflict_cols)

    stmt = text(f"INSERT INTO {table} ({col_names}) VALUES ({placeholders}) ON CONFLICT ({conflict}) DO NOTHING")
    conn.execute(stmt, rows)

# ---------------------------------------------------------------------------
# Parsers
# ---------------------------------------------------------------------------

def parse_movie(data: dict) -> dict:
    return {
        "tmdb_id": data["id"],
        "imdb_id": data.get("imdb_id"),
        "original_title": data.get("original_title"),
        "release_date": parse_date(data.get("release_date")),
        "runtime": data.get("runtime"),
        "poster_path": data.get("poster_path"),
        "backdrop_path": data.get("backdrop_path"),
        "original_language": data.get("original_language"),
        "status": movie_status(data.get("status")),
    }

def parse_movie_contents(data: dict) -> list[dict]:
    """Retourne 0-2 lignes movie_content (fr et/ou en)."""
    rows = []
    tmdb_id = data["id"]

    # Index des translations disponibles
    trans_by_lang: dict[str, dict] = {}
    for t in data.get("translations", {}).get("translations", []):
        lang = t.get("iso_639_1", "")
        if lang in KEPT_LANGUAGES:
            trans_by_lang[lang] = t.get("data", {})

    for lang in KEPT_LANGUAGES:
        t = trans_by_lang.get(lang, {})
        title = t.get("title") or data.get("original_title") or ""
        if not title: continue
        rows.append({
            "tmdb_id": tmdb_id, "language_iso": lang, "title": title,
            "overview": t.get("overview") or None, "tag_line": t.get("tagline") or None,
        })
    return rows

def parse_videos(data: dict) -> list[dict]:
    trailers = extract_trailers(data.get("videos", {}).get("results", []))
    return [{"tmdb_id": data["id"], "language_iso": lang, "youtube_key": key} for lang, key in trailers.items()]

def parse_movie_genres(data: dict) -> list[dict]:
    return [{"movie_id": data["id"], "genre_id": g["id"]} for g in data.get("genres", [])]

def parse_persons(data: dict) -> list[dict]:
    """
    Extrait les persons (cast + crew) à partir des crédits du film.
    """
    seen: dict[int, dict] = {}  # tmdb_id -> row
    credits = data.get("credits", {})
    for member in credits.get("cast", []) + credits.get("crew", []):
        pid = member.get("id")
        if pid is None or pid in seen: continue
        name = member.get("name") or member.get("original_name") or ""
        seen[pid] = {
            "tmdb_id": pid, "imdb_id": None, "name": name, "gender": member.get("gender"),
            "known_for_department": member.get("known_for_department"), "profile_path": member.get("profile_path"),
        }
    return list(seen.values())

def parse_cast(data: dict) -> list[dict]:
    rows = []
    seen_pk = set()
    for member in data.get("credits", {}).get("cast", []):
        pid, order = member.get("id"), member.get("order", 0)
        if pid is None: continue
        pk = (data["id"], pid, order)
        if pk in seen_pk: continue
        seen_pk.add(pk)
        rows.append({"movie_id": data["id"], "person_id": pid, "character": (member.get("character") or "")[:255] or None, "cast_order": order})
    return rows

def parse_crew(data: dict) -> list[dict]:
    rows = []
    seen_pk = set()
    for member in data.get("credits", {}).get("crew", []):
        pid, job = member.get("id"), (member.get("job") or "")[:100]
        if pid is None or not job: continue
        pk = (data["id"], pid, job)
        if pk in seen_pk: continue
        seen_pk.add(pk)
        rows.append({"movie_id": data["id"], "person_id": pid, "job": job, "department": (member.get("department") or "")[:100] or None})
    return rows

# ---------------------------------------------------------------------------
# Main (Optimisé)
# ---------------------------------------------------------------------------

def flush_to_db(engine, movies, movie_contents, videos, movie_genres_rows, all_persons, cast_rows, crew_rows):
    """Envoie les données accumulées en base et vide les listes en mémoire."""
    if not movies:
        return
        
    persons_dedup = {p["tmdb_id"]: p for p in all_persons}
    all_persons_deduped = list(persons_dedup.values())

    with engine.begin() as conn:
        batch_upsert(conn, "movies", movies, ["tmdb_id"], ["imdb_id", "original_title", "release_date", "runtime", "poster_path", "backdrop_path", "original_language", "status"])
        batch_upsert(conn, "movie_content", movie_contents, ["tmdb_id", "language_iso"], ["title", "overview", "tag_line"])
        batch_upsert(conn, "video", videos, ["tmdb_id", "language_iso"], ["youtube_key"])
        batch_insert_ignore(conn, "movie_genres", movie_genres_rows, ["movie_id", "genre_id"])
        batch_upsert(conn, "persons", all_persons_deduped, ["tmdb_id"], ["name", "gender", "known_for_department", "profile_path"])
        batch_upsert(conn, "movie_cast", cast_rows, ["movie_id", "person_id", "cast_order"], ["character"])
        batch_upsert(conn, "movie_crew", crew_rows, ["movie_id", "person_id", "job"], ["department"])

    # On vide les listes pour libérer la mémoire (crucial)
    movies.clear()
    movie_contents.clear()
    videos.clear()
    movie_genres_rows.clear()
    all_persons.clear()
    cast_rows.clear()
    crew_rows.clear()


def load(shards_dir: str) -> None:
    engine = create_engine(DATABASE_URL, future=True)

    shard_paths = sorted(glob.glob(str(Path(shards_dir) / "raw_movie_data_*.jsonl")))
    if not shard_paths:
        print(f"Aucun shard trouvé dans {shards_dir}")
        return

    print(f"{len(shard_paths)} shard(s) trouvé(s)")

    # Listes tampons (buffers)
    movies, movie_contents, videos = [], [], []
    movie_genres_rows, all_persons = [], []
    cast_rows, crew_rows = [], []
    
    total_processed = 0

    for shard_path in shard_paths:
        print(f"  → Lecture de {shard_path}")

        with open(shard_path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line: continue
                try:
                    data = json.loads(line)
                except json.JSONDecodeError:
                    continue

                if data.get("adult") is True:
                    continue

                movies.append(parse_movie(data))
                movie_contents.extend(parse_movie_contents(data))
                videos.extend(parse_videos(data))
                movie_genres_rows.extend(parse_movie_genres(data))
                all_persons.extend(parse_persons(data))
                cast_rows.extend(parse_cast(data))
                crew_rows.extend(parse_crew(data))
                
                total_processed += 1

                # Si le buffer est plein, on envoie en base et on le vide
                if len(movies) >= BATCH_SIZE:
                    flush_to_db(engine, movies, movie_contents, videos, movie_genres_rows, all_persons, cast_rows, crew_rows)

        # À la fin de chaque fichier, on flush le reste du buffer s'il y en a
        flush_to_db(engine, movies, movie_contents, videos, movie_genres_rows, all_persons, cast_rows, crew_rows)
        print(f"     [OK] {total_processed} films traités au total jusqu'ici.")

    print("Chargement movies terminé avec succès !")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", default=".", help="Dossier contenant les shards")
    args = parser.parse_args()
    load(args.dir)