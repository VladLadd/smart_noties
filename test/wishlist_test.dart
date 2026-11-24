import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_noties/models/note_model.dart';
import 'package:smart_noties/models/wishlist_model.dart';
import 'package:smart_noties/providers/auth_provider.dart';
import 'package:smart_noties/providers/locale_provider.dart';
import 'package:smart_noties/providers/notes_provider.dart';
import 'package:smart_noties/services/guest_notes_store.dart';
import 'package:smart_noties/services/notes_service.dart';
import 'package:smart_noties/services/note_client_crypto.dart';
import 'package:smart_noties/screens/wishlist_edit_screen.dart';
import 'package:smart_noties/screens/wishlist_hub_screen.dart';
import 'package:smart_noties/services/wishlist_service.dart';

class WishlistBackend extends NotesService {
  bool fail = false;
  bool conflict = false;
  int uploads = 0;
  final List<Note> created = [];
  @override
  Future<String> uploadPickedImage(
      {required XFile file,
      required String token,
      String? mediaPassword}) async {
    uploads++;
    return '/api/image/1/gift.jpg';
  }

  @override
  Future<Note> createNote(
      {required Note note, required int userId, required String token}) async {
    if (fail) throw Exception('offline');
    created.add(note);
    return note.copyWith(
        id: 'cloud-wishlist',
        isPending: false,
        title: conflict ? 'Older cloud version' : note.title);
  }
}

class WishlistUiNotes extends NotesProvider {
  Note? saved;
  @override
  Future<Note> saveWishlist(Note note,
      {required String? token,
      required int? userId,
      int? wishlistRevision}) async {
    saved = note;
    return note;
  }
}

class SharedWishlistService extends WishlistService {
  @override
  Future<dynamic> json(String path, String token,
      {String method = 'GET', Map<String, dynamic>? body}) async {
    if (path == '/api/wishlists/shared') {
      return [
        {'id': 'shared-list', 'title': 'Shared birthday'}
      ];
    }
    throw Exception('wishlist_not_found');
  }
}

