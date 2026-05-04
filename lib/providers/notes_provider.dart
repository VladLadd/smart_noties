import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../services/notes_service.dart';

class NotesProvider extends ChangeNotifier {
  final _service = NotesService();
  final List<Note> _notes = [];

  List<Note> get notes => List.unmodifiable(_notes);

  Future<void> addNote(
    Note note, {
    required int userId,
    required String token,
  }) async {
    final created = await _service.createNote(
      note: note,
      userId: userId,
      token: token,
    );
    _notes.insert(0, created);
    notifyListeners();
  }

  void updateNote(Note updated) {
    final index = _notes.indexWhere((n) => n.id == updated.id);
    if (index != -1) {
      _notes[index] = updated;
      notifyListeners();
    }
  }

  void deleteNote(String id) {
    _notes.removeWhere((n) => n.id == id);
    notifyListeners();
  }
}
