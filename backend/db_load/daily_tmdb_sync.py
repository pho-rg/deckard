"""
daily_tmdb_sync.py
------------------
Script unifié résilient pour exécution quotidienne sur AWS ECS Fargate.
Utilise Amazon S3 pour stocker la date de dernière synchronisation réussie.
Permet une reprise automatique en cas d'erreur, ou une exécution manuelle
pour rattraper des dates précises via les arguments CLI.
"""

import os
import requests
import boto3
import sys
import argparse
from datetime import datetime, timedelta, timezone
from botocore.exceptions import ClientError
from sqlalchemy import create_engine
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import logging

# Import des fonctions de parsing depuis le fichier load_movies.py local
from load_movies import (
    parse_movie, parse_movie_contents, parse_videos,
    parse_movie_genres, parse_persons, parse_cast, parse_crew,
    batch_upsert, batch_insert_ignore
)

# Configuration Logging pour AWS CloudWatch
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger()

# Variables d'environnement
API_KEY = os.environ.get("TMDB_API_KEY")
DATABASE_URL = os.environ.get("DATABASE_URL")
S3_BUCKET = os.environ.get("S3_BUCKET")
STATE_FILE_KEY = "state/last_tmdb_sync.txt"

CHANGES_BASE_URL = "https://api.themoviedb.org/3/movie/changes"
MOVIE_BASE_URL = "https://api.themoviedb.org/3/movie"

# Initialisation du client S3
s3_client = boto3.client('s3')

def get_last_sync_date() -> str:
    try:
        response = s3_client.get_object(Bucket=S3_BUCKET, Key=STATE_FILE_KEY)
        last_date = response['Body'].read().decode('utf-8').strip()
        logger.info(f"Dernière synchronisation réussie lue sur S3: {last_date}")
        return last_date
    except ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchKey':
            logger.info("Aucun état de synchro trouvé sur S3. Initialisation à J-2.")
            default_date = datetime.now(timezone.utc) - timedelta(days=2)
            return default_date.strftime("%Y-%m-%d")
        else:
            raise e

def set_last_sync_date(date_str: str):
    s3_client.put_object(Bucket=S3_BUCKET, Key=STATE_FILE_KEY, Body=date_str.encode('utf-8'))
    logger.info(f"État de synchronisation mis à jour sur S3 à : {date_str}")

def make_session():
    s = requests.Session()
    retry = Retry(total=5, backoff_factor=1, status_forcelist=(429, 500, 502, 503, 504), allowed_methods=frozenset(["GET"]))
    adapter = HTTPAdapter(max_retries=retry, pool_connections=20, pool_maxsize=20)
    s.mount("https://", adapter)
    s.headers.update({
        "accept": "application/json",
        "Authorization": f"Bearer {API_KEY}"
    })
    return s

def get_changed_ids(session: requests.Session, start_str: str, end_str: str) -> set:
    changed_ids = set()
    page = 1
    total_pages = 1
    logger.info(f"Recherche des modifications TMDB du {start_str} au {end_str}...")

    while page <= total_pages:
        response = session.get(CHANGES_BASE_URL, params={"start_date": start_str, "end_date": end_str, "page": page}, timeout=10)
        response.raise_for_status()
        data = response.json()
        for item in data.get("results", []):
            if item.get("id"):
                changed_ids.add(item["id"])
        total_pages = data.get("total_pages", 1)
        page += 1

    logger.info(f"{len(changed_ids)} films modifiés détectés.")
    return changed_ids

def fetch_movie_details(session: requests.Session, movie_ids: set) -> list:
    movies_data = []
    for mid in movie_ids:
        response = session.get(f"{MOVIE_BASE_URL}/{mid}", params={"append_to_response": "credits,keywords,videos,translations"}, timeout=10)
        if response.status_code == 404:
            continue
        if response.ok:
            data = response.json()
            if data.get("success") is not False:
                if data.get("adult") is True:
                    continue
                movies_data.append(data)
    return movies_data

def update_database(movies_data: list):
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

    persons_dedup = {p["tmdb_id"]: p for p in all_persons}
    all_persons = list(persons_dedup.values())

    with engine.begin() as conn:
        batch_upsert(conn, "movies", movies, conflict_cols=["tmdb_id"], update_cols=["imdb_id", "original_title", "release_date", "runtime", "poster_path", "backdrop_path", "original_language", "status"])
        batch_upsert(conn, "movie_content", movie_contents, conflict_cols=["tmdb_id", "language_iso"], update_cols=["title", "overview", "tag_line"])
        batch_upsert(conn, "video", videos, conflict_cols=["tmdb_id", "language_iso"], update_cols=["youtube_key"])
        batch_insert_ignore(conn, "movie_genres", movie_genres_rows, conflict_cols=["movie_id", "genre_id"])
        batch_upsert(conn, "persons", all_persons, conflict_cols=["tmdb_id"], update_cols=["name", "gender", "known_for_department", "profile_path"])
        batch_upsert(conn, "movie_cast", cast_rows, conflict_cols=["movie_id", "person_id", "cast_order"], update_cols=["character"])
        batch_upsert(conn, "movie_crew", crew_rows, conflict_cols=["movie_id", "person_id", "job"], update_cols=["department"])

    logger.info("Mise à jour DB terminée avec succès.")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--start_date", help="Date de début (YYYY-MM-DD)")
    parser.add_argument("--end_date", help="Date de fin (YYYY-MM-DD)")
    args = parser.parse_args()

    session = make_session()
    
    try:
        is_manual_run = bool(args.start_date and args.end_date)

        if is_manual_run:
            start_date = args.start_date
            end_date = args.end_date
            logger.info(f"Exécution MANUELLE demandée du {start_date} au {end_date}")
        else:
            start_date = get_last_sync_date()
            end_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")

        if start_date == end_date and not is_manual_run:
            logger.info("La synchro a déjà été effectuée aujourd'hui.")
            sys.exit(0)

        changed_ids = get_changed_ids(session, start_str=start_date, end_str=end_date)
        
        if changed_ids:
            movies_data = fetch_movie_details(session, changed_ids)
            update_database(movies_data)
        
        if not is_manual_run:
            set_last_sync_date(end_date)
        
        logger.info(f"Sync complete from {start_date} to {end_date}. Updated {len(changed_ids)} movies.")
        sys.exit(0)
        
    except Exception as e:
        logger.error(f"Erreur fatale: {str(e)}", exc_info=True)
        sys.exit(1)

if __name__ == "__main__":
    main()