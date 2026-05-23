# Deckard — Backend

API FastAPI pour Deckard. Tourne en local via Docker Compose (API + Postgres).

## Prérequis

- Docker Desktop (Docker Engine 24+ et Docker Compose v2)

## Démarrer

```sh
# build + démarre db et api, applique les migrations automatiquement
docker compose up -d

# logs en live
docker compose logs -f api

# stoppe les conteneurs (garde les données)
docker compose down

# stoppe + supprime le volume Postgres (wipe complet)
docker compose down -v
```

L'API écoute sur **http://localhost:8000**.
Postgres écoute sur **localhost:5432** (user `deckard`, password `deckard`, db `deckard`).

## Vérifier que ça tourne

```sh
curl http://localhost:8000/health
# → {"status":"ok"}
```

Documentation OpenAPI interactive : **http://localhost:8000/docs**

## Endpoints disponibles

Tous préfixés par `/api/v1`.

| Méthode | Route | Description |
|---|---|---|
| POST | `/auth/register` | Créer un compte |
| POST | `/auth/login` | Récupérer access + refresh tokens |
| POST | `/auth/refresh` | Rotation du refresh token |
| POST | `/auth/logout` | Révoquer le refresh token |
| GET | `/auth/me` | Profil de l'utilisateur connecté (Bearer access) |

## Commandes utiles

### Migrations Alembic

```sh
# appliquer les migrations (fait automatiquement au démarrage)
docker compose exec api alembic upgrade head

# générer une nouvelle migration depuis les modèles SQLAlchemy
docker compose exec api alembic revision --autogenerate -m "ma migration"

# rollback la dernière migration
docker compose exec api alembic downgrade -1

# voir l'historique
docker compose exec api alembic history
```

### Accès Postgres

```sh
# ouvrir psql dans le conteneur db
docker compose exec db psql -U deckard -d deckard

# requête one-shot
docker compose exec db psql -U deckard -d deckard -c "SELECT * FROM users;"

# lister les tables
docker compose exec db psql -U deckard -d deckard -c "\dt"
```

Pour un client GUI (DBeaver, pgAdmin, DataGrip…) :

```
Host:     localhost
Port:     5432
Database: deckard
User:     deckard
Password: deckard
```

### Conteneur API

```sh
# shell dans l'API
docker compose exec api sh

# redémarrer juste l'API (utile après changement de requirements.txt)
docker compose build api && docker compose up -d api

# voir les processus
docker compose ps
```

## Hot-reload

Le code de `backend/` est monté dans le conteneur via volume. Uvicorn tourne en `--reload` : toute modification de fichier `.py` recharge le serveur automatiquement.