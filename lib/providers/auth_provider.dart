import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

enum AuthStatus { checking, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  static const _sessionCheckInterval = Duration(seconds: 15);
  final _service = AuthService();
  Timer? _sessionTimer;
  bool _sessionCheckInProgress = false;

  AuthStatus status = AuthStatus.checking;
  AuthUser? user;
  String? token;
  int? userId;
  String? email;
  String role = 'user';
  String? forcedLogoutCode;

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
    email = _extractEmailFromJwt(savedToken);
    role = _extractRoleFromJwt(savedToken) ?? 'user';
    // ignore: avoid_print
    print(
        '[AUTH] auto-login: userId=$userId token=${savedToken.substring(0, 20)}...');

    if (userId != null) {
      await _service.saveUserId(userId!);
    }

    status = AuthStatus.authenticated;
    notifyListeners();
    _startSessionMonitor();
  }

  Future<void> requestEmailRegistrationCode({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    await _service.requestEmailRegistrationCode(
      name: name,
      email: email,
      password: password,
      phone: phone,
    );
  }

  Future<void> verifyEmailRegistrationCode({
    required String email,
    required String code,
  }) async {
    final result = await _service.verifyEmailRegistrationCode(
      email: email,
      code: code,
    );
    await _persist(result);
  }

  Future<void> login({required String email, required String password}) async {
    final result = await _service.login(email: email, password: password);
    await _persist(result);
  }

  Future<void> requestPhoneCode({required String phone}) async {
    await _service.requestPhoneCode(phone: phone);
  }

  Future<void> verifyPhoneCode({
    required String phone,
    required String code,
  }) async {
    final result = await _service.verifyPhoneCode(phone: phone, code: code);
    await _persist(result);
  }

  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    await _service.resetPassword(email: email, newPassword: newPassword);
  }

  Future<void> logout() async {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    if (token != null) await _service.logout(token!);
    await _service.clearToken();
    token = null;
    userId = null;
    user = null;
    email = null;
    role = 'user';
    forcedLogoutCode = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void updateProfileEmail(String value) {
    email = value;
    notifyListeners();
  }

  Future<void> _persist(({String token, AuthUser user}) result) async {
    token = result.token;
    user = result.user;
    userId =
        int.tryParse(result.user.id) ?? _extractUserIdFromJwt(result.token);
    email = result.user.email.isNotEmpty
        ? result.user.email
        : _extractEmailFromJwt(result.token);
    role = result.user.role.isNotEmpty
        ? result.user.role
        : (_extractRoleFromJwt(result.token) ?? 'user');
    // ignore: avoid_print
    print('[AUTH] _persist: raw id="${result.user.id}" parsed userId=$userId');
    await _service.saveToken(result.token);
    if (userId != null) await _service.saveUserId(userId!);
    status = AuthStatus.authenticated;
    forcedLogoutCode = null;
    notifyListeners();
    _startSessionMonitor();
  }

  void _startSessionMonitor() {
    _sessionTimer?.cancel();
    unawaited(_checkSession());
    _sessionTimer = Timer.periodic(_sessionCheckInterval, (_) {
      unawaited(_checkSession());
    });
  }

  Future<void> _checkSession() async {
    final currentToken = token;
    if (currentToken == null ||
        status != AuthStatus.authenticated ||
        _sessionCheckInProgress) {
      return;
    }
    _sessionCheckInProgress = true;
    try {
      await _service.validateSession(currentToken);
    } on AuthException catch (error) {
      if (token != currentToken) return;
      if (error.code == 'account_blocked' || error.statusCode == 401) {
        await _clearLocalSession(
          noticeCode:
              error.code == 'account_blocked' ? 'account_blocked' : null,
        );
      }
    } catch (_) {
      // A temporary network problem does not terminate a valid local session.
    } finally {
      _sessionCheckInProgress = false;
    }
  }

  Future<void> _clearLocalSession({String? noticeCode}) async {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    await _service.clearToken();
    token = null;
    userId = null;
    user = null;
    email = null;
    role = 'user';
    forcedLogoutCode = noticeCode;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearForcedLogoutNotice() {
    if (forcedLogoutCode == null) return;
    forcedLogoutCode = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
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
      final raw =
          json['id'] ?? json['userId'] ?? json['user_id'] ?? json['sub'];
      if (raw == null) return null;
      return raw is int ? raw : int.tryParse(raw.toString());
    } catch (e) {
      // ignore: avoid_print
      print('[AUTH] JWT parse error: $e');
      return null;
    }
  }

  // Достаёт email из payload JWT (бэкенд кладёт его в claims).
  String? _extractEmailFromJwt(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final raw = json['email'];
      return raw is String && raw.isNotEmpty ? raw : null;
    } catch (e) {
      // ignore: avoid_print
      print('[AUTH] JWT email parse error: $e');
      return null;
    }
  }

  String? _extractRoleFromJwt(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final raw = json['role'];
      return raw is String && raw.isNotEmpty ? raw : null;
    } catch (e) {
      // ignore: avoid_print
      print('[AUTH] JWT role parse error: $e');
      return null;
    }
  }
}
