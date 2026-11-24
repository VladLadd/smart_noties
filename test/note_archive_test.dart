import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_noties/models/note_model.dart';
import 'package:smart_noties/models/note_filters.dart';
import 'package:smart_noties/providers/auth_provider.dart';
import 'package:smart_noties/providers/locale_provider.dart';
import 'package:smart_noties/providers/notes_provider.dart';
import 'package:smart_noties/screens/notes_grid_screen.dart';
import 'package:smart_noties/services/guest_notes_store.dart';
import 'package:smart_noties/services/notes_service.dart';
import 'package:smart_noties/services/note_client_crypto.dart';

class ArchiveService extends NotesService {
  bool fail = false;
  int archiveRequests = 0;
  Note? uploaded;
  @override
  Future<List<Note>> fetchNotes(
          {required String token, String? hiddenAccessToken}) async =>
      [
        const Note(
            id: 'server',
            title: 'Защищённая заметка',
            body: '',
            isProtected: true)
      ];
  @override
  Future<void> setArchived(
      {required String id,
      required bool archived,
      required String token}) async {
    archiveRequests++;
    if (fail) throw Exception('Network error');
  }

  @override
  Future<Note> createNote(
      {required Note note, required int userId, required String token}) async {
    uploaded = note;
    return note.copyWith(id: 'server-upload', isPending: false);
  }

  @override
  Future<Note> updateNote(
          {required Note note,
          required String token,
          int? wishlistRevision}) async =>
      throw StateError('Архивирование не должно перезаписывать содержимое');
}

class ArchiveUiNotes extends NotesProvider {
  Note item = const Note(id: 'ui', title: 'Travel note', body: 'Text');
  @override
  List<Note> get notes => [item];
  @override
  Future<void> setArchived(String id,
      {required bool archived, String? token}) async {
    item = item.copyWith(isArchived: archived);
    notifyListeners();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'Archived notes are excluded from active sections and remain searchable in archive',
      () {
    final archived = Note(
        id: 'a',
        title: 'Trip',
        body: 'Tickets',
        isIncoming: true,
        isArchived: true,
        createdAt: DateTime(2026, 11, 19));
    final active = archived.copyWith(id: 'b', isArchived: false);
    for (final section in [NoteSection.all, NoteSection.incoming]) {
      expect(filterNotes([archived, active], section: section).map((n) => n.id),
          ['b']);
    }
    expect(
        filterNotes([archived, active], section: NoteSection.created), isEmpty);
    expect(
        filterNotes([archived, active],
                section: NoteSection.archived,
                query: 'tickets',
                start: DateTime(2026, 11, 19))
            .single
            .id,
        'a');
    expect(Note.fromJson(archived.toJson()).isArchived, isTrue);
    expect(Note.fromJson({'id': 'old', 'title': '', 'body': ''}).isArchived,
        isFalse);
  });

  test(
      'Guest protected note archives and restores after restart without a password',
      () async {
    final root = await Directory.systemTemp.createTemp('archive-test-');
    final store = GuestNotesStore(directoryProvider: () async => root);
    try {
      final prepared = await store.prepare(const Note(
          id: 'guest_1',
          title: 'Secret',
          body: 'Private text',
          isProtected: true,
          protectionPassword: 'test-password'));
      await store.write([prepared]);
      final provider = NotesProvider(guestStore: store);
      await provider.setGuestMode(true);
      await provider.setArchived('guest_1', archived: true);
      expect(provider.notes.single.title, prepared.title);
      expect(provider.notes.single.isArchived, isTrue);
      provider.dispose();
      final restarted = NotesProvider(guestStore: store);
      await restarted.setGuestMode(true);
      expect(restarted.notes.single.isArchived, isTrue);
      await restarted.setArchived('guest_1', archived: false);
      final saved = (await store.load()).single;
      expect(saved.isArchived, isFalse);
      expect(saved.title, prepared.title);
      expect(saved.protectionPassword, isNull);
      final unlocked = await decryptNoteFromClient(saved, 'test-password');
      expect(unlocked.body, 'Private text');
      restarted.dispose();
    } finally {
      await root.delete(recursive: true);
    }
  });

  test(
      'Pending note remains local, preserves archive state when manually uploaded',
      () async {
    final service = ArchiveService();
    const note = Note(
        id: 'local_1',
        title: 'Local',
        body: 'Body',
        isPending: true,
        isIncoming: true);
    SharedPreferences.setMockInitialValues({
      'pending_notes': jsonEncode([note.toJson()])
    });
    final provider = NotesProvider(service: service);
    await provider.setArchived('local_1', archived: true);
    expect(service.archiveRequests, 0);
    final disk = jsonDecode(
            (await SharedPreferences.getInstance()).getString('pending_notes')!)
        as List;
    expect(disk.single['isArchived'], isTrue);
    await provider.syncNote(provider.notes.single,
        userId: 1, token: 'test-token');
    expect(service.uploaded!.isArchived, isTrue);
    expect(provider.notes.single.isArchived, isTrue);
    provider.dispose();
  });

  test(
      'Failed server archive leaves note unchanged; success uses metadata-only request',
      () async {
    final service = ArchiveService()..fail = true;
    final provider = NotesProvider(service: service);
    await provider.loadServerNotes(token: 'test-token');
    await expectLater(
        provider.setArchived('server', archived: true, token: 'test-token'),
        throwsException);
    expect(provider.notes.single.isArchived, isFalse);
    service.fail = false;
    await provider.setArchived('server', archived: true, token: 'test-token');
    expect(provider.notes.single.isArchived, isTrue);
    expect(provider.notes.single.title, 'Защищённая заметка');
    expect(service.archiveRequests, 2);
    provider.dispose();
  });

  test(
      'Archiving an unlocked pending note stores encrypted content without its password',
      () async {
    const note = Note(
        id: 'local_2',
        title: 'Private title',
        body: 'Private body',
        isPending: true,
        isProtected: true,
        protectionPassword: 'private-test-password');
    SharedPreferences.setMockInitialValues({
      'pending_notes': jsonEncode([note.toJson()])
    });
    final provider = NotesProvider();
    await provider.setArchived(note.id, archived: true);
    final raw =
        (await SharedPreferences.getInstance()).getString('pending_notes')!;
    expect(raw, isNot(contains('Private title')));
    expect(raw, isNot(contains('private-test-password')));
    final saved = Note.fromJson(
        Map<String, dynamic>.from((jsonDecode(raw) as List).single));
    expect(saved.isArchived, isTrue);
    expect((await decryptNoteFromClient(saved, 'private-test-password')).body,
        'Private body');
    provider.dispose();
  });

  testWidgets('Long press archives note, archive tab offers restore',
      (tester) async {
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<NotesProvider>(create: (_) => ArchiveUiNotes()),
    ], child: const MaterialApp(home: NotesGridScreen())));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Travel note'));
    await tester.pumpAndSettle();
    expect(find.text('Редактировать'), findsOneWidget);
    expect(find.text('Удалить'), findsOneWidget);
    await tester.tap(find.text('В архив'));
    await tester.pumpAndSettle();
    expect(find.text('Travel note'), findsNothing);
    await tester.tap(find.text('Архив'));
    await tester.pumpAndSettle();
    expect(find.text('Travel note'), findsOneWidget);
    await tester.longPress(find.text('Travel note'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Вернуть из архива'));
    await tester.pumpAndSettle();
    expect(find.text('Travel note'), findsNothing);
    expect(find.text('В архиве пока нет заметок'), findsOneWidget);
    await tester.tap(find.text('Все'));
    await tester.pumpAndSettle();
    expect(find.text('Travel note'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
