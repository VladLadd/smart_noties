import 'note_model.dart';

enum NoteSection { all, incoming, created }

List<Note> filterNotes(Iterable<Note> notes,
    {NoteSection section = NoteSection.all,
    String query = '',
    DateTime? start,
    DateTime? end}) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final first =
      start == null ? null : DateTime(start.year, start.month, start.day);
  final last = end == null ? null : DateTime(end.year, end.month, end.day + 1);
  final result = notes.where((note) {
    if (section == NoteSection.incoming && !note.isIncoming) return false;
    if (section == NoteSection.created && note.isIncoming) return false;
    if (first != null || last != null) {
      final date = note.createdAt?.toLocal();
      if (date == null ||
          (first != null && date.isBefore(first)) ||
          (last != null && !date.isBefore(last))) {
        return false;
      }
    }
    if (words.isNotEmpty) {
      if (note.hasProtection) return false;
      final text = '${note.title}\n${note.body}'.toLowerCase();
      if (!words.every(text.contains)) return false;
    }
    return true;
  }).toList();
  // Стабильный порядок старых заметок без известной даты.
  final indexed = result.asMap().entries.toList();
  indexed.sort((a, b) {
    final date = (b.value.createdAt ?? DateTime(1970))
        .compareTo(a.value.createdAt ?? DateTime(1970));
    return date == 0 ? a.key.compareTo(b.key) : date;
  });
  return indexed.map((entry) => entry.value).toList();
}
