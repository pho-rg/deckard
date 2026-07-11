# Utilisation du modèle : produit une liste ordonnée d'ids TMDb à partir
# des notes d'un utilisateur ou d'un groupe.
# Rien n'est stocké côté modèle : le profil de goût est recalculé à
# chaque appel à partir des notes passées en paramètre.
# Le modèle est téléchargé depuis le S3 au moment de l'instanciation de
# MovieRecommender (une seule fois, au premier appel de
# get_recommendations).

from pathlib import Path
import pickle
import tempfile
import boto3
import numpy as np

# emplacement du modèle sur le S3
S3_BUCKET = "deckard-s3-bucket"
S3_PREFIX = "match_model/current"

# dossier local où les fichiers du modèle sont téléchargés
LOCAL_MODEL_DIR = Path(tempfile.gettempdir()) / "match_model"

RATING_MIN = 0.5
RATING_MAX = 5.0

# force du lissage lors du recalcul du profil : plus la valeur est haute,
# plus un utilisateur avec peu de notes reste proche du classement général
FOLDIN_REGULARIZATION = 0.5

TOP_X = 100


def compute_user_profile(user_ratings, movie_features, movie_bias, global_mean):
    """Recalcule le profil de goût d'un utilisateur à partir de ses notes.
    user_ratings : dictionnaire ligne de matrice du film vers note.
    Résout une petite équation qui cherche le profil expliquant le mieux
    les notes données, avec un lissage pour éviter les conclusions
    hâtives quand il y a peu de notes."""
    movie_rows = np.array(list(user_ratings.keys()))
    rating_values = np.array(list(user_ratings.values()))

    user_bias = float((rating_values - global_mean - movie_bias[movie_rows]).mean())
    features = movie_features[movie_rows]
    target = rating_values - global_mean - user_bias - movie_bias[movie_rows]

    dimensions = movie_features.shape[1]
    ridge = FOLDIN_REGULARIZATION * len(movie_rows) / 10.0
    A = features.T @ features + (ridge + 1e-6) * np.eye(dimensions)
    user_profile = np.linalg.solve(A, features.T @ target)
    return user_profile, user_bias


def score_all_movies(user_ratings, movie_features, movie_bias, global_mean):
    """Score de chaque film du catalogue pour un utilisateur.
    Les films déjà notés reçoivent moins l'infini pour ne jamais être
    recommandés. Sans aucune note : classement par qualité générale."""
    if len(user_ratings) == 0:
        return global_mean + movie_bias.copy()
    user_profile, user_bias = compute_user_profile(
        user_ratings, movie_features, movie_bias, global_mean)
    scores = global_mean + user_bias + movie_bias + movie_features @ user_profile
    for movie_row in user_ratings:
        scores[movie_row] = -np.inf
    return scores


