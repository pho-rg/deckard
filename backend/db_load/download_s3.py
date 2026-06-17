import os
import boto3
from pathlib import Path

# On récupère le nom du bucket (passé en variable d'environnement par Terraform)
BUCKET_NAME = os.environ.get("S3_BUCKET", "deckard-s3-bucket")
PREFIX = "recup_/"
DEST_DIR = "/data/"

def download_s3_folder():
    print(f"Début du téléchargement depuis s3://{BUCKET_NAME}/{PREFIX} vers {DEST_DIR}...")
    s3 = boto3.client('s3')
    
    # Créer le dossier de destination s'il n'existe pas
    Path(DEST_DIR).mkdir(parents=True, exist_ok=True)
    
    # Lister les fichiers dans le bucket
    paginator = s3.get_paginator('list_objects_v2')
    pages = paginator.paginate(Bucket=BUCKET_NAME, Prefix=PREFIX)
    
    count = 0
    for page in pages:
        if "Contents" in page:
            for obj in page["Contents"]:
                key = obj["Key"]
                
                # Ignorer les "dossiers"
                if key.endswith('/'):
                    continue
                    
                # Extraire le nom du fichier
                file_name = os.path.basename(key)
                local_path = os.path.join(DEST_DIR, file_name)
                
                # Télécharger
                print(f"  Téléchargement: {file_name}")
                s3.download_file(BUCKET_NAME, key, local_path)
                count += 1
                
    print(f"Terminé : {count} fichiers téléchargés dans {DEST_DIR}.")

if __name__ == "__main__":
    download_s3_folder()