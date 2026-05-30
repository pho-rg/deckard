"""
load_movies.py
--------------
Charge les fichiers raw_movie_data_*.jsonl en base PostgreSQL.

À lancer APRÈS load_genres.py

Tables alimentées (dans l'ordre) :
  movies, movie_content, video,
  movie_genres,
  persons (stub),
  person_content (stub, fr+en, name only),
  movie_cast, movie_crew

stub = ébauche de personne qui sera complétée par load_persons plus tard.

Prérequis :
  - Les tables genres + genre_content sont déjà peuplées par load_genres.py.
  - Lancer load_persons.py APRÈS pour enrichir les persons.

Usage :
  DATABASE_URL=postgresql://user:pass@host/db python load_movies.py [--dir /path/to/shards]
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
        if (
            v.get("type") == "Trailer"
            and v.get("official") is True
            and v.get("site") == "YouTube"
        ):
            lang = v.get("iso_639_1", "")[:2]
            if lang in KEPT_LANGUAGES and lang not in result:
                result[lang] = v["key"]
    return result


def batch_upsert(conn, table: str, rows: list[dict], conflict_cols: list[str], update_cols: list[str]) -> None:
    """
    INSERT ... ON CONFLICT (...) DO UPDATE SET ...
    Utilise des paramètres nommés SQLAlchemy.
    """
    if not rows:
        return

    cols = list(rows[0].keys())
    col_names = ", ".join(cols)
    placeholders = ", ".join(f":{c}" for c in cols)
    conflict = ", ".join(conflict_cols)
    updates = ", ".join(f"{c} = EXCLUDED.{c}" for c in update_cols)

    stmt = text(
        f"INSERT INTO {table} ({col_names}) VALUES ({placeholders}) "
        f"ON CONFLICT ({conflict}) DO UPDATE SET {updates}"
    )

    for i in range(0, len(rows), BATCH_SIZE):
        conn.execute(stmt, rows[i : i + BATCH_SIZE])


def batch_insert_ignore(conn, table: str, rows: list[dict], conflict_cols: list[str]) -> None:
    """INSERT ... ON CONFLICT DO NOTHING (tables de liaison)."""
    if not rows:
        return

    cols = list(rows[0].keys())
    col_names = ", ".join(cols)
    placeholders = ", ".join(f":{c}" for c in cols)
    conflict = ", ".join(conflict_cols)

    stmt = text(
        f"INSERT INTO {table} ({col_names}) VALUES ({placeholders}) "
        f"ON CONFLICT ({conflict}) DO NOTHING"
    )

    for i in range(0, len(rows), BATCH_SIZE):
        conn.execute(stmt, rows[i : i + BATCH_SIZE])


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
        if not title:
            continue  # pas de titre => on ne crée pas la ligne
        rows.append({
            "tmdb_id": tmdb_id,
            "language_iso": lang,
            "title": title,
            "overview": t.get("overview") or None,
            "tag_line": t.get("tagline") or None,
        })

    return rows


def parse_videos(data: dict) -> list[dict]:
    videos_raw = data.get("videos", {}).get("results", [])
    trailers = extract_trailers(videos_raw)
    tmdb_id = data["id"]
    return [
        {"tmdb_id": tmdb_id, "language_iso": lang, "youtube_key": key}
        for lang, key in trailers.items()
    ]


def parse_movie_genres(data: dict) -> list[dict]:
    tmdb_id = data["id"]
    return [
        {"movie_id": tmdb_id, "genre_id": g["id"]}
        for g in data.get("genres", [])
    ]


def parse_persons_stub(data: dict) -> tuple[list[dict], list[dict]]:
    """
    Extrait les persons (cast + crew) pour créer des ébauches qui seront complétées par load_persons.
    Retourne (persons_rows, person_content_rows).
    person_content contient uniquement name (biography=None).
    """
    seen: dict[int, dict] = {}  # tmdb_id -> row
    credits = data.get("credits", {})

    for member in credits.get("cast", []) + credits.get("crew", []):
        pid = member.get("id")
        if pid is None or pid in seen:
            continue
        seen[pid] = {
            "tmdb_id": pid,
            "imdb_id": None,
            "birthday": None,
            "deathday": None,
            "gender": member.get("gender"),
            "known_for_department": member.get("known_for_department"),
            "profile_path": member.get("profile_path"),
        }

    persons_rows = list(seen.values())

    # 2 person_content créé : name en + fr (même valeur, on n'a que original_name ici)
    content_rows = []
    for pid, p in seen.items():
        # On récupère le nom depuis cast ou crew
        name = next(
            (
                m.get("name", "")
                for m in credits.get("cast", []) + credits.get("crew", [])
                if m.get("id") == pid
            ),
            "",
        )
        if not name:
            continue
        for lang in KEPT_LANGUAGES:
            content_rows.append({
                "tmdb_id": pid,
                "language_iso": lang,
                "biography": None,
                "place_of_birth": None,
                "name": name,
            })

    return persons_rows, content_rows


def parse_cast(data: dict) -> list[dict]:
    tmdb_id = data["id"]
    rows = []
    seen_pk: set[tuple] = set()
    for member in data.get("credits", {}).get("cast", []):
        pid = member.get("id")
        order = member.get("order", 0)
        if pid is None:
            continue
        pk = (tmdb_id, pid, order)
        if pk in seen_pk:
            continue
        seen_pk.add(pk)
        rows.append({
            "movie_id": tmdb_id,
            "person_id": pid,
            "character": (member.get("character") or "")[:255] or None,
            "cast_order": order,
        })
    return rows


def parse_crew(data: dict) -> list[dict]:
    tmdb_id = data["id"]
    rows = []
    seen_pk: set[tuple] = set()
    for member in data.get("credits", {}).get("crew", []):
        pid = member.get("id")
        job = (member.get("job") or "")[:100]
        if pid is None or not job:
            continue
        pk = (tmdb_id, pid, job)
        if pk in seen_pk:
            continue
        seen_pk.add(pk)
        rows.append({
            "movie_id": tmdb_id,
            "person_id": pid,
            "job": job,
            "department": (member.get("department") or "")[:100] or None,
        })
    return rows


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def load(shards_dir: str) -> None:
    db_url = os.environ["DATABASE_URL"]
    engine = create_engine(db_url, future=True)

    shard_paths = sorted(glob.glob(str(Path(shards_dir) / "raw_movie_data_*.jsonl")))
    if not shard_paths:
        print(f"Aucun shard trouvé dans {shards_dir}")
        return

    print(f"{len(shard_paths)} shard(s) trouvé(s)")

    for shard_path in shard_paths:
        print(f"  → {shard_path}")

        movies, movie_contents, videos = [], [], []
        movie_genres_rows = []
        all_persons, all_person_contents = [], []
        cast_rows, crew_rows = [], []

        with open(shard_path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    data = json.loads(line)
                except json.JSONDecodeError:
                    continue

                movies.append(parse_movie(data))
                movie_contents.extend(parse_movie_contents(data))
                videos.extend(parse_videos(data))
                movie_genres_rows.extend(parse_movie_genres(data))
                p_rows, pc_rows = parse_persons_stub(data)
                all_persons.extend(p_rows)
                all_person_contents.extend(pc_rows)
                cast_rows.extend(parse_cast(data))
                crew_rows.extend(parse_crew(data))

        # Déduplications inter-films dans le shard
        # persons : garder le dernier (load_persons enrichira de toute façon)
        persons_dedup: dict[int, dict] = {p["tmdb_id"]: p for p in all_persons}
        all_persons = list(persons_dedup.values())

        # person_content : (tmdb_id, language_iso) unique
        pc_dedup: dict[tuple, dict] = {
            (p["tmdb_id"], p["language_iso"]): p for p in all_person_contents
        }
        all_person_contents = list(pc_dedup.values())

        with engine.begin() as conn:
            batch_upsert(
                conn, "movies", movies,
                conflict_cols=["tmdb_id"],
                update_cols=["imdb_id", "original_title", "release_date", "runtime",
                             "poster_path", "backdrop_path", "original_language", "status"],
            )
            batch_upsert(
                conn, "movie_content", movie_contents,
                conflict_cols=["tmdb_id", "language_iso"],
                update_cols=["title", "overview", "tag_line"],
            )
            batch_upsert(
                conn, "video", videos,
                conflict_cols=["tmdb_id", "language_iso"],
                update_cols=["youtube_key"],
            )
            batch_insert_ignore(conn, "movie_genres", movie_genres_rows,
                                conflict_cols=["movie_id", "genre_id"])
            # persons : on ne met à jour que les champs non-null
            batch_upsert(
                conn, "persons", all_persons,
                conflict_cols=["tmdb_id"],
                update_cols=["gender", "known_for_department", "profile_path"],
            )
            # person_content : on n'écrase pas biography/place_of_birth si déjà remplis
            batch_upsert(
                conn, "person_content", all_person_contents,
                conflict_cols=["tmdb_id", "language_iso"],
                update_cols=["name"],  # name seulement, on ne touche pas biography
            )
            batch_upsert(
                conn, "movie_cast", cast_rows,
                conflict_cols=["movie_id", "person_id", "cast_order"],
                update_cols=["character"],
            )
            batch_upsert(
                conn, "movie_crew", crew_rows,
                conflict_cols=["movie_id", "person_id", "job"],
                update_cols=["department"],
            )

        print(f"     {len(movies)} films, {len(all_persons)} persons (stubs), "
              f"{len(cast_rows)} cast, {len(crew_rows)} crew")

    print("Chargement movies terminé.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", default=".", help="Dossier contenant les shards")
    args = parser.parse_args()
    load(args.dir)
