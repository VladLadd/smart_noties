import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../models/note_model.dart';

const _clientEncryptedPrefix = 'cenc:v1:';
const _saltLength = 16;
const _pbkdf2Iterations = 120000;

bool isClientEncryptedValue(String value) {
  return value.startsWith(_clientEncryptedPrefix);
}

Future<Note> encryptNoteForClient(Note note, String password) async {
  if (!note.hasProtection || password.isEmpty) return note;

  final title = await _encryptString(note.title, password);
  final body = await _encryptString(note.body, password);
  final drawingData = note.drawingData == null
      ? null
      : await _encryptString(note.drawingData!, password);
  final imagePath = note.imagePath == null
      ? null
      : await _encryptString(note.imagePath!, password);
  final voicePath = note.voicePath == null
      ? null
      : await _encryptString(note.voicePath!, password);
  final photoPaths = <String>[];
  for (final path in note.photoPaths) {
    photoPaths.add(await _encryptString(path, password));
  }

  return note.copyWith(
    title: title,
    body: body,
    drawingData: drawingData,
    clearDrawingData: drawingData == null,
    imagePath: imagePath,
    clearImagePath: imagePath == null,
    voicePath: voicePath,
    clearVoicePath: voicePath == null,
    photoPaths: photoPaths,
  );
}

Future<Note> decryptNoteFromClient(Note note, String password) async {
  if (!note.hasProtection || password.isEmpty) return note;

  final title = await _decryptString(note.title, password);
  final body = await _decryptString(note.body, password);
  final drawingData = note.drawingData == null
      ? null
      : await _decryptString(note.drawingData!, password);
  final imagePath = note.imagePath == null
      ? null
      : await _decryptString(note.imagePath!, password);
  final voicePath = note.voicePath == null
      ? null
      : await _decryptString(note.voicePath!, password);
  final photoPaths = <String>[];
  for (final path in note.photoPaths) {
    photoPaths.add(await _decryptString(path, password));
  }

  return note.copyWith(
    title: title,
    body: body,
    drawingData: drawingData,
    clearDrawingData: drawingData == null,
    imagePath: imagePath,
    clearImagePath: imagePath == null,
    voicePath: voicePath,
    clearVoicePath: voicePath == null,
    photoPaths: photoPaths,
  );
}

Future<String> _encryptString(String value, String password) async {
  if (value.isEmpty || isClientEncryptedValue(value)) return value;

  final salt = _randomBytes(_saltLength);
  final secretKey = await _deriveKey(password, salt);
  final algorithm = AesGcm.with256bits();
  final secretBox = await algorithm.encrypt(
    utf8.encode(value),
    secretKey: secretKey,
  );

  return [
    _clientEncryptedPrefix.substring(0, _clientEncryptedPrefix.length - 1),
    base64Encode(salt),
    base64Encode(secretBox.concatenation()),
  ].join(':');
}

Future<String> _decryptString(String value, String password) async {
  if (value.isEmpty || !isClientEncryptedValue(value)) return value;

  final parts = value.split(':');
  if (parts.length != 4) {
    throw const FormatException('Некорректный формат шифротекста заметки');
  }

  final salt = base64Decode(parts[2]);
  final boxBytes = base64Decode(parts[3]);
  final secretKey = await _deriveKey(password, salt);
  final algorithm = AesGcm.with256bits();
  final clearBytes = await algorithm.decrypt(
    SecretBox.fromConcatenation(
      boxBytes,
      nonceLength: 12,
      macLength: 16,
    ),
    secretKey: secretKey,
  );
  return utf8.decode(clearBytes);
}

Future<SecretKey> _deriveKey(String password, List<int> salt) {
  return Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _pbkdf2Iterations,
    bits: 256,
  ).deriveKeyFromPassword(
    password: password,
    nonce: salt,
  );
}

List<int> _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}
