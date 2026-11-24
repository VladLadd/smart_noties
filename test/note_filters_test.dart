import 'package:flutter_test/flutter_test.dart';
import 'package:smart_noties/models/note_model.dart';
import 'package:smart_noties/models/note_filters.dart';
import 'package:smart_noties/models/wishlist_model.dart';

void main() {
  final notes = [
    Note(
        id: '1',
        title: 'Поездка',
        body: 'Купить билеты Москва',
        createdAt: DateTime(2026, 11, 12, 0)),
    Note(
        id: '2',
        title: 'Ссылка Москва',
        body: 'Купить вещи',
        isIncoming: true,
        createdAt: DateTime(2026, 11, 12, 23, 59)),
    Note(
        id: '3',
        title: 'Москва',
        body: 'Билеты',
        isProtected: true,
        createdAt: DateTime(2026, 11, 11)),
    const Note(id: 'old', title: 'Без даты', body: ''),
  ];
  test('Sections, keyword intersection and dates compose', () {
    expect(
        filterNotes(notes,
                section: NoteSection.incoming, query: 'МОСКВА купить')
            .map((n) => n.id),
        ['2']);
    expect(
        filterNotes(notes, section: NoteSection.created, query: 'Москва билеты')
            .map((n) => n.id),
        ['1']);
    expect(
        filterNotes(notes,
                start: DateTime(2026, 11, 12), end: DateTime(2026, 11, 12))
            .map((n) => n.id),
        ['2', '1']);
    expect(filterNotes(notes, query: 'нет результата'), isEmpty);
    expect(filterNotes(notes).last.id, 'old');
  });
  test('Old JSON stays compatible and origin/date survive round trip', () {
    expect(Note.fromJson({'id': 'old', 'title': '', 'body': ''}).isIncoming,
        isFalse);
    final restored = Note.fromJson(notes[1].toJson());
    expect(restored.isIncoming, isTrue);
    expect(restored.createdAt!.isAtSameMomentAs(notes[1].createdAt!), isTrue);
    expect(restored.copyWith(body: 'edited').isIncoming, isTrue);
  });
  test('Wishlist section combines type, archive, gift search and date filters',
      () {
    final wishlist = Note(
        id: 'wishlist',
        noteType: NoteType.wishlist,
        title: 'Подарки',
        body: '',
        createdAt: DateTime(2026, 11, 12),
        wishlistData: const WishlistData(items: [
          WishlistItem(id: 'gift', title: 'Браслет', description: 'Нефритовый')
        ]).encode());
    final mixed = [
      ...notes,
      wishlist,
      wishlist.copyWith(id: 'incoming-wishlist', isIncoming: true),
      wishlist.copyWith(id: 'archived-wishlist', isArchived: true),
      wishlist.copyWith(id: 'protected-wishlist', isProtected: true),
    ];
    expect(filterNotes(mixed, section: NoteSection.wishlists).map((n) => n.id),
        ['wishlist', 'incoming-wishlist', 'protected-wishlist']);
    expect(
        filterNotes(mixed,
                section: NoteSection.wishlists,
                query: 'НЕФРИТОВЫЙ браслет',
                start: DateTime(2026, 11, 12),
                end: DateTime(2026, 11, 12))
            .map((n) => n.id),
        ['wishlist', 'incoming-wishlist']);
    expect(
        filterNotes(mixed,
            section: NoteSection.wishlists, start: DateTime(2026, 11, 13)),
        isEmpty);
    expect(filterNotes(mixed, section: NoteSection.archived).map((n) => n.id),
        ['archived-wishlist']);
  });
}
