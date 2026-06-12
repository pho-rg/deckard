import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:8000';

  // Set after login: ApiService.token = response.accessToken
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
    _checkStatus(response);
    return json.decode(response.body);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers,
      body: json.encode(body),
    );
    _checkStatus(response);
    return json.decode(response.body);
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers,
      body: json.encode(body),
    );
    _checkStatus(response);
    return json.decode(response.body);
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode == 401) throw AuthException('Not authenticated');
    if (response.statusCode == 403) throw AuthException('Access denied');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Request failed: ${response.statusCode}');
    }
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}
