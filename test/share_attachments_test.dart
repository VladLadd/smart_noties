import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:smart_noties/models/note_model.dart';
import 'package:smart_noties/providers/incoming_share_provider.dart';
import 'package:smart_noties/services/note_client_crypto.dart';

void main() {
  test('Mixed shares retain text, photos, documents and video', () {
    final share = IncomingShare.fromMedia([
      SharedMediaFile(path: 'https://example.com', type: SharedMediaType.url),
      SharedMediaFile(path: '/photo.jpg', type: SharedMediaType.image),
      SharedMediaFile(path: '/report.pdf', type: SharedMediaType.file),
      SharedMediaFile(path: '/clip.mp4', type: SharedMediaType.video),
    ]);
    expect(share.body, 'https://example.com');
    expect(share.images.length, 1);
    expect(share.files.map((f) => f.path), ['/report.pdf', '/clip.mp4']);
    expect(share.unsupportedFileCount, 0);
  });
  test('Protected attachments survive local JSON and encryption round trip',
      () async {
    const note = Note(
        id: 'local_1',
        title: 'Title',
        body: 'Text',
        isProtected: true,
        attachmentPaths: ['/api/file/1/report.pdf']);
    final encrypted = await encryptNoteForClient(note, 'password');
    expect(encrypted.attachmentPaths.single, isNot(contains('report.pdf')));
    final restored = await decryptNoteFromClient(
        Note.fromJson(encrypted.toJson()), 'password');
    expect(restored.attachmentPaths, note.attachmentPaths);
    expect(
        Note.fromJson({'id': 'old', 'title': '', 'body': ''}).attachmentPaths,
        isEmpty);
  });
}
