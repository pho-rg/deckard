import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'auth_token';
  static const _refreshKey = 'refresh_token';

  static final _api = ApiService();

  /// Id de l'utilisateur connecté (rempli au login / restauration de session).
  /// Sert notamment à savoir si l'on est l'hôte d'un match.
  static String? currentUserId;

  /// Langue du compte connecté (ex. "en-US", "fr-FR"), remplie au login /
  /// restauration de session. Le compte a `fr-FR` par défaut côté serveur
  /// (voir models/user.py) indépendamment de la langue de l'UI — sans
  /// synchroniser LocaleProvider dessus au démarrage, les contenus renvoyés
  /// par le back (titres, synopsis…) restent dans cette langue par défaut
  /// même quand l'UI affiche l'anglais.
  static String? currentUserLanguage;

  /// Connexion email + mot de passe.
  /// POST /auth/login → { access_token, refresh_token, token_type }
  /// Retourne `true` si l'utilisateur doit passer par l'onboarding
  /// (aucun favori enregistré).
  static Future<bool> login(String email, String password) async {
    final data = await _api.post('/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    await _persistTokens(
      data['access_token'] as String,
      data['refresh_token'] as String,
    );
    return fetchNeedsOnboarding();
  }

  /// Inscription email + username + mot de passe.
  /// POST /auth/register → UserOut (PAS de token), donc on enchaîne un login
  /// pour récupérer les tokens. Retourne `true` (nouvel utilisateur → onboarding).
  static Future<bool> register(
      String email, String username, String password) async {
    await _api.post('/auth/register', {
      'email': email.trim(),
      'username': username.trim(),
      'password': password,
    });
    // register ne renvoie pas de token → on se connecte immédiatement.
    return login(email, password);
  }

  /// Indique si l'onboarding est à faire : vrai tant que l'utilisateur n'a
  /// aucun favori. GET /users/me → { ..., needs_onboarding }.
  static Future<bool> fetchNeedsOnboarding() async {
    final me = await _api.get('/users/me');
    if (me is Map) {
      currentUserId = me['id'] as String?;
      currentUserLanguage = me['language'] as String?;
    }
    return (me is Map && me['needs_onboarding'] == true);
  }

  /// Validation de l'onboarding : les films cochés deviennent des favoris.
  /// POST /users/me/favorites/batch { tmdb_ids: [...] }
  static Future<void> saveOnboardingMovies(List<int> tmdbIds) async {
    if (tmdbIds.isEmpty) return;
    await _api.post('/users/me/favorites/batch', {'tmdb_ids': tmdbIds});
  }

  /// Rafraîchit le token d'accès via le refresh token stocké.
  /// Branché sur ApiService.onRefreshToken (cf. main()) : appelé
  /// automatiquement par ApiService quand une requête reçoit un 401, avant
  /// d'abandonner la session. Retourne false si aucun refresh token n'est
  /// stocké ou s'il est lui-même invalide/expiré (déconnexion inévitable).
  static Future<bool> refreshTokens() async {
    final refresh = await _storage.read(key: _refreshKey);
    if (refresh == null) return false;
    try {
      final data = await _api.post('/auth/refresh', {'refresh_token': refresh});
      await _persistTokens(
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Efface les tokens et réinitialise l'API.
  static Future<void> logout() async {
    final refresh = await _storage.read(key: _refreshKey);
    if (refresh != null) {
      // best-effort : invalide le refresh token côté serveur
      try {
        await _api.post('/auth/logout', {'refresh_token': refresh});
      } catch (_) {/* on déconnecte localement quoi qu'il arrive */}
    }
    await clearLocalSession();
  }

  /// Purge la session locale (tokens + en-tête API), sans appel serveur.
  /// Utilisé au logout, sur token invalide au démarrage, et sur 401.
  static Future<void> clearLocalSession() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    ApiService.token = null;
    currentUserId = null;
  }

  /// Appelé au démarrage. Restaure le token ET le valide auprès du backend.
  /// → token absent : false (login)
  /// → token présent mais invalide/expiré (401) : purge + false (login)
  /// → token valide : true (accès à l'app)
  static Future<bool> tryRestoreToken() async {
    final token = await _storage.read(key: _accessKey);
    if (token == null) return false;
    ApiService.token = token;
    try {
      final me = await _api.get('/users/me'); // valide réellement le token
      if (me is Map) {
        currentUserId = me['id'] as String?;
        currentUserLanguage = me['language'] as String?;
      }
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await clearLocalSession();
      }
      return false;
    } catch (_) {
      // Backend injoignable / erreur réseau : on n'entre pas dans l'app.
      return false;
    }
  }

  static Future<void> _persistTokens(String access, String refresh) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
    ApiService.token = access;
  }
}
