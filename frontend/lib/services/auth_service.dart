import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'auth_token';
  static const _refreshKey = 'refresh_token';

  static final _api = ApiService();

  /// Connexion email + mot de passe.
  /// POST /auth/login → { access_token, refresh_token, token_type }
  static Future<void> login(String email, String password) async {
    final data = await _api.post('/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    await _persistTokens(
      data['access_token'] as String,
      data['refresh_token'] as String,
    );
  }

  /// Inscription email + username + mot de passe.
  /// POST /auth/register → UserOut (PAS de token), donc on enchaîne un login
  /// pour récupérer les tokens et authentifier l'onboarding qui suit.
  static Future<void> register(
      String email, String username, String password) async {
    await _api.post('/auth/register', {
      'email': email.trim(),
      'username': username.trim(),
      'password': password,
    });
    // register ne renvoie pas de token → on se connecte immédiatement.
    await login(email, password);
  }

  /// Save onboarding movie picks (called after register).
  /// Each selected film should be added to both the user's watched list
  /// and their favorites list.
  /// TODO: implement with two calls (or a dedicated onboarding endpoint):
  ///   await ApiService().post('/users/me/watched/batch', {'tmdb_ids': tmdbIds});
  ///   await ApiService().post('/users/me/favorites/batch', {'tmdb_ids': tmdbIds});
  static Future<void> saveOnboardingMovies(List<int> tmdbIds) async {
    await Future.delayed(const Duration(milliseconds: 500));
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
