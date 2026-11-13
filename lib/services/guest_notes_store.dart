import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/note_model.dart';
import 'note_client_crypto.dart';

/// Отдельное хранилище: гостевые заметки не входят в очередь синхронизации.
class GuestNotesStore {
  final Future<Directory> Function()? directoryProvider;
  final String directoryName;
  final String idPrefix;
  GuestNotesStore(
      {this.directoryProvider,
      this.directoryName = 'guest_notes',
      this.idPrefix = 'guest_'});

  bool _validId(String id) =>
      RegExp('^${RegExp.escape(idPrefix)}[0-9]+\$').hasMatch(id);

  Future<Directory> _root() async {
    final base =
        await (directoryProvider?.call() ?? getApplicationSupportDirectory());
    return Directory('${base.path}/$directoryName').create(recursive: true);
  }

  Future<List<Note>> load() async {
    final root = await _root();
    final file = File('${root.path}/notes.json');
    if (!await file.exists()) return [];
    return (jsonDecode(await file.readAsString()) as List)
        .map((value) => Note.fromJson(Map<String, dynamic>.from(value as Map)))
        .toList();
  }

  Future<Note> prepare(Note note) async {
    final root = await _root();
    if (!_validId(note.id)) {
      throw const FormatException(
          'Некорректный идентификатор локальной заметки');
    }
    final dir =
        await Directory('${root.path}/${note.id}').create(recursive: true);
    var sequence = 0;
    Future<String?> copy(String? path) async {
      if (path == null || path.isEmpty) return null;
      if (path.startsWith('assets/')) return path;
      if (path.startsWith('/api/') ||
          path.startsWith('https://') ||
          path.startsWith('http://')) {
        return path;
      }
      if (path.startsWith('${dir.path}/')) return path;
      final source = File(path);
      if (!await source.exists()) {
        throw FileSystemException('Файл вложения не найден', path);
      }
      final name = source.uri.pathSegments.last;
      final target =
          '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${sequence++}_$name';
      return (await source.copy(target)).path;
    }

    final photos = <String>[];
    for (final path in note.photoPaths) {
      photos.add((await copy(path))!);
    }
    final files = <String>[];
    for (final path in note.attachmentPaths) {
      files.add((await copy(path))!);
    }
    final durable = note.copyWith(
      imagePath: await copy(note.imagePath),
      voicePath: await copy(note.voicePath),
      photoPaths: photos,
      attachmentPaths: files,
      isPending: note.isPending,
    );
    if (durable.hasProtection) {
      final password = durable.protectionPassword;
      if (password == null || password.isEmpty) {
        throw StateError('Не указан пароль заметки');
      }
      return (await encryptNoteForClient(durable, password))
          .copyWith(clearProtectionPassword: true);
    }
    return durable.copyWith(clearProtectionPassword: true);
  }

  Future<void> write(List<Note> notes) async {
    final root = await _root();
    final temporary = File('${root.path}/notes.json.tmp');
    await temporary.writeAsString(
        jsonEncode(notes.map((n) => n.toJson()).toList()),
        flush: true);
    await temporary.rename('${root.path}/notes.json');
  }

  Future<void> removeMedia(String id) async {
    if (!_validId(id)) return;
    final root = await _root();
    final dir = Directory('${root.path}/$id');
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
