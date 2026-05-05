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
    final savedUserId = await _service.loadUserId();
    if (savedToken != null && savedToken.isNotEmpty) {
      token = savedToken;
      userId = savedUserId;
      status = AuthStatus.authenticated;
    } else {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _service.register(name: name, email: email, password: password);
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
    userId = int.tryParse(result.user.id);
    await _service.saveToken(result.token);
    if (userId != null) await _service.saveUserId(userId!);
    status = AuthStatus.authenticated;
    notifyListeners();
  }
}
