import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_noties/models/note_drawing_model.dart';
import 'package:smart_noties/models/note_model.dart';
import 'package:smart_noties/services/note_client_crypto.dart';

void main() {
  test('NoteDrawing сохраняет и читает strokes', () {
    const drawing = NoteDrawing(
      canvasAspectRatio: 0.72,
      strokes: [
        DrawingStroke(
          color: Colors.red,
          width: 0.02,
          points: [
            DrawingPoint(x: 0.1, y: 0.2),
            DrawingPoint(x: 0.3, y: 0.4),
          ],
        ),
      ],
    );

    final decoded = NoteDrawing.decode(drawing.encode());

    expect(decoded.hasContent, isTrue);
    expect(decoded.canvasAspectRatio, 0.72);
    expect(decoded.strokes.single.color.toARGB32(), Colors.red.toARGB32());
    expect(decoded.strokes.single.points.last.x, 0.3);
  });

  test('NoteDrawing устойчив к пустым и битым данным', () {
    expect(NoteDrawing.decode(null).hasContent, isFalse);
    expect(NoteDrawing.decode('').hasContent, isFalse);
    expect(NoteDrawing.decode('{bad json').hasContent, isFalse);
  });

  test('drawingData шифруется вместе с защищенной заметкой', () async {
    const drawingData =
        '{"version":1,"strokes":[{"tool":"pen","color":1,"width":0.01,"points":[{"x":0,"y":0},{"x":1,"y":1}]}]}';
    const note = Note(
      id: '1',
      title: 'secret',
      body: 'body',
      drawingData: drawingData,
      isProtected: true,
      protectionPassword: '123456',
    );

    final encrypted = await encryptNoteForClient(note, '123456');
    expect(encrypted.drawingData, isNot(drawingData));
    expect(encrypted.drawingData, startsWith('cenc:v1:'));

    final decrypted = await decryptNoteFromClient(encrypted, '123456');
    expect(decrypted.drawingData, drawingData);
  });
}
