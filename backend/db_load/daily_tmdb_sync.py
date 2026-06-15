"""
daily_tmdb_sync.py
------------------
Script unifié pour exécution quotidienne sur AWS Lambda ou ECS.
Récupère les IDs modifiés des dernières 24h, télécharge leurs détails,
et met à jour la base PostgreSQL.
"""

import os
import requests
from datetime import datetime, timedelta
from sqlalchemy import create_engine, text
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import logging

# On importe les fonctions de parsing et batch_upsert de load_movies.py
# (load_movies.py doit être dans le même dossier ou module)
from load_movies import (
    parse_movie, parse_movie_contents, parse_videos,
    parse_movie_genres, parse_persons, parse_cast, parse_crew,
    batch_upsert, batch_insert_ignore
)

# Configuration Logging pour AWS CloudWatch
logger = logging.getLogger()
logger.setLevel(logging.INFO)

API_KEY = os.environ.get("TMDB_API_KEY")
DATABASE_URL = os.environ.get("DATABASE_URL")
CHANGES_BASE_URL = "https://api.themoviedb.org/3/movie/changes"
MOVIE_BASE_URL = "https://api.themoviedb.org/3/movie"


def make_session():
    s = requests.Session()
    retry = Retry(
        total=5,
        backoff_factor=1,
        status_forcelist=(429, 500, 502, 503, 504),
        allowed_methods=frozenset(["GET"]),
    )
    adapter = HTTPAdapter(max_retries=retry, pool_connections=20, pool_maxsize=20)
    s.mount("https://", adapter)
    return s


def get_daily_changed_ids(session: requests.Session) -> set:
    """Récupère les IDs des films modifiés sur les dernières 24h."""
    # On prend une marge de 2 jours pour s'assurer de ne rien rater à cause des fuseaux horaires
    end_date = datetime.utcnow()
    start_date = end_date - timedelta(days=2)
    
    start_str = start_date.strftime("%Y-%m-%d")
    end_str = end_date.strftime("%Y-%m-%d")
    
    changed_ids = set()
    page = 1
    total_pages = 1

    logger.info(f"Recherche des modifications TMDB du {start_str} au {end_str}...")

    while page <= total_pages:
        response = session.get(
            CHANGES_BASE_URL,
            params={"api_key": API_KEY, "start_date": start_str, "end_date": end_str, "page": page},
            timeout=10,
        )
        if not response.ok:
            logger.error(f"Erreur API Changes: {response.status_code}")
            break

        data = response.json()
        for item in data.get("results", []):
            if item.get("id"):
                changed_ids.add(item["id"])

        total_pages = data.get("total_pages", 1)
        page += 1

    logger.info(f"{len(changed_ids)} films modifiés détectés.")
    return changed_ids


def fetch_movie_details(session: requests.Session, movie_ids: set) -> list:
    """Télécharge les détails complets pour une liste d'IDs."""
    movies_data = []
    
    for mid in movie_ids:
        response = session.get(
            f"{MOVIE_BASE_URL}/{mid}",
            params={"api_key": API_KEY, "append_to_response": "credits,keywords,videos,translations"},
            timeout=10,
        )
        if response.status_code == 404:
            continue # Film supprimé ou non trouvé, on ignore
        if response.ok:
            data = response.json()
            if data.get("success") is not False:
                movies_data.append(data)
        else:
            logger.warning(f"Echec récupération ID {mid}: HTTP {response.status_code}")

    return movies_data


def update_database(movies_data: list):
    """Parse et insère les données en base avec tes fonctions existantes."""
    if not movies_data:
        return

    logger.info(f"Préparation de l'insertion pour {len(movies_data)} films...")
    engine = create_engine(DATABASE_URL, future=True)

    movies, movie_contents, videos, movie_genres_rows = [], [], [], []
    all_persons, cast_rows, crew_rows = [], [], []

    for data in movies_data:
        movies.append(parse_movie(data))
        movie_contents.extend(parse_movie_contents(data))
        videos.extend(parse_videos(data))
        movie_genres_rows.extend(parse_movie_genres(data))
        all_persons.extend(parse_persons(data))
        cast_rows.extend(parse_cast(data))
        crew_rows.extend(parse_crew(data))

    # Déduplication des personnes avant insertion
    persons_dedup = {p["tmdb_id"]: p for p in all_persons}
    all_persons = list(persons_dedup.values())

    with engine.begin() as conn:
        batch_upsert(
            conn, "movies", movies,
            conflict_cols=["tmdb_id"],
            update_cols=["imdb_id", "original_title", "release_date", "runtime", "poster_path", "backdrop_path", "original_language", "status"]
        )
        batch_upsert(
            conn, "movie_content", movie_contents,
            conflict_cols=["tmdb_id", "language_iso"],
            update_cols=["title", "overview", "tag_line"]
        )
        batch_upsert(
            conn, "video", videos,
            conflict_cols=["tmdb_id", "language_iso"],
            update_cols=["youtube_key"]
        )
        batch_insert_ignore(
            conn, "movie_genres", movie_genres_rows,
            conflict_cols=["movie_id", "genre_id"]
        )
        batch_upsert(
            conn, "persons", all_persons,
            conflict_cols=["tmdb_id"],
            update_cols=["name", "gender", "known_for_department", "profile_path"]
        )
        batch_upsert(
            conn, "movie_cast", cast_rows,
            conflict_cols=["movie_id", "person_id", "cast_order"],
            update_cols=["character"]
        )
        batch_upsert(
            conn, "movie_crew", crew_rows,
            conflict_cols=["movie_id", "person_id", "job"],
            update_cols=["department"]
        )

    logger.info("Mise à jour de la base de données terminée avec succès.")


# --- ENTRY POINT POUR AWS LAMBDA ---
def lambda_handler(event, context):
    """Fonction principale appelée par AWS Lambda."""
    session = make_session()
    
    try:
        # 1. Identifier les changements
        changed_ids = get_daily_changed_ids(session)
        
        if not changed_ids:
            logger.info("Aucun changement détecté aujourd'hui.")
            return {"statusCode": 200, "body": "No changes"}

        # 2. Récupérer les données détaillées (en mémoire)
        movies_data = fetch_movie_details(session, changed_ids)
        
        # 3. Mettre à jour la DB PostgreSQL
        update_database(movies_data)
        
        return {
            "statusCode": 200,
            "body": f"Sync complete. Updated {len(movies_data)} movies."
        }
        
    except Exception as e:
        logger.error(f"Erreur fatale lors de la synchronisation: {str(e)}", exc_info=True)
        raise e

# --- ENTRY POINT POUR TEST LOCAL ---
if __name__ == "__main__":
    lambda_handler({}, None)