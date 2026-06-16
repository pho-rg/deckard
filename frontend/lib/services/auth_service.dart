import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'auth_token';
  static const _refreshKey = 'refresh_token';

  static final _api = ApiService();

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
    return (me is Map && me['needs_onboarding'] == true);
  }

  /// Validation de l'onboarding : les films cochés deviennent des favoris.
  /// POST /users/me/favorites/batch { tmdb_ids: [...] }
  static Future<void> saveOnboardingMovies(List<int> tmdbIds) async {
    if (tmdbIds.isEmpty) return;
    await _api.post('/users/me/favorites/batch', {'tmdb_ids': tmdbIds});
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
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    ApiService.token = null;
  }

  /// Appelé au démarrage. Restaure le token s'il existe.
  static Future<bool> tryRestoreToken() async {
    final token = await _storage.read(key: _accessKey);
    if (token != null) {
      ApiService.token = token;
      return true;
    }
    return false;
  }

  static Future<void> _persistTokens(String access, String refresh) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
    ApiService.token = access;
  }
}
