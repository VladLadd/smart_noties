import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

final String _baseUrl = apiBaseUrl;
const String _tokenKey = 'auth_token';
const String _userIdKey = 'user_id';

class AuthUser {
  final String id;
  final String name;
  final String email;

  const AuthUser({required this.id, required this.name, required this.email});

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    // ignore: avoid_print
    print('[AUTH] AuthUser.fromJson keys=${json.keys.toList()} values=$json');
    final rawId = json['id'] ?? json['userId'] ?? json['user_id'];
    return AuthUser(
      id: rawId?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
    );
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  Future<({String token, AuthUser user})> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/users'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': name, 'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));

    return _parseAuthResponse(response);
  }

  Future<({String token, AuthUser user})> login({
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));

    return _parseAuthResponse(response);
  }

  ({String token, AuthUser user}) _parseAuthResponse(http.Response response) {
    // ignore: avoid_print
    print('[AUTH] status=${response.statusCode} body=${response.body}');

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw AuthException(
        'Сервер вернул неожиданный ответ (${response.statusCode}):\n${response.body}',
      );
    }

    if (response.statusCode >= 400) {
      final msg = body['message'] ?? body['error'] ?? 'Ошибка сервера';
      throw AuthException(msg.toString());
    }
    final token = body['token'] as String? ?? '';
    final user = AuthUser.fromJson(body['user'] as Map<String, dynamic>? ?? body);
    return (token: token, user: user);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> logout(String token) async {
    try {
      await http
          .post(
            Uri.parse('$_baseUrl/api/auth/logout'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // ignore network errors — clear local session regardless
    }
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }

  Future<void> saveUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, userId);
  }

  Future<int?> loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }
}
