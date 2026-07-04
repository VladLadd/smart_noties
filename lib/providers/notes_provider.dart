import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../services/notes_service.dart';

class NotesProvider extends ChangeNotifier {
  final _service = NotesService();
  final List<Note> _notes = [];

  List<Note> get notes => List.unmodifiable(_notes);

  NotesProvider() {
    _loadPendingNotes();
  }

  Future<void> _loadPendingNotes() async {
    final pending = await _service.loadPendingNotes();
    if (pending.isEmpty) return;
    _notes.addAll(pending);
    notifyListeners();
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
  Future<String> uploadVoice(File file, String token) =>
      _service.uploadVoice(file: file, token: token);

  Future<void> _saveLocally(Note note) async {
    final pending = note.copyWith(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      isPending: true,
    );
    _notes.insert(0, pending);
    notifyListeners();
    await _service.savePendingNotes(_notes.toList());
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
    await _service.savePendingNotes(_notes.toList());
  }

  void updateNote(Note updated) {
    final index = _notes.indexWhere((n) => n.id == updated.id);
    if (index != -1) {
      _notes[index] = updated;
      notifyListeners();
    }
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
    await _service.savePendingNotes(_notes.toList());
  }
}
