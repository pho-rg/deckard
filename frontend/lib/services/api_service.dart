import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  /// Base de l'API. Tous les routers backend sont montés sous /api/v1.
  ///
  /// Injectée à la compilation via --dart-define pour ne pas coder en dur
  /// l'URL (qui change selon l'environnement : local, AWS, etc.) :
  ///
  ///   flutter run   --dart-define=API_BASE_URL=http://localhost:8000/api/v1
  ///   flutter build --dart-define=API_BASE_URL=`https://dns-alb-aws/api/v1`
  ///
  /// Défaut = dev local (web/Chrome). Pour un émulateur Android, utiliser
  /// http://10.0.2.2:8000/api/v1.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  // Renseigné après login : ApiService.token = response['access_token']
  static String? token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers,
    );
    return _handle(response);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers,
      body: json.encode(body),
    );
    return _handle(response);
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers,
      body: json.encode(body),
    );
    return _handle(response);
  }

  /// Vérifie le statut HTTP et décode le corps JSON.
  /// En cas d'erreur, remonte le message `detail` renvoyé par FastAPI.
  dynamic _handle(http.Response response) {
    final status = response.statusCode;

    if (status >= 200 && status < 300) {
      if (response.body.isEmpty) return null; // ex: 204 No Content
      return json.decode(utf8.decode(response.bodyBytes));
    }

    final message = _extractDetail(response);
    if (status == 401 || status == 403) {
      throw ApiException(message, statusCode: status, isAuth: true);
    }
    throw ApiException(message, statusCode: status);
  }

  /// FastAPI renvoie {"detail": "..."} (string) ou une liste d'erreurs de
  /// validation (422). On extrait un message lisible dans les deux cas.
  String _extractDetail(http.Response response) {
    try {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      final detail = decoded is Map ? decoded['detail'] : null;
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          return first['msg'].toString();
        }
      }
    } catch (_) {
      // corps non-JSON
    }
    return 'Request failed (${response.statusCode})';
  }
}

/// Exception applicative portant le message lisible renvoyé par l'API.
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final bool isAuth;

  ApiException(this.message, {required this.statusCode, this.isAuth = false});

  @override
  String toString() => message;
}

/// Conservé pour compatibilité avec le code existant.
class AuthException extends ApiException {
  AuthException(super.message) : super(statusCode: 401, isAuth: true);
}
