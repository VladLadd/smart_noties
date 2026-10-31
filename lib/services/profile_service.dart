import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'api_config.dart';

class ProfileService {
  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
      };

  Future<ProfileSnapshot> fetchProfile({required String token}) async {
    final response = await http
        .get(
          Uri.parse('$apiBaseUrl/api/profile'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));
    final json = _decode(response);
    final value = json['avatarUrl']?.toString() ?? '';
    return ProfileSnapshot(
      avatarUrl: value.isEmpty ? null : value,
      storageUsedBytes: _readInt(json['storageUsedBytes']),
      storageLimitBytes: _readInt(json['storageLimitBytes']),
    );
  }

  Future<String> uploadAvatar({
    required String token,
    required XFile file,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$apiBaseUrl/api/profile/avatar'),
    )
      ..headers.addAll(_headers(token))
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          await file.readAsBytes(),
          filename: file.name,
        ),
      );
    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);
    final json = _decode(response);
    final value = json['avatarUrl']?.toString() ?? '';
    if (value.isEmpty) throw const ProfileException('Сервер не вернул аватар');
    return value;
  }

  Future<void> deleteAvatar({required String token}) async {
    final response = await http
        .delete(
          Uri.parse('$apiBaseUrl/api/profile/avatar'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));
    _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> json;
    try {
      json = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw ProfileException(
        'Сервер вернул неожиданный ответ (${response.statusCode})',
      );
    }
    if (response.statusCode >= 400) {
      final message = json['message'] ?? json['error'] ?? 'Ошибка сервера';
      throw ProfileException(message.toString());
    }
    return json;
  }

  int _readInt(dynamic value) => value is num ? value.toInt() : 0;
}

class ProfileSnapshot {
  final String? avatarUrl;
  final int storageUsedBytes;
  final int storageLimitBytes;

  const ProfileSnapshot({
    required this.avatarUrl,
    required this.storageUsedBytes,
    required this.storageLimitBytes,
  });
}

class ProfileException implements Exception {
  final String message;

  const ProfileException(this.message);

  @override
  String toString() => message;
}
