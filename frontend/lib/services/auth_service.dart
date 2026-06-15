import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  /// Log in with email + password.
  /// Mock: accepts any non-empty credentials and stores a fake token.
  /// TODO: replace body with real API call:
  ///   final data = await ApiService().post('/auth/login', {'email': email, 'password': password});
  ///   final token = data['access_token'] as String;
  static Future<void> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (email.trim().isEmpty || password.isEmpty) {
      throw Exception('Email et mot de passe requis.');
    }

    // Mock token — replace with data['access_token'] from real API
    const mockToken = 'mock-token-abc123';
    await _storage.write(key: _tokenKey, value: mockToken);
    ApiService.token = mockToken;
  }

  /// Clear the stored token and reset the API service.
  static Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    ApiService.token = null;
  }

  /// Called on app start. Returns true if a valid token was found.
  static Future<bool> tryRestoreToken() async {
    final token = await _storage.read(key: _tokenKey);
    if (token != null) {
      ApiService.token = token;
      return true;
    }
    return false;
  }
}
