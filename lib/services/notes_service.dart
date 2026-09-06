import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_model.dart';
import '../models/note_video_model.dart';
import '../models/nfc_unlock_model.dart';
import '../models/video_preview_model.dart';
import 'api_config.dart';
import 'note_client_crypto.dart';

final String _baseUrl = apiBaseUrl;
const String _pendingNotesKey = 'pending_notes';

class NotesService {
  Future<List<Note>> fetchNotes({
    required String token,
    String? hiddenAccessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/notes'),
      headers: {
        'Authorization': 'Bearer $token',
        if (hiddenAccessToken != null && hiddenAccessToken.isNotEmpty)
          'X-Hidden-Access': hiddenAccessToken,
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = body['message'] ?? body['error'] ?? 'Ошибка сервера';
      throw Exception(msg.toString());
    }

    final list = jsonDecode(response.body) as List<dynamic>;
    final notes =
        list.map((e) => _noteFromJson(e as Map<String, dynamic>)).toList();
    // ignore: avoid_print
    print(
      '[NOTES] GET /api/notes '
      'status=${response.statusCode} count=${notes.length}',
    );
    return notes;
  }

  Future<Note> createNote({
    required Note note,
    required int userId,
    required String token,
  }) async {
    final password = note.protectionPassword ?? '';
    final requestNote = await encryptNoteForClient(note, password);
    final requestBody = {
      'title': requestNote.title,
      'body': requestNote.body,
      'userId': userId,
      'color': requestNote.color.toARGB32(),
      'isVoice': requestNote.isVoice,
      'isVideo': requestNote.isVideo,
      'imagePath': requestNote.imagePath ?? '',
      'photoPaths': requestNote.photoPaths,
      'voicePath': requestNote.voicePath ?? '',
      'isProtected': note.hasProtection,
      'isHidden': note.isHidden,
      'hiddenKeyId': note.hiddenKeyId ?? '',
      'protectionPassword': password,
    };
    final logBody = Map<String, dynamic>.from(requestBody);
    if (note.hasProtection) {
      logBody['title'] = '***';
      logBody['body'] = '***';
    }
    if ((logBody['protectionPassword'] as String).isNotEmpty) {
      logBody['protectionPassword'] = '***';
    }
    // ignore: avoid_print
    print('[NOTES] POST /api/notes body=$logBody');

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
    print('[NOTES] status=${response.statusCode}');

    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = body['message'] ?? body['error'] ?? 'Ошибка сервера';
      throw Exception(msg.toString());
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final created = _noteFromJson(json);
    return decryptNoteFromClient(created, password);
  }

  Future<Note> updateNote({
    required Note note,
    required String token,
  }) async {
    final password = note.protectionPassword ?? '';
    final requestNote = await encryptNoteForClient(note, password);
    final requestBody = {
      'title': requestNote.title,
      'body': requestNote.body,
      'color': requestNote.color.toARGB32(),
      'isVoice': requestNote.isVoice,
      'isVideo': requestNote.isVideo,
      'imagePath': requestNote.imagePath ?? '',
      'photoPaths': requestNote.photoPaths,
      'voicePath': requestNote.voicePath ?? '',
      'isProtected': note.hasProtection,
      'isHidden': note.isHidden,
      'hiddenKeyId': note.hiddenKeyId ?? '',
      'protectionPassword': password,
    };
    final logBody = Map<String, dynamic>.from(requestBody);
    if (note.hasProtection) {
      logBody['title'] = '***';
      logBody['body'] = '***';
    }
    if ((logBody['protectionPassword'] as String).isNotEmpty) {
      logBody['protectionPassword'] = '***';
    }
    // ignore: avoid_print
    print('[NOTES] PATCH /api/notes/${note.id} body=$logBody');

    final response = await http
        .patch(
          Uri.parse('$_baseUrl/api/notes/${note.id}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 15));

    // ignore: avoid_print
    print('[NOTES] update status=${response.statusCode}');

    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = body['message'] ?? body['error'] ?? 'Ошибка сервера';
      throw Exception(msg.toString());
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final updated = _noteFromJson(json);
    return decryptNoteFromClient(updated, password);
  }

  Future<Note> verifyNotePassword({
    required String id,
    required String password,
    required String token,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/notes/$id/verify-password'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'password': password}),
        )
        .timeout(const Duration(seconds: 15));

    // ignore: avoid_print
    print(
      '[NOTES] verify password status=${response.statusCode} body=${response.body}',
    );

    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = body['message'] ?? body['error'] ?? 'Неверный пароль';
      throw Exception(msg.toString());
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final unlocked = await decryptNoteFromClient(_noteFromJson(json), password);
    return unlocked.copyWith(protectionPassword: password);
  }

  Future<void> updateNoteProtection({
    required String id,
    required bool isProtected,
    required String? password,
    required String token,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$_baseUrl/api/notes/$id/protection'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'isProtected': isProtected,
            'password': password ?? '',
          }),
        )
        .timeout(const Duration(seconds: 15));

    // ignore: avoid_print
    print(
      '[NOTES] protection status=${response.statusCode} body=${response.body}',
    );

    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = body['message'] ?? body['error'] ?? 'Ошибка сервера';
      if (msg.toString().toLowerCase().contains('method not allowed')) {
        throw Exception('Backend не поддерживает обновление защиты');
      }
      throw Exception(msg.toString());
    }
  }

