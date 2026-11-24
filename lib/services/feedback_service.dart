import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feedback_model.dart';
import 'api_config.dart';

class FeedbackException implements Exception {
  final String code;
  const FeedbackException(this.code);
  @override
  String toString() => code;
}

class FeedbackService {
  static final shared = FeedbackService();
  final http.Client? client;
  Future<String>? _guestCredential;
  FeedbackService({this.client});
  static String newRequestId() {
    final random = Random.secure();
    final b = List.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  static String get platform => kIsWeb
      ? 'web'
      : defaultTargetPlatform == TargetPlatform.fuchsia
          ? 'unknown'
          : defaultTargetPlatform.name.toLowerCase();
  Future<String> _guestToken() => _guestCredential ??= _loadGuestToken();
  Future<String> _loadGuestToken() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('feedback_guest_token');
    if (saved != null && RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(saved)) {
      return saved;
    }
    final random = Random.secure();
    final token = base64UrlEncode(List.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    await prefs.setString('feedback_guest_token', token);
    return token;
  }

  Future<Map<String, dynamic>> _request(String path,
      {String? token,
      String method = 'GET',
      Map<String, dynamic>? body}) async {
    final transport = client ?? http.Client();
    try {
      final request = http.Request(method, Uri.parse('$apiBaseUrl$path'))
        ..headers['Content-Type'] = 'application/json';
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      } else {
        request.headers['X-Feedback-Token'] = await _guestToken();
      }
      if (body != null) request.body = jsonEncode(body);
      final response = await transport
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 20));
      Map<String, dynamic>? value;
      try {
        value = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      } catch (_) {
        throw const FeedbackException('feedback_unavailable');
      }
      if (response.statusCode >= 400) {
        throw FeedbackException(
            value['error'] as String? ?? 'feedback_unavailable');
      }
      return value;
    } on FeedbackException {
      rethrow;
    } catch (_) {
      throw const FeedbackException('feedback_unavailable');
    } finally {
      if (client == null) transport.close();
    }
  }

  String _base(bool admin) => admin ? '/api/admin/feedback' : '/api/feedback';
  Future<FeedbackPage> list(
      {String? token,
      bool admin = false,
      String query = '',
      String status = '',
      String category = '',
      int offset = 0}) async {
    final params = Uri(queryParameters: {
      if (query.isNotEmpty) 'q': query,
      if (status.isNotEmpty) 'status': status,
      if (category.isNotEmpty) 'category': category,
      'offset': '$offset'
    }).query;
    return FeedbackPage.fromJson(
        await _request('${_base(admin)}?$params', token: token));
  }

  Future<FeedbackThread> read(String id,
          {String? token, bool admin = false}) async =>
      FeedbackThread.fromJson(await _request(
          '${_base(admin)}/${Uri.encodeComponent(id)}',
          token: token));
  Future<FeedbackThread> create(
          {String? token,
          required String requestId,
          required String category,
          required String subject,
          required String body,
          String contactEmail = '',
          String locale = 'ru'}) async =>
      FeedbackThread.fromJson(
          await _request('/api/feedback', token: token, method: 'POST', body: {
        'requestId': requestId,
        'category': category,
        'subject': subject,
        'body': body,
        'contactEmail': contactEmail,
        'platform': platform,
        'locale': locale
      }));
  Future<FeedbackThread> reply(String id,
          {String? token,
          bool admin = false,
          required String requestId,
          required String body}) async =>
      FeedbackThread.fromJson(await _request(
          '${_base(admin)}/${Uri.encodeComponent(id)}/messages',
          token: token,
          method: 'POST',
          body: {'requestId': requestId, 'body': body}));
  Future<FeedbackThread> setStatus(String id, String status,
          {required String token}) async =>
      FeedbackThread.fromJson(await _request(
          '/api/admin/feedback/${Uri.encodeComponent(id)}',
          token: token,
          method: 'PATCH',
          body: {'status': status}));
}
