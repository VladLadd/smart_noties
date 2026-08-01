import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/note_model.dart';
import '../services/note_client_crypto.dart';
import '../services/notes_service.dart';

class NotesProvider extends ChangeNotifier {
  final _service = NotesService();
  final List<Note> _notes = [];
  bool _loadingServerNotes = false;
  String? _loadedToken;

  List<Note> get notes => List.unmodifiable(_notes);
  bool get loadingServerNotes => _loadingServerNotes;

  bool shouldLoadServerNotes(String? token) {
    return token != null &&
        token.isNotEmpty &&
        !_loadingServerNotes &&
        _loadedToken != token;
  }

  NotesProvider() {
    _loadPendingNotes();
  }

  Future<void> _loadPendingNotes() async {
    final pending = await _service.loadPendingNotes();
    if (pending.isEmpty) return;
    _notes.addAll(pending);
    notifyListeners();
  }

  Future<void> loadServerNotes({
    required String? token,
    bool force = false,
  }) async {
    if (token == null || token.isEmpty) return;
    if (_loadingServerNotes) return;
    if (!force && _loadedToken == token) return;

    _loadingServerNotes = true;
    _loadedToken = token;
    notifyListeners();

    try {
      final serverNotes = await _service.fetchNotes(token: token);
      _notes.removeWhere((note) => !note.isPending);
      _notes.addAll(serverNotes);
      notifyListeners();
    } catch (e) {
      // ignore: avoid_print
      print('[NOTES] load server notes error: $e');
    } finally {
      _loadingServerNotes = false;
      notifyListeners();
    }
  }

  Future<void> addNote(
    Note note, {
    required int? userId,
    required String? token,
  }) async {
    if (userId == null || token == null || token.isEmpty) {
      await _saveLocally(note);
      return;
    }
    try {
      final created = await _service.createNote(
        note: note,
        userId: userId,
        token: token,
      );
      _notes.insert(0, created);
      notifyListeners();
    } catch (e) {
      if (_isOfflineError(e)) {
        await _saveLocally(note);
      } else {
        rethrow;
      }
    }
  }

  /// Заливает локальный аудио-файл на сервер, возвращает относительный URL.
  Future<String> uploadVoice(
    File file,
    String token, {
    String? mediaPassword,
  }) =>
      _service.uploadVoice(
        file: file,
        token: token,
        mediaPassword: mediaPassword,
      );

  /// Заливает локальное изображение на сервер, возвращает относительный URL.
  Future<String> uploadImage(
    File file,
    String token, {
    String? mediaPassword,
  }) =>
      _service.uploadImage(
        file: file,
        token: token,
        mediaPassword: mediaPassword,
      );

  Future<String> uploadPickedImage(
    XFile file,
    String token, {
    String? mediaPassword,
  }) =>
      _service.uploadPickedImage(
        file: file,
        token: token,
        mediaPassword: mediaPassword,
      );

  Future<void> _saveLocally(Note note) async {
    final noteToSave = note.hasProtection && note.protectionPassword != null
        ? await encryptNoteForClient(note, note.protectionPassword!)
        : note;
    final pending = noteToSave.copyWith(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      isPending: true,
    );
    _notes.insert(0, pending);
    notifyListeners();
    await _savePendingNotes();
  }

  Future<void> _savePendingNotes() async {
    final notesForStorage = <Note>[];
    for (final note in _notes) {
      if (note.isPending &&
          note.hasProtection &&
          note.protectionPassword != null &&
          note.protectionPassword!.isNotEmpty) {
        notesForStorage.add(
          await encryptNoteForClient(note, note.protectionPassword!),
        );
      } else {
        notesForStorage.add(note);
      }
    }
    await _service.savePendingNotes(notesForStorage);
  }

  bool _isOfflineError(Object e) {
    if (e is SocketException) return true;
    if (e is TimeoutException) return true;
    if (e is Exception) {
      final msg = e.toString().toLowerCase();
      return msg.contains('timeout') ||
          msg.contains('connection refused') ||
          msg.contains('network') ||
          msg.contains('socket');
    }
    return false;
  }

  Future<void> syncNote(
    Note note, {
    required int userId,
    required String token,
  }) async {
    final created = await _service.createNote(
      note: note,
      userId: userId,
      token: token,
    );
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _notes[index] = created;
      notifyListeners();
    }
    await _savePendingNotes();
  }

  Future<void> updateNote(
    Note updated, {
    required String? token,
  }) async {
    final index = _notes.indexWhere((n) => n.id == updated.id);
    if (index != -1) {
      _notes[index] = updated;
      notifyListeners();
    }
    await _savePendingNotes();

    if (updated.isPending) return;
    if (token == null || token.isEmpty) {
      throw Exception('Необходима авторизация');
    }

    final saved = await _service.updateNote(note: updated, token: token);
    final savedIndex = _notes.indexWhere((n) => n.id == updated.id);
    if (savedIndex != -1) {
      _notes[savedIndex] = saved;
      notifyListeners();
    }
  }

  Future<void> updateNoteProtection(
    Note note, {
    required bool isProtected,
    required String? password,
    required String? token,
  }) async {
    final updated = note.copyWith(
      isProtected: isProtected,
      protectionPassword: isProtected ? password : null,
      clearProtectionPassword: !isProtected,
    );
    await updateNote(updated, token: token);
    await _savePendingNotes();
  }

  Future<Note> verifyNotePassword(
    Note note, {
    required String password,
    required String? token,
  }) async {
    if (!note.hasProtection) return note;

    if (note.protectionPassword != null && note.protectionPassword!.isNotEmpty) {
      if (note.protectionPassword == password) {
        final unlocked = await decryptNoteFromClient(note, password);
        final index = _notes.indexWhere((item) => item.id == note.id);
        if (index != -1) {
          _notes[index] = unlocked.copyWith(protectionPassword: password);
          notifyListeners();
        }
        return unlocked.copyWith(protectionPassword: password);
      }
      throw Exception('Неверный пароль');
    }

    if (note.isPending) {
      throw Exception('Неверный пароль');
    }

    if (token == null || token.isEmpty) {
      throw Exception('Необходима авторизация');
    }

    final unlocked = await _service.verifyNotePassword(
      id: note.id,
      password: password,
      token: token,
    );
    final index = _notes.indexWhere((item) => item.id == note.id);
    if (index != -1) {
      _notes[index] = unlocked;
      notifyListeners();
    }
    return unlocked;
  }

  Future<void> deleteNote(String id, {String? token}) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index == -1) return;
    final note = _notes[index];

    // Серверную заметку (уже синхронизированную) удаляем на бэкенде —
    // там же удалится связанный аудио-файл. Локальные/pending удаляем только тут.
    if (!note.isPending && token != null && token.isNotEmpty) {
      await _service.deleteNote(id: id, token: token);
    }

    _notes.removeAt(index);
    notifyListeners();
    await _savePendingNotes();
  }
}
