import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_noties/providers/incoming_share_provider.dart';
import 'package:smart_noties/providers/notes_provider.dart';
import 'package:smart_noties/services/guest_notes_store.dart';
import 'package:smart_noties/services/shared_note_importer.dart';

void main() {
  late Directory root;
  late GuestNotesStore pending;
  late GuestNotesStore guest;
  IncomingShare link() => IncomingShare.fromMedia([
        SharedMediaFile(
            path: 'https://example.com/story', type: SharedMediaType.url)
      ]);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('share-import-test-');
    pending = GuestNotesStore(
        directoryProvider: () async => root,
        directoryName: 'pending_media',
        idPrefix: 'local_');
    guest = GuestNotesStore(directoryProvider: () async => root);
  });
  tearDown(() async => root.delete(recursive: true));

  test('Saves before preview loads and does not overwrite user edits',
      () async {
    final started = Completer<void>();
    final response = Completer<http.Response>();
    final client = MockClient((_) {
      started.complete();
      return response.future;
    });
    final provider = NotesProvider(pendingStore: pending);
    final importing = provider.importShare(link(),
        importer: SharedNoteImporter(client: client));
    await started.future;
    final disk = jsonDecode(
            (await SharedPreferences.getInstance()).getString('pending_notes')!)
        as List;
    expect(disk.single['body'], 'https://example.com/story');
    await provider.updateNote(provider.notes.single.copyWith(title: 'My title'),
        token: null);
    response.complete(http.Response('<title>Website title</title>', 200));
    await importing;
    expect(provider.notes.single.title, 'My title');
    provider.dispose();
    client.close();
  });

  test('Extracts title, article and relative cover, retaining the source URL',
      () async {
    final client = MockClient((request) async {
      if (request.url.path == '/cover.png') {
        return http.Response.bytes([137, 80, 78, 71, 13, 10, 26, 10, 0], 200);
      }
      return http.Response('''<html><head>
        <meta property="og:title" content="Story &amp; news">
        <meta property="og:image" content="/cover.png"></head>
        <body><article><p>A complete article paragraph that should be saved in the note.</p></article></body></html>''',
          200);
    });
    final provider = NotesProvider(pendingStore: pending);
    await provider.importShare(link(),
        importer: SharedNoteImporter(client: client));
    final note = provider.notes.single;
    expect(note.title, 'Story & news');
    expect(note.body, contains('A complete article paragraph'));
    expect(note.body, contains('https://example.com/story'));
    expect(note.isIncoming, isTrue);
    expect(note.isPending, isTrue);
    expect(await File(note.imagePath!).exists(), isTrue);
    provider.dispose();
    final restarted = NotesProvider(pendingStore: pending);
    // Даём завершиться чтению локальных заметок.
    await Future<void>.delayed(Duration.zero);
    expect(restarted.notes.single.title, note.title);
    expect(await File(restarted.notes.single.imagePath!).exists(), isTrue);
    restarted.dispose();
    client.close();
  });

  test(
      'Offline shares remain local and preserve attachments after source removal',
      () async {
    final source = File('${root.path}/photo.jpg');
    await source.writeAsBytes([1, 2, 3]);
    final share = IncomingShare.fromMedia([
      SharedMediaFile(
          path: 'https://example.com/story', type: SharedMediaType.url),
      SharedMediaFile(path: source.path, type: SharedMediaType.image),
      SharedMediaFile(path: source.path, type: SharedMediaType.file),
    ]);
    final client =
        MockClient((_) async => throw const SocketException('offline'));
    final provider = NotesProvider(pendingStore: pending);
    await provider.importShare(share,
        importer: SharedNoteImporter(client: client));
    await source.delete();
    final note = provider.notes.single;
    expect(note.title, 'example.com');
    expect(note.body, 'https://example.com/story');
    for (final path in [...note.photoPaths, ...note.attachmentPaths]) {
      expect(await File(path).readAsBytes(), [1, 2, 3]);
    }
    await provider.updateNote(note.copyWith(title: 'Edited locally'),
        token: 'token');
    expect(provider.notes.single.isPending, isTrue);
    provider.dispose();
    client.close();
  });

  test('Guest share stays local and is available for manual upload after login',
      () async {
    final client = MockClient((_) async => http.Response('blocked', 403));
    final provider = NotesProvider(guestStore: guest, pendingStore: pending);
    await provider.setGuestMode(true);
    await provider.importShare(link(),
        importer: SharedNoteImporter(client: client));
    final saved = provider.notes.single;
    expect(saved.isIncoming, isTrue);
    expect(saved.isPending, isTrue);
    expect(await guest.load(), isEmpty);
    await provider.updateNote(saved.copyWith(title: 'Guest edited'),
        token: null);
    await provider.setGuestMode(false);
    expect(provider.notes.single.title, 'Guest edited');
    expect(provider.notes.single.id, saved.id);
    await provider.setGuestMode(true);
    await provider.deleteNote(saved.id);
    expect(provider.notes, isEmpty);
    provider.dispose();
    client.close();
  });

  test(
      'Concurrent imports are not lost and missing media is not reported saved',
      () async {
    final client = MockClient((_) async => http.Response('offline', 503));
    final provider = NotesProvider(pendingStore: pending);
    await Future.wait(List.generate(
        3,
        (_) => provider.importShare(link(),
            importer: SharedNoteImporter(client: client))));
    expect(provider.notes.length, 3);
    expect(provider.notes.map((n) => n.id).toSet().length, 3);
    expect(
        jsonDecode((await SharedPreferences.getInstance())
            .getString('pending_notes')!) as List,
        hasLength(3));
    final share = IncomingShare.fromMedia([
      SharedMediaFile(path: '/missing/photo.jpg', type: SharedMediaType.image)
    ]);
    await expectLater(
        provider.importShare(share), throwsA(isA<FileSystemException>()));
    expect(provider.notes.length, 3);
    provider.dispose();
    client.close();
  });
}
