import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/note_model.dart';

const String _baseUrl = 'http://localhost:8070';

class NotesService {
  Future<Note> createNote({
    required Note note,
    required int userId,
    required String token,
  }) async {
    final requestBody = {
      'title': note.title,
      'body': note.body,
      'userId': userId,
      'color': note.color.value,
      'isVoice': note.isVoice,
      'isVideo': note.isVideo,
      'imagePath': note.imagePath ?? '',
      'voicePath': note.voicePath ?? '',
    };
    // ignore: avoid_print
    print('[NOTES] POST /api/notes body=$requestBody');

    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/notes'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 15));

    // ignore: avoid_print
    print('[NOTES] status=${response.statusCode} body=${response.body}');

    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = body['message'] ?? body['error'] ?? 'Ошибка сервера';
      throw Exception(msg.toString());
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _noteFromJson(json);
  }

  Note _noteFromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      imagePath: (json['imagePath'] as String?)?.isEmpty == true
          ? null
          : json['imagePath'] as String?,
      voicePath: (json['voicePath'] as String?)?.isEmpty == true
          ? null
          : json['voicePath'] as String?,
      isVoice: json['isVoice'] == true,
      isVideo: json['isVideo'] == true,
      color: Color(json['color'] as int? ?? 0xFFFFFFFF),
    );
  }
}
