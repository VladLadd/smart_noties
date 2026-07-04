import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

enum AuthStatus { checking, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final _service = AuthService();

  AuthStatus status = AuthStatus.checking;
  AuthUser? user;
  String? token;
  int? userId;

  AuthProvider() {
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final savedToken = await _service.loadToken();
    if (savedToken == null || savedToken.isEmpty) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    token = savedToken;
    userId = await _service.loadUserId() ?? _extractUserIdFromJwt(savedToken);
    // ignore: avoid_print
    print('[AUTH] auto-login: userId=$userId token=${savedToken.substring(0, 20)}...');

    if (userId != null) {
      await _service.saveUserId(userId!);
    }

    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _service.register(name: name, email: email, password: password);
    // Бэкенд /api/users не возвращает токен — сразу логинимся теми же
    // учётными данными, чтобы после регистрации юзер был авторизован.
    await login(email: email, password: password);
  }

  Future<void> login({required String email, required String password}) async {
    final result = await _service.login(email: email, password: password);
    await _persist(result);
  }

  Future<void> logout() async {
    if (token != null) await _service.logout(token!);
    await _service.clearToken();
    token = null;
    userId = null;
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> _persist(({String token, AuthUser user}) result) async {
    token = result.token;
    user = result.user;
    userId = int.tryParse(result.user.id) ?? _extractUserIdFromJwt(result.token);
    // ignore: avoid_print
    print('[AUTH] _persist: raw id="${result.user.id}" parsed userId=$userId');
    await _service.saveToken(result.token);
    if (userId != null) await _service.saveUserId(userId!);
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  // Декодирует payload JWT и ищет userId/id/sub без сторонних пакетов.
  int? _extractUserIdFromJwt(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      // ignore: avoid_print
      print('[AUTH] JWT payload=$json');
      final raw = json['id'] ?? json['userId'] ?? json['user_id'] ?? json['sub'];
      if (raw == null) return null;
      return raw is int ? raw : int.tryParse(raw.toString());
    } catch (e) {
      // ignore: avoid_print
      print('[AUTH] JWT parse error: $e');
      return null;
    }
  }
}
