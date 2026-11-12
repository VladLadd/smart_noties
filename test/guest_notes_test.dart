import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_noties/models/note_model.dart';
import 'package:smart_noties/providers/notes_provider.dart';
import 'package:smart_noties/services/guest_notes_store.dart';

void main() {
  late Directory root;
  late GuestNotesStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('guest-notes-test-');
    store = GuestNotesStore(directoryProvider: () async => root);
  });
  tearDown(() async => root.delete(recursive: true));

  test('Guest notes and media survive restart without entering sync queue',
      () async {
    final source = File('${root.path}/picked.jpg');
    await source.writeAsBytes([1, 2, 3]);
    final provider = NotesProvider(guestStore: store);
    await provider.setGuestMode(true);
    await provider.addNote(
        Note(
            id: '',
            title: 'Local',
            body: 'Body',
            isIncoming: true,
            imagePath: source.path,
            photoPaths: [source.path],
            attachmentPaths: [source.path],
            voicePath: source.path),
        userId: null,
        token: null);
    final note = provider.notes.single;
    expect(note.isPending, isFalse);
    expect(note.createdAt, isNotNull);
    expect(note.isIncoming, isTrue);
    await source.delete();
    for (final path in [
      note.imagePath!,
      ...note.photoPaths,
      ...note.attachmentPaths,
      note.voicePath!
    ]) {
      expect(await File(path).readAsBytes(), [1, 2, 3]);
    }
    expect(provider.shouldLoadServerNotes('cloud-token'), isFalse);
    await expectLater(
        provider.syncNote(note, userId: 1, token: 'token'), throwsStateError);
    expect((await SharedPreferences.getInstance()).getString('pending_notes'),
        isNull);
    await provider.setGuestMode(false);
    expect(provider.notes, isEmpty);
    provider.dispose();

    final restarted = NotesProvider(guestStore: store);
    await restarted.setGuestMode(true);
    expect(restarted.notes.single.id, note.id);
    await restarted.updateNote(restarted.notes.single.copyWith(title: 'Edited'),
        token: null);
    expect((await store.load()).single.title, 'Edited');
    await restarted.deleteNote(note.id);
    expect(await store.load(), isEmpty);
    expect(await Directory('${root.path}/guest_notes/${note.id}').exists(),
        isFalse);
    restarted.dispose();
  });

  test('Local password protection persists without saving the password',
      () async {
    final provider = NotesProvider(guestStore: store);
    await provider.setGuestMode(true);
    await provider.addNote(
        const Note(
            id: '',
            title: 'Secret title',
            body: 'Secret text',
            isProtected: true,
            protectionPassword: 'test-private-password'),
        userId: null,
        token: null);
    final disk =
        await File('${root.path}/guest_notes/notes.json').readAsString();
    expect(disk, isNot(contains('Secret title')));
    expect(disk, isNot(contains('test-private-password')));
    final loaded = (await store.load()).single;
    final unlocked = await provider.verifyNotePassword(loaded,
        password: 'test-private-password', token: null);
    expect(unlocked.body, 'Secret text');
    await expectLater(
        provider.verifyNotePassword(loaded, password: 'wrong', token: null),
        throwsException);
    provider.dispose();
  });
  test('Concurrent local saves do not overwrite one another', () async {
    final provider = NotesProvider(guestStore: store);
    await provider.setGuestMode(true);
    await Future.wait(List.generate(
        4,
        (i) => provider.addNote(Note(id: '', title: 'Note $i', body: ''),
            userId: null, token: null)));
    expect(provider.notes.length, 4);
    expect((await store.load()).map((n) => n.title).toSet().length, 4);
    provider.dispose();
  });
  test('Unreadable guest data is not overwritten by a new note', () async {
    final directory = await Directory('${root.path}/guest_notes').create();
    final file = File('${directory.path}/notes.json');
    await file.writeAsString('invalid JSON');
    final provider = NotesProvider(guestStore: store);
    await provider.setGuestMode(true);
    expect(provider.guestLoadError, isNotNull);
    await expectLater(
        provider.addNote(const Note(id: '', title: 'New', body: ''),
            userId: null, token: null),
        throwsStateError);
    expect(await file.readAsString(), 'invalid JSON');
    provider.dispose();
  });
}
