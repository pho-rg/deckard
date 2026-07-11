"""
load_ratings.py
---------------
Script ultra-performant pour charger un énorme CSV de recommandations.
- Utilise psycopg3 COPY pour des performances d'insertion maximales.
- Convertit les notes de /5 à /10 (en Integer).
- Convertit les timestamps Unix en DateTime UTC.
- Convertit les ID fictifs (0, 1, 2...) en vrais UUIDs déterministes.
- Ignore silencieusement les avis concernant des films absents de la BDD.
- Crée automatiquement les utilisateurs fictifs manquants.
"""

import os
import csv
import argparse
import uuid
from datetime import datetime, timezone
from sqlalchemy import create_engine, text
from tqdm import tqdm

DATABASE_URL = os.environ.get("DATABASE_URL")

# Namespace arbitraire pour générer nos UUIDs de façon déterministe
NAMESPACE_AI = uuid.NAMESPACE_OID

def load_ratings(csv_path: str):
    engine = create_engine(DATABASE_URL)
    
    # ---------------------------------------------------------
    # 1. Mise en cache des films existants (Prévention des crashs FK)
    # ---------------------------------------------------------
    print("1. Mise en cache des films existants...")
    with engine.connect() as conn:
        result = conn.execute(text("SELECT tmdb_id FROM movies"))
        valid_movie_ids = {row[0] for row in result}
    print(f"   -> {len(valid_movie_ids)} films trouvés en base. Les autres seront ignorés.")

    # ---------------------------------------------------------
    # 2. Analyse du CSV pour trouver les utilisateurs
    # ---------------------------------------------------------
    print("2. Analyse du CSV (Extraction des utilisateurs)...")
    unique_users = set()
    total_lines = 0
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            unique_users.add(int(row['user_row']))
            total_lines += 1
    print(f"   -> {len(unique_users)} utilisateurs uniques et {total_lines} avis détectés.")

    # ---------------------------------------------------------
    # 3. Création des Utilisateurs Fictifs (Avec conversion UUID)
    # ---------------------------------------------------------
    print("3. Création des utilisateurs fictifs (s'ils n'existent pas)...")
    users_to_insert = [
        {
            # Génération d'un UUID unique basé sur l'entier du CSV
            "id": str(uuid.uuid5(NAMESPACE_AI, f"ai_user_{uid}")),
            "username": f"ai_user_{uid}",
            "email": f"ai_user_{uid}@deckard.local",
            "password_hash": "not_a_real_password"
        }
        for uid in unique_users
    ]
    
    with engine.begin() as conn:
        # Insertion massive en ignorant ceux qui existent déjà (ON CONFLICT DO NOTHING)
        stmt = text("""
            INSERT INTO users (id, username, email, password_hash)
            VALUES (:id, :username, :email, :password_hash)
            ON CONFLICT (id) DO NOTHING
        """)
        chunk_size = 5000
        for i in tqdm(range(0, len(users_to_insert), chunk_size), desc="Insertion utilisateurs"):
            conn.execute(stmt, users_to_insert[i:i+chunk_size])
            
        # Plus besoin de setval() car on n'utilise pas d'autoincrement, mais des UUIDs !

    # ---------------------------------------------------------
    # 4. Insertion des avis via PostgreSQL COPY (Ultra-Rapide)
    # ---------------------------------------------------------
    print("4. Insertion massive des avis (COPY en streaming)...")
    
    with engine.raw_connection() as raw_conn:
        with raw_conn.cursor() as cur:
            copy_query = "COPY ratings (user_id, movie_id, rating, created_at) FROM STDIN"
            
            with cur.copy(copy_query) as copy:
                with open(csv_path, 'r', encoding='utf-8') as f:
                    reader = csv.DictReader(f)
                    
                    for row in tqdm(reader, total=total_lines, desc="Écriture des avis en base"):
                        movie_id = int(row['movie_row'])
                        
                        # Si le film n'existe pas dans la base, on ignore l'avis
                        if movie_id not in valid_movie_ids:
                            continue
                        
                        # Conversion de l'ID en UUID
                        user_id_int = int(row['user_row'])
                        user_uuid = str(uuid.uuid5(NAMESPACE_AI, f"ai_user_{user_id_int}"))
                        
                        # Conversion de la note sur 10 (en Integer comme défini dans Alembic)
                        rating = int(float(row['rating']) * 2)
                        
                        # Conversion du timestamp Unix
                        created_at = datetime.fromtimestamp(int(row['timestamp']), tz=timezone.utc)
                        
                        # Écriture de la ligne dans le flux COPY
                        copy.write_row((user_uuid, movie_id, rating, created_at))
                        
        raw_conn.commit()
        
    print("✅ Chargement des avis terminé avec succès !")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", required=True, help="Chemin vers le fichier CSV (ex: /tmp/ratings.csv)")
    args = parser.parse_args()
    load_ratings(args.file)