class MovieRecommender:
    """Télécharge le modèle depuis le S3, le charge en mémoire et produit
    des recommandations. À instancier une seule fois au démarrage de
    l'application, puis à réutiliser à chaque requête.
    Entrée : notes avec des ids TMDb. Sortie : liste ordonnée d'ids TMDb,
    meilleur en premier. L'application se charge de l'affichage et des
    filtres à partir de sa base de données."""

    def __init__(self):
        LOCAL_MODEL_DIR.mkdir(parents=True, exist_ok=True)
        model_path = LOCAL_MODEL_DIR / "model.npz"
        mappings_path = LOCAL_MODEL_DIR / "mappings.pkl"

        # téléchargement des deux fichiers du modèle depuis le S3
        s3 = boto3.client("s3")
        s3.download_file(S3_BUCKET, f"{S3_PREFIX}/model.npz", str(model_path))
        s3.download_file(S3_BUCKET, f"{S3_PREFIX}/mappings.pkl", str(mappings_path))

        saved = np.load(model_path)
        self.movie_features = saved["movie_features"]
        self.movie_bias = saved["movie_bias"]
        self.global_mean = float(saved["global_mean"])
        self.popularity = saved["popularity"]
        self.popularity_beta = float(saved["popularity_beta"])

        with open(mappings_path, "rb") as f:
            mappings = pickle.load(f)
        self.tmdb_to_row = mappings["tmdb_to_row"]
        self.row_to_tmdb = mappings["row_to_tmdb"]
        self.genre_flags = mappings["genre_flags"]
        self.genres = mappings["genres"]

    def to_matrix_rows(self, user_ratings):
        """Convertit un dictionnaire id TMDb vers note en dictionnaire
        ligne de matrice vers note. Les films inconnus du modèle sont
        ignorés silencieusement."""
        return {self.tmdb_to_row[m]: r for m, r in user_ratings.items()
                if m in self.tmdb_to_row}

    def get_genre_affinities(self, known_ratings):
        """Affinités par genre calculées depuis les notes elles-mêmes :
        écart entre la note moyenne donnée aux films d'un genre et la
        note moyenne générale du catalogue. Un écart positif signifie
        que le genre est mieux noté que la moyenne des films, donc
        apprécié. La comparaison se fait avec la moyenne du catalogue et
        non celle de l'utilisateur : un utilisateur qui ne note que des
        films aimés garde ainsi des affinités marquées."""
        movie_rows = np.array(list(known_ratings.keys()))
        rating_values = np.array(list(known_ratings.values()))

        affinities = np.zeros(len(self.genres))
        for genre_column in range(len(self.genres)):
            in_genre = self.genre_flags[movie_rows, genre_column]
            if in_genre.any():
                affinities[genre_column] = (rating_values[in_genre]
                                            - self.global_mean).mean()
        return affinities

    def select_calibrated(self, affinities, scores, top_x):
        """Répartit les top_x places entre les genres au prorata des
        affinités positives, puis remplit chaque quota avec les meilleurs
        films du genre. Évite qu'un seul genre dominant remplisse toute
        la liste (bulle de filtre)."""
        positive_affinities = np.clip(affinities, 0, None)
        if positive_affinities.sum() == 0:
            return np.argsort(-scores)[:top_x]
        genre_proportions = positive_affinities / positive_affinities.sum()

        # nombre de places par genre, les restes vont aux plus grosses
        # décimales pour retomber exactement sur top_x
        exact_slots = genre_proportions * top_x
        slots_per_genre = np.floor(exact_slots).astype(int)
        slots_left = top_x - slots_per_genre.sum()
        biggest_remainders = np.argsort(-(exact_slots - slots_per_genre))
        slots_per_genre[biggest_remainders[:slots_left]] += 1

        selected = []
        already_taken = np.zeros(len(scores), dtype=bool)
        already_taken[~np.isfinite(scores)] = True

        # les genres sont servis du plus gros quota au plus petit
        for genre_column in np.argsort(-slots_per_genre):
            needed = slots_per_genre[genre_column]
            if needed == 0:
                break
            candidates = np.where(self.genre_flags[:, genre_column]
                                  & ~already_taken)[0]
            best_of_genre = candidates[np.argsort(-scores[candidates])][:needed]
            selected.extend(best_of_genre.tolist())
            already_taken[best_of_genre] = True

        # si des quotas n'ont pas pu être remplis, complément au score
        if len(selected) < top_x:
            remaining = np.where(~already_taken)[0]
            best_remaining = remaining[np.argsort(-scores[remaining])]
            selected.extend(best_remaining[:top_x - len(selected)].tolist())

        return np.array(selected[:top_x])

    def recommend(self, user_ratings, top_x=TOP_X, calibrated=True):
        """Recommandations pour un utilisateur.
        user_ratings : dictionnaire id TMDb vers note.
        Retourne une liste ordonnée de top_x ids TMDb."""
        known_ratings = self.to_matrix_rows(user_ratings)
        scores = score_all_movies(known_ratings, self.movie_features,
                                  self.movie_bias, self.global_mean)
        scores = scores + self.popularity_beta * self.popularity

        if calibrated and known_ratings:
            affinities = self.get_genre_affinities(known_ratings)
            selected_rows = self.select_calibrated(affinities, scores, top_x)
        else:
            selected_rows = np.argsort(-scores)[:top_x]

        ordered_rows = selected_rows[np.argsort(-scores[selected_rows])]
        return [int(t) for t in self.row_to_tmdb[ordered_rows]]

    def recommend_for_group(self, group_ratings, top_x=TOP_X,
                            seen_movies=None, calibrated=False):
        """Recommandations pour un groupe (fonction matching).
        Stratégie du moindre malheur : le score du groupe pour un film est
        le minimum des scores individuels, donc personne ne déteste ce qui
        est recommandé. Tout film déjà noté par au moins un membre est
        exclu automatiquement.
        La calibration est désactivée par défaut : le moindre malheur
        produit déjà une liste équilibrée pour le groupe, et calibrer sur
        des goûts opposés peut remplir les quotas avec des films médiocres
        pour tout le monde.
        group_ratings : liste de dictionnaires id TMDb vers note, un par
        membre. seen_movies : films vus mais non notés, exclus aussi."""

        # profil et scores de chaque membre séparément : surtout ne pas
        # fusionner les dictionnaires, une note écraserait l'autre si
        # deux membres ont noté le même film
        scores_per_user = []
        affinities_per_user = []
        for user_ratings in group_ratings:
            known_ratings = self.to_matrix_rows(user_ratings)
            scores = score_all_movies(known_ratings, self.movie_features,
                                      self.movie_bias, self.global_mean)
            scores = scores + self.popularity_beta * self.popularity
            scores_per_user.append(scores)
            if known_ratings:
                affinities_per_user.append(
                    self.get_genre_affinities(known_ratings))
        scores_per_user = np.vstack(scores_per_user)

        # minimum des scores : les films notés par un membre sont à moins
        # l'infini dans sa ligne, donc exclus pour tout le groupe
        group_scores = scores_per_user.min(axis=0)

        # exclusion des films vus mais non notés
        if seen_movies:
            for tmdb_id in seen_movies:
                if tmdb_id in self.tmdb_to_row:
                    group_scores[self.tmdb_to_row[tmdb_id]] = -np.inf

        # calibration sur la moyenne des affinités des membres
        if calibrated and affinities_per_user:
            group_affinities = np.mean(affinities_per_user, axis=0)
            selected_rows = self.select_calibrated(group_affinities,
                                                   group_scores, top_x)
        else:
            selected_rows = np.argsort(-group_scores)[:top_x]

        ordered_rows = selected_rows[np.argsort(-group_scores[selected_rows])]
        return [int(t) for t in self.row_to_tmdb[ordered_rows]]


# instance unique du modèle, créée au premier appel puis réutilisée
_recommender = None


def get_recommendations(user_ratings_list, top_x=TOP_X, seen_movies=None):
    """Recommandations pour un ou plusieurs utilisateurs.
    user_ratings_list : liste de dictionnaires id TMDb vers note, un
    dictionnaire par membre. Une liste d'un seul élément correspond à un
    utilisateur seul, plusieurs éléments au mode groupe (matching).
    seen_movies : liste d'ids TMDb vus mais non notés, à exclure.
    Retourne une liste ordonnée de top_x ids TMDb, meilleur en premier."""
    global _recommender
    if _recommender is None:
        _recommender = MovieRecommender()

    if len(user_ratings_list) == 1:
        return _recommender.recommend(user_ratings_list[0], top_x=top_x)
    return _recommender.recommend_for_group(user_ratings_list, top_x=top_x,
                                            seen_movies=seen_movies)