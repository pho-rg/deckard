"""
load_persons.py
---------------
Enrichit la table persons + person_content depuis les raw_person_data_*.jsonl.

À lancer APRÈS load_movies.py (qui crée les ébauches persons nécessaires
aux FK de movie_cast / movie_crew).

Tables alimentées :
  persons       — upsert complet (imdb_id, birthday, deathday, gender, ...)
  person_content — upsert fr + en (name, biography, place_of_birth)

Usage :
  DATABASE_URL=postgresql://user:pass@host/db python load_persons.py [--dir /path/to/shards]
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


def batch_upsert(conn, table: str, rows: list[dict], conflict_cols: list[str], update_cols: list[str]) -> None:
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


# ---------------------------------------------------------------------------
# Parsers
# ---------------------------------------------------------------------------

def parse_person(data: dict) -> dict:
    return {
        "tmdb_id": data["id"],
        "imdb_id": data.get("imdb_id") or None,
        "birthday": parse_date(data.get("birthday")),
        "deathday": parse_date(data.get("deathday")),
        "gender": data.get("gender"),
        "known_for_department": data.get("known_for_department") or None,
        "profile_path": data.get("profile_path") or None,
    }


def parse_person_contents(data: dict) -> list[dict]:
    """
    Retourne 0-2 lignes person_content (fr et/ou en).

    - name      : depuis translations si dispo, sinon data["name"]
    - biography : depuis translations
    - place_of_birth : champ racine du JSON (toujours en anglais dans TMDB),
                       inséré uniquement sur la ligne 'en'
    """
    tmdb_id = data["id"]
    fallback_name = data.get("name", "")
    place_of_birth = data.get("place_of_birth") or None

    # Index des translations disponibles
    trans_by_lang: dict[str, dict] = {}
    for t in data.get("translations", {}).get("translations", []):
        lang = t.get("iso_639_1", "")
        if lang in KEPT_LANGUAGES:
            t_data = t.get("data", {})
            trans_by_lang[lang] = t_data

    rows = []
    for lang in KEPT_LANGUAGES:
        t = trans_by_lang.get(lang, {})

        # name : translation > fallback racine
        name = t.get("name") or fallback_name
        if not name:
            continue  # pas de nom => on saute

        biography = t.get("biography") or None

        rows.append({
            "tmdb_id": tmdb_id,
            "language_iso": lang,
            "name": name,
            "biography": biography,
            # place_of_birth uniquement sur EN (c'est toujours en anglais)
            "place_of_birth": place_of_birth if lang == "en" else None,
        })

    return rows


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def load(shards_dir: str) -> None:
    db_url = os.environ["DATABASE_URL"]
    engine = create_engine(db_url, future=True)

    shard_paths = sorted(glob.glob(str(Path(shards_dir) / "raw_person_data_*.jsonl")))
    if not shard_paths:
        print(f"Aucun shard trouvé dans {shards_dir}")
        return

    print(f"{len(shard_paths)} shard(s) trouvé(s)")

    for shard_path in shard_paths:
        print(f"  → {shard_path}")

        persons, person_contents = [], []

        with open(shard_path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    data = json.loads(line)
                except json.JSONDecodeError:
                    continue

                persons.append(parse_person(data))
                person_contents.extend(parse_person_contents(data))

        with engine.begin() as conn:
            # Upsert complet : écrase tous les champs y compris ceux
            # laissés à None par load_movies (imdb_id, birthday, etc.)
            batch_upsert(
                conn, "persons", persons,
                conflict_cols=["tmdb_id"],
                update_cols=["imdb_id", "birthday", "deathday", "gender",
                             "known_for_department", "profile_path"],
            )
            # person_content : écrase tout, load_persons a la donnée complète
            batch_upsert(
                conn, "person_content", person_contents,
                conflict_cols=["tmdb_id", "language_iso"],
                update_cols=["name", "biography", "place_of_birth"],
            )

        print(f"     {len(persons)} persons enrichies, {len(person_contents)} contenus")

    print("Chargement persons terminé.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", default=".", help="Dossier contenant les shards")
    args = parser.parse_args()
    load(args.dir)
