import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/admin_user_model.dart';
import '../models/nfc_key_model.dart';
import '../models/nfc_token_request_model.dart';
import 'api_config.dart';

final String _baseUrl = apiBaseUrl;

class NfcAdminException implements Exception {
  final String message;

  const NfcAdminException(this.message);

  @override
  String toString() => message;
}

class NfcAdminService {
  Future<List<NfcKey>> fetchMyKeys({required String token}) async {
    final response = await http
        .get(
          Uri.parse('$_baseUrl/api/nfc/keys'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    final json = _parseResponse(response);
    return _readList(json).map(NfcKey.fromJson).toList();
  }

  Future<NfcKeyCreateResult> createMyKey({
    required String token,
    required String name,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/nfc/keys'),
          headers: _headers(token),
          body: jsonEncode({'name': name}),
        )
        .timeout(const Duration(seconds: 15));

    final json = _parseResponse(response);
    return NfcKeyCreateResult.fromJson(json as Map<String, dynamic>);
  }

  Future<void> revokeMyKey({
    required String token,
    required String keyId,
  }) async {
    final response = await http
        .delete(
          Uri.parse('$_baseUrl/api/nfc/keys/$keyId'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    _parseEmptyResponse(response);
  }

  Future<List<NfcTokenRequest>> fetchMyTokenRequests({
    required String token,
  }) async {
    final response = await http
        .get(
          Uri.parse('$_baseUrl/api/nfc/token-requests'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    final json = _parseResponse(response);
    return _readList(json).map(NfcTokenRequest.fromJson).toList();
  }

  Future<NfcTokenRequest> createMyTokenRequest({
    required String token,
    required String name,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/nfc/token-requests'),
          headers: _headers(token),
          body: jsonEncode({'name': name}),
        )
        .timeout(const Duration(seconds: 15));

    final json = _parseResponse(response);
    return NfcTokenRequest.fromJson(json as Map<String, dynamic>);
  }

  Future<void> consumeMyTokenRequest({
    required String token,
    required String requestId,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/nfc/token-requests/$requestId/consume'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    _parseEmptyResponse(response);
  }

  Future<List<AdminUser>> searchUsers({
    required String token,
    required String query,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/admin/users').replace(
      queryParameters: query.trim().isEmpty ? null : {'query': query.trim()},
    );
    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    final json = _parseResponse(response);
    return _readList(json).map(AdminUser.fromJson).toList();
  }

  Future<List<NfcKey>> fetchUserKeys({
    required String token,
    required int userId,
  }) async {
    final response = await http
        .get(
          Uri.parse('$_baseUrl/api/admin/users/$userId/nfc/keys'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    final json = _parseResponse(response);
    return _readList(json).map(NfcKey.fromJson).toList();
  }

  Future<NfcKeyCreateResult> createUserKey({
    required String token,
    required int userId,
    required String name,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/admin/users/$userId/nfc/keys'),
          headers: _headers(token),
          body: jsonEncode({'name': name}),
        )
        .timeout(const Duration(seconds: 15));

    final json = _parseResponse(response);
    return NfcKeyCreateResult.fromJson(json as Map<String, dynamic>);
  }

  Future<void> revokeUserKey({
    required String token,
    required int userId,
    required String keyId,
  }) async {
    final response = await http
        .delete(
          Uri.parse('$_baseUrl/api/admin/users/$userId/nfc/keys/$keyId'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    _parseEmptyResponse(response);
  }

  Future<List<NfcTokenRequest>> fetchAdminTokenRequests({
    required String token,
    String status = 'pending',
  }) async {
    final uri = Uri.parse('$_baseUrl/api/admin/nfc/token-requests').replace(
      queryParameters: status.trim().isEmpty ? null : {'status': status},
    );
    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    final json = _parseResponse(response);
    return _readList(json).map(NfcTokenRequest.fromJson).toList();
  }

  Future<NfcTokenRequest> approveTokenRequest({
    required String token,
    required String requestId,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/admin/nfc/token-requests/$requestId/approve'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    final json = _parseResponse(response);
    return NfcTokenRequest.fromJson(json as Map<String, dynamic>);
  }

  Future<void> rejectTokenRequest({
    required String token,
    required String requestId,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/admin/nfc/token-requests/$requestId/reject'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    _parseEmptyResponse(response);
  }

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Object _parseResponse(http.Response response) {
    Object json;
    try {
      json = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } on FormatException {
      throw NfcAdminException(
        'Сервер вернул неожиданный ответ (${response.statusCode}):\n${response.body}',
      );
    }

    if (response.statusCode >= 400) {
      final message = json is Map
          ? (json['message'] ?? json['error'] ?? 'Ошибка сервера').toString()
          : 'Ошибка сервера';
      throw NfcAdminException(message);
    }
    return json;
  }

  void _parseEmptyResponse(http.Response response) {
    if (response.statusCode == 204) return;
    _parseResponse(response);
  }

  List<Map<String, dynamic>> _readList(Object json) {
    if (json is! List) return const [];
    return json
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
        .toList();
  }
}
