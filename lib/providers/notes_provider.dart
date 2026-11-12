import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/note_model.dart';
import '../models/note_video_model.dart';
import '../models/nfc_unlock_model.dart';
import '../models/video_preview_model.dart';
import '../services/note_client_crypto.dart';
import '../services/notes_service.dart';
import '../services/guest_notes_store.dart';

class NotesProvider extends ChangeNotifier {
  static const hiddenSessionDuration = Duration(minutes: 10);

  final _service = NotesService();
  final GuestNotesStore _guestStore;
  final List<Note> _guestNotes = [];
  Future<void> _guestWrites = Future<void>.value();
  Future<void> _serializeGuestWrite(Future<void> Function() action) {
    final result = _guestWrites.then((_) => action());
    _guestWrites =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  bool _guestMode = false;
  bool _guestLoading = false;
  String? guestLoadError;
  bool get isGuestMode => _guestMode;
  bool get guestLoading => _guestLoading;

  Future<void> setGuestMode(bool enabled) async {
    _guestMode = enabled;
    if (!enabled) {
      notifyListeners();
      return;
    }
    _guestLoading = true;
    guestLoadError = null;
    _hiddenSessionTimer?.cancel();
    _hiddenAccessToken = null;
    _hiddenKeyId = null;
    _hiddenSessionExpiresAt = null;
    _loadedHiddenAccessToken = null;
    notifyListeners();
    try {
      await _guestWrites;
      final loaded = await _guestStore.load();
      _guestNotes
        ..clear()
        ..addAll(loaded);
    } catch (error) {
      guestLoadError = error.toString();
    } finally {
      _guestLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveGuestNote(Note note, {bool creating = false}) =>
      _serializeGuestWrite(() async {
        if (guestLoadError != null || _guestLoading) {
          throw StateError('Локальное хранилище недоступно');
        }
        final now = DateTime.now();
        final prepared = await _guestStore.prepare(note.copyWith(
          id: creating ? 'guest_${now.microsecondsSinceEpoch}' : note.id,
          createdAt: note.createdAt ?? now,
          updatedAt: now,
        ));
        final next = List<Note>.of(_guestNotes);
        final index = next.indexWhere((item) => item.id == prepared.id);
        if (index == -1) {
          next.insert(0, prepared);
        } else {
          next[index] = prepared;
        }
        await _guestStore.write(next);
        _guestNotes
          ..clear()
          ..addAll(next);
        notifyListeners();
      });

  final List<Note> _notes = [];
  bool _loadingServerNotes = false;
  bool _unlockingHiddenNotes = false;
  String? _loadedToken;
  String? _loadedHiddenAccessToken;
  String? _hiddenAccessToken;
  String? _hiddenKeyId;
  DateTime? _hiddenSessionExpiresAt;
  Timer? _hiddenSessionTimer;

  List<Note> get notes => List.unmodifiable(
        (_guestMode ? _guestNotes : _notes)
            .where((note) => !note.isHidden || isHiddenNotesVisible),
      );
  bool get loadingServerNotes => _loadingServerNotes;
  bool get unlockingHiddenNotes => _unlockingHiddenNotes;
  bool get isHiddenNotesVisible =>
      _hiddenAccessToken != null &&
      _hiddenSessionExpiresAt != null &&
      DateTime.now().isBefore(_hiddenSessionExpiresAt!);
  Duration get hiddenSessionRemaining {
    final expiresAt = _hiddenSessionExpiresAt;
    if (expiresAt == null || !isHiddenNotesVisible) return Duration.zero;
    return expiresAt.difference(DateTime.now());
  }

  String? get activeHiddenKeyId {
    if (!isHiddenNotesVisible) return null;
    return _hiddenKeyId;
  }

  bool shouldLoadServerNotes(String? token) {
    return !_guestMode &&
        token != null &&
        token.isNotEmpty &&
        !_loadingServerNotes &&
        (_loadedToken != token ||
            _loadedHiddenAccessToken != _activeHiddenAccessToken);
  }

  NotesProvider({GuestNotesStore? guestStore})
      : _guestStore = guestStore ?? GuestNotesStore() {
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
    final hiddenAccessToken = _activeHiddenAccessToken;
    if (!force &&
        _loadedToken == token &&
        _loadedHiddenAccessToken == hiddenAccessToken) {
      return;
    }

    _loadingServerNotes = true;
    _loadedToken = token;
    _loadedHiddenAccessToken = hiddenAccessToken;
    notifyListeners();

    try {
      final serverNotes = await _service.fetchNotes(
        token: token,
        hiddenAccessToken: hiddenAccessToken,
      );
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

  Future<void> unlockHiddenNotes({
    required NfcUnlockPayload payload,
    required String? token,
  }) async {
    if (token == null || token.isEmpty) {
      throw Exception('Необходима авторизация');
    }

    _unlockingHiddenNotes = true;
    notifyListeners();
    try {
      final result = await _service.unlockHiddenNotes(
        token: token,
        tagId: payload.tagId,
        secret: payload.secret,
      );
      if (result.hiddenAccessToken.isEmpty) {
        throw Exception('Backend не вернул hidden-token');
      }

      final serverTTL = Duration(seconds: result.expiresInSeconds);
      final ttl =
          serverTTL <= Duration.zero || serverTTL > hiddenSessionDuration
              ? hiddenSessionDuration
              : serverTTL;
      _hiddenAccessToken = result.hiddenAccessToken;
      _hiddenKeyId = result.keyId;
      _hiddenSessionExpiresAt = DateTime.now().add(ttl);
      _restartHiddenSessionTimer(ttl);

      await loadServerNotes(token: token, force: true);
    } finally {
      _unlockingHiddenNotes = false;
      notifyListeners();
    }
  }

  Future<void> lockHiddenNotes({String? token}) async {
    _hiddenSessionTimer?.cancel();
    _hiddenSessionTimer = null;
    _hiddenAccessToken = null;
    _hiddenKeyId = null;
    _hiddenSessionExpiresAt = null;
    _loadedHiddenAccessToken = null;
    _notes.removeWhere((note) => note.isHidden);
    notifyListeners();

    if (token != null && token.isNotEmpty) {
      await loadServerNotes(token: token, force: true);
    }
  }

  String? get _activeHiddenAccessToken {
    if (!isHiddenNotesVisible) return null;
    return _hiddenAccessToken;
  }

  void _restartHiddenSessionTimer(Duration ttl) {
    _hiddenSessionTimer?.cancel();
    _hiddenSessionTimer = Timer(ttl, () {
      unawaited(lockHiddenNotes());
    });
  }

  Future<void> addNote(
    Note note, {
    required int? userId,
    required String? token,
  }) async {
    if (_guestMode) {
      await _saveGuestNote(note, creating: true);
      return;
    }
    if (note.id.startsWith('guest_')) {
      throw StateError('Локальные заметки не синхронизируются');
    }
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

  Future<VideoPreview> previewVideoUrl({
    required String url,
    required String? token,
  }) {
    if (token == null || token.isEmpty) {
      throw Exception('Необходима авторизация');
    }
    return _service.previewVideoUrl(url: url, token: token);
  }

  Future<NoteVideo> addVideoFromUrl({
    required Note note,
    required String url,
    required String? token,
  }) async {
    if (token == null || token.isEmpty) {
      throw Exception('Необходима авторизация');
    }
    if (note.isPending) {
      throw Exception('Сначала синхронизируйте заметку');
    }
    if (note.hasProtection) {
      throw Exception('Видео для защищённых заметок пока не поддерживается');
    }

    final video = await _service.importVideoUrl(
      url: url,
      token: token,
      noteId: note.id,
      isProtected: false,
    );

    final index = _notes.indexWhere((item) => item.id == note.id);
    if (index != -1) {
      final current = _notes[index];
      _notes[index] = current.copyWith(
        videos: [...current.videos, video],
        isVideo: true,
      );
      notifyListeners();
    }
    return video;
  }

  Future<void> deleteVideo({
    required Note note,
    required String videoId,
    required String? token,
  }) async {
    if (token == null || token.isEmpty) {
      throw Exception('Необходима авторизация');
    }
    if (note.isPending) {
      throw Exception('Сначала синхронизируйте заметку');
    }

    await _service.deleteVideo(id: videoId, token: token);

    final index = _notes.indexWhere((item) => item.id == note.id);
    if (index != -1) {
      final current = _notes[index];
      final videos =
          current.videos.where((video) => video.id != videoId).toList();
      _notes[index] = current.copyWith(
        videos: videos,
        isVideo: videos.isNotEmpty,
      );
      notifyListeners();
    }
  }

  Future<void> _saveLocally(Note note) async {
    final noteToSave = note.hasProtection && note.protectionPassword != null
        ? await encryptNoteForClient(note, note.protectionPassword!)
        : note;
    final pending = noteToSave.copyWith(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      createdAt: note.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
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
    if (_guestMode || note.id.startsWith('guest_')) {
      throw StateError('Локальные заметки не синхронизируются');
    }
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
    if (_guestMode) {
      await _saveGuestNote(updated);
      return;
    }
    if (updated.id.startsWith('guest_')) {
      throw StateError('Локальные заметки не синхронизируются');
    }
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
    if (_guestMode) {
      try {
        final unlocked = await decryptNoteFromClient(note, password);
        return unlocked.copyWith(protectionPassword: password);
      } catch (_) {
        throw Exception('Неверный пароль');
      }
    }

    if (note.protectionPassword != null &&
        note.protectionPassword!.isNotEmpty) {
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
    if (_guestMode) {
      await _serializeGuestWrite(() async {
        final next = _guestNotes.where((note) => note.id != id).toList();
        await _guestStore.write(next);
        _guestNotes
          ..clear()
          ..addAll(next);
        notifyListeners();
        await _guestStore.removeMedia(id);
      });
      return;
    }

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

  @override
  void dispose() {
    _hiddenSessionTimer?.cancel();
    super.dispose();
  }
}