  Future<VideoPreview> previewVideoUrl({
    required String url,
    required String token,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/video/preview'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'url': url}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(response, 'Не удалось получить preview'));
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return VideoPreview.fromJson(json);
  }

  Future<NoteVideo> importVideoUrl({
    required String url,
    required String token,
    String? noteId,
    bool isProtected = false,
    String? password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/video/import'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'url': url,
            'noteId': noteId ?? '',
            'isProtected': isProtected,
            'password': password ?? '',
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(response, 'Не удалось добавить видео'));
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return NoteVideo.fromJson(json);
  }

  Future<NfcUnlockResult> unlockHiddenNotes({
    required String token,
    required String tagId,
    required String secret,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/nfc/unlock'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'tagId': tagId, 'secret': secret}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      throw Exception(
          _errorMessage(response, 'Не удалось открыть скрытые заметки'));
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return NfcUnlockResult.fromJson(json);
  }

  Future<void> deleteVideo({
    required String id,
    required String token,
  }) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/video/$id'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(response, 'Не удалось удалить видео'));
    }
  }

  /// Загружает аудио-файл голосовой заметки на сервер и возвращает
  /// относительный URL вида `/uploads/voice/<...>`.
  Future<String> uploadVoice({
    required File file,
    required String token,
    String? mediaPassword,
  }) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/upload/voice'))
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(await http.MultipartFile.fromPath('file', file.path));
    _applyMediaProtection(request, mediaPassword);

    final streamed = await request.send().timeout(const Duration(seconds: 30));
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

  /// Загружает изображение на сервер и возвращает защищённый URL
  /// вида `/api/image/<userId>/<file>`.
  Future<String> uploadImage({
    required File file,
    required String token,
    String? mediaPassword,
  }) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/upload/image'))
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(await http.MultipartFile.fromPath('file', file.path));
    _applyMediaProtection(request, mediaPassword);

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);

    // ignore: avoid_print
    print('[IMAGE] upload status=${response.statusCode} body=${response.body}');

    if (response.statusCode >= 400) {
      throw Exception('Не удалось загрузить изображение '
          '(${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final url = json['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Сервер не вернул URL изображения');
    }
    return url;
  }

  Future<String> uploadPickedImage({
    required XFile file,
    required String token,
    String? mediaPassword,
  }) async {
    final bytes = await file.readAsBytes();
    final request =
        http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/upload/image'))
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: _imageUploadFileName(file),
            ),
          );
    _applyMediaProtection(request, mediaPassword);

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);

    // ignore: avoid_print
    print('[IMAGE] upload status=${response.statusCode} body=${response.body}');

    if (response.statusCode >= 400) {
      throw Exception('Не удалось загрузить изображение '
          '(${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final url = json['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Сервер не вернул URL изображения');
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
    return Note.fromJson({
      ...json,
      'id': json['id']?.toString() ?? '',
      'title': json['title'] ?? '',
      'body': json['body'] ?? '',
      'imagePath': (json['imagePath'] as String?)?.isEmpty == true
          ? null
          : json['imagePath'],
      'photoPaths': _readStringList(json['photoPaths']),
      'voicePath': (json['voicePath'] as String?)?.isEmpty == true
          ? null
          : json['voicePath'],
      'isVoice': json['isVoice'] == true,
      'isVideo': json['isVideo'] == true,
      'color': json['color'] as int? ?? 0xFFFFFFFF,
      'isProtected': _readBool(json['isProtected']),
      'isHidden': _readBool(json['isHidden']),
      'hiddenKeyId': (json['hiddenKeyId'] as String?)?.isEmpty == true
          ? null
          : json['hiddenKeyId'],
    });
  }

  bool _readBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }

  List<String> _readStringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => item?.toString() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  String _imageUploadFileName(XFile file) {
    final name = file.name.trim();
    if (name.isEmpty || !name.contains('.')) return 'image.jpg';
    return name;
  }

  void _applyMediaProtection(
    http.MultipartRequest request,
    String? mediaPassword,
  ) {
    if (mediaPassword == null || mediaPassword.isEmpty) return;
    request.fields['isProtected'] = 'true';
    request.fields['password'] = mediaPassword;
  }

  String _errorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['message'] ?? body['error'] ?? fallback).toString();
    } catch (_) {
      return '$fallback (${response.statusCode})';
    }
  }
}