class BlockedProductService extends WishlistService {
  @override
  Future<dynamic> json(String path, String token,
      {String method = 'GET', Map<String, dynamic>? body}) async {
    throw Exception('wishlist_store_blocked');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  WishlistItem gift({String image = ''}) => WishlistItem(
      id: WishlistItem.newId(),
      title: 'Camera',
      imagePath: image,
      priceMinor: 129999,
      currency: 'RUB');
  Note wishlist({String image = '', String id = 'draft'}) => Note(
      id: id,
      noteType: NoteType.wishlist,
      title: 'Birthday',
      body: 'Ideas',
      wishlistData: WishlistData(items: [gift(image: image)]).encode());
  test(
      'Typed wishlist JSON preserves money, order and old notes; unknown data is not overwritten',
      () {
    final original = wishlist();
    final restored = Note.fromJson(original.toJson());
    expect(restored.isWishlist, isTrue);
    expect(restored.wishlist.items.single.priceMinor, 129999);
    expect(
        restored.wishlist.items.single.id, original.wishlist.items.single.id);
    expect(Note.fromJson({'id': 'old', 'title': '', 'body': ''}).isWishlist,
        isFalse);
    final future = original.copyWith(wishlistData: '{"version":2,"items":[]}');
    expect(() => future.wishlist, throwsFormatException);
    expect(future.copyWith(title: 'Edited').wishlistData, future.wishlistData);
  });
  test(
      'Guest wishlist photos survive temp deletion and encrypted JSON round trip',
      () async {
    final root = await Directory.systemTemp.createTemp('wishlist-test-');
    try {
      final photo = File('${root.path}/source.jpg');
      await photo.writeAsBytes([1, 2, 3]);
      final store = GuestNotesStore(directoryProvider: () async => root);
      final saved = await store.prepare(
          wishlist(image: photo.path, id: 'guest_1').copyWith(
              isProtected: true, protectionPassword: 'test-password'));
      await store.write([saved]);
      await photo.delete();
      final raw =
          await File('${root.path}/guest_notes/notes.json').readAsString();
      expect(raw, isNot(contains('Camera')));
      expect(raw, isNot(contains('test-password')));
      final restored = await decryptNoteFromClient(
          (await store.load()).single, 'test-password');
      expect(await File(restored.wishlist.items.single.imagePath).readAsBytes(),
          [1, 2, 3]);
    } finally {
      await root.delete(recursive: true);
    }
  });
  test(
      'Sign-in exposes only the chosen guest wishlist and failed upload preserves all local data',
      () async {
    final root = await Directory.systemTemp.createTemp('wishlist-upload-test-');
    try {
      final photo = File('${root.path}/source.jpg');
      await photo.writeAsBytes([1, 2, 3]);
      final store = GuestNotesStore(directoryProvider: () async => root);
      final backend = WishlistBackend()..fail = true;
      final provider = NotesProvider(guestStore: store, service: backend);
      await provider.setGuestMode(true);
      final first = await provider.saveWishlist(wishlist(image: photo.path),
          token: null, userId: null);
      await provider.saveWishlist(
          wishlist().copyWith(title: 'Other private list'),
          token: null,
          userId: null);
      await provider.offerGuestWishlist(first);
      await provider.setGuestMode(false);
      expect(provider.notes.length, 1);
      expect(provider.notes.single.id, first.id);
      await expectLater(
          provider.uploadWishlist(first, token: 'token', userId: 1),
          throwsException);
      expect((await store.load()).length, 2);
      expect(provider.notes.single.id, first.id);
      backend.fail = false;
      backend.conflict = true;
      await expectLater(
          provider.uploadWishlist(first, token: 'token', userId: 1),
          throwsStateError);
      expect((await store.load()).length, 2);
      backend.conflict = false;
      backend.created.clear();
      final cloud =
          await provider.uploadWishlist(first, token: 'token', userId: 1);
      expect(cloud.id, 'cloud-wishlist');
      expect(backend.uploads, 1);
      expect(backend.created.single.wishlist.items.single.imagePath,
          '/api/image/1/gift.jpg');
      expect((await store.load()).single.title, 'Other private list');
      expect(
          (await SharedPreferences.getInstance())
              .getString('wishlist_upload_candidate'),
          isNull);
      provider.dispose();
    } finally {
      await root.delete(recursive: true);
    }
  });
  testWidgets(
      'Wishlist editor creates a gift and rejects unsafe links without losing the draft',
      (tester) async {
    final notes = WishlistUiNotes();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider<NotesProvider>.value(value: notes),
        ],
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const WishlistEditScreen())),
                        child: const Text('Create')))))));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('wishlist-title')), 'Birthday');
    await tester.tap(find.text('Добавить подарок'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('gift-title')), 'Camera');
    await tester.enterText(find.byKey(const ValueKey('gift-price')), '1299,99');
    await tester.enterText(
        find.byKey(const ValueKey('gift-url')), 'javascript:alert(1)');
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить').last);
    await tester.pumpAndSettle();
    expect(find.text('Введите ссылку http:// или https://'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('gift-url')), 'https://example.com/product');
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить').last);
    await tester.pumpAndSettle();
    expect(find.text('Camera'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();
    expect(notes.saved!.wishlist.items.single.priceMinor, 129999);
    expect(notes.saved!.isWishlist, isTrue);
    expect(tester.takeException(), isNull);
    notes.dispose();
  });
  testWidgets('Locked wishlist cannot be edited without unlocking',
      (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: MaterialApp(
          home: WishlistEditScreen(
              initialNote: wishlist().copyWith(
                  isProtected: true, wishlistData: 'cenc:v1:locked'))),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wishlist-title')), findsNothing);
    expect(find.text('Добавить подарок'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test('Import accepts only Smart Notes share URLs', () {
    final token = 'a' * 43;
    expect(WishlistService.linkToken('https://s-notes.ru/w/$token'), token);
    expect(() => WishlistService.linkToken('https://attacker.invalid/w/$token'),
        throwsFormatException);
    expect(
        () => WishlistService.linkToken('https://s-notes.ru/api/image/1/a.jpg'),
        throwsFormatException);
    expect(() => WishlistService.linkToken('javascript:alert(1)'),
        throwsFormatException);
  });
  testWidgets('Shared list hub loads invitations and exposes explicit import',
      (tester) async {
    final auth = AuthProvider();
    await tester.pump();
    auth.token = 'test-token';
    auth.userId = 1;
    auth.status = AuthStatus.authenticated;
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ],
        child: MaterialApp(
            home: WishlistHubScreen(service: SharedWishlistService()))));
    await tester.pumpAndSettle();
    expect(find.text('Shared birthday'), findsOneWidget);
    expect(find.text('Импортировать копию'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });
  testWidgets('Revision conflict keeps wishlist draft in editor',
      (tester) async {
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ],
        child: MaterialApp(
            home: WishlistEditScreen(
                initialNote: wishlist(),
                collaborative: true,
                onSave: (_) async => throw StateError('wishlist_conflict')))));
    await tester.enterText(
        find.byKey(const ValueKey('wishlist-title')), 'My unsaved draft');
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('My unsaved draft'), findsOneWidget);
    expect(find.textContaining('Список уже изменён другим участником'),
        findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Store failure appears inside gift dialog and preserves entered fields',
      (tester) async {
    final auth = AuthProvider();
    await tester.pump();
    auth.token = 'test-token';
    auth.userId = 1;
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ],
        child: MaterialApp(
            home:
                WishlistEditScreen(productService: BlockedProductService()))));
    await tester.tap(find.text('Добавить подарок'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('gift-title')), 'Нефритовый браслет');
    await tester.enterText(find.byKey(const ValueKey('gift-price')), '1800');
    await tester.enterText(find.byKey(const ValueKey('gift-url')),
        'https://www.ozon.ru/product/test');
    await tester.ensureVisible(find.text('Заполнить по ссылке'));
    await tester.tap(find.text('Заполнить по ссылке'));
    await tester.pumpAndSettle();
    final error = find.byKey(const ValueKey('gift-autofill-error'));
    expect(error, findsOneWidget);
    expect(find.ancestor(of: error, matching: find.byType(AlertDialog)),
        findsOneWidget);
    expect(find.text('Нефритовый браслет'), findsOneWidget);
    expect(find.text('1800'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });
}
