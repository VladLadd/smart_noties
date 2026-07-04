import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_model.dart';
import 'api_config.dart';

final String _baseUrl = apiBaseUrl;
const String _pendingNotesKey = 'pending_notes';

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

  /// Загружает аудио-файл голосовой заметки на сервер и возвращает
  /// относительный URL вида `/uploads/voice/<...>`.
  Future<String> uploadVoice({
    required File file,
    required String token,
  }) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/upload/voice'))
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed =
        await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);

    // ignore: avoid_print
    print('[VOICE] upload status=${response.statusCode} body=${response.body}');

    if (response.statusCode >= 400) {
      throw Exception('Не удалось загрузить голосовую заметку '
          '(${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final url = json['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Сервер не вернул URL файла');
    }
    return url;
  }

  /// Удаляет заметку на сервере (вместе со связанным аудио-файлом).
  Future<void> deleteNote({required String id, required String token}) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/notes/$id'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));

    // ignore: avoid_print
    print('[NOTES] DELETE /api/notes/$id status=${response.statusCode}');

    if (response.statusCode >= 400) {
      throw Exception('Не удалось удалить заметку (${response.statusCode})');
    }
  }

  Future<List<Note>> loadPendingNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingNotesKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> savePendingNotes(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = notes.where((n) => n.isPending).toList();
    await prefs.setString(
      _pendingNotesKey,
      jsonEncode(pending.map((n) => n.toJson()).toList()),
    );
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
