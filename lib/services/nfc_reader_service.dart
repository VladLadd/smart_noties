import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:nfc_manager/nfc_manager.dart';

import '../models/nfc_unlock_model.dart';

class NfcReaderException implements Exception {
  final String message;

  const NfcReaderException(this.message);

  @override
  String toString() => message;
}

class NfcReaderService {
  Completer<NfcUnlockPayload>? _activeRead;

  Future<NfcUnlockPayload> readUnlockPayload() async {
    if (kIsWeb) {
      throw const NfcReaderException('NFC недоступен в web-версии');
    }
    if (_activeRead != null) {
      throw const NfcReaderException('NFC уже ожидает метку');
    }

    final available = await NfcManager.instance.isAvailable();
    if (!available) {
      throw const NfcReaderException('NFC недоступен на этом устройстве');
    }

    final completer = Completer<NfcUnlockPayload>();
    _activeRead = completer;

    await NfcManager.instance.startSession(
      onDiscovered: (tag) async {
        try {
          final uri = _readSmartNotiesUri(tag);
          final payload = _payloadFromUri(uri);
          if (!completer.isCompleted) completer.complete(payload);
          await _stopSessionQuietly();
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
          await _stopSessionQuietly(errorMessage: e.toString());
        } finally {
          _activeRead = null;
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        cancel();
        throw const NfcReaderException('NFC-метка не приложена');
      },
    );
  }

  void cancel() {
    final completer = _activeRead;
    _activeRead = null;
    unawaited(_stopSessionQuietly());
    if (completer != null && !completer.isCompleted) {
      completer
          .completeError(const NfcReaderException('Сканирование отменено'));
    }
  }

  Future<void> _stopSessionQuietly({String? errorMessage}) async {
    try {
      if (errorMessage == null || errorMessage.isEmpty) {
        await NfcManager.instance.stopSession();
      } else {
        await NfcManager.instance.stopSession(errorMessage: errorMessage);
      }
    } catch (_) {
      // NFC-сессия могла ещё не стартовать или уже быть закрытой.
    }
  }

  Uri _readSmartNotiesUri(NfcTag tag) {
    final ndef = Ndef.from(tag);
    final records = ndef?.cachedMessage?.records ?? const <NdefRecord>[];

    for (final record in records) {
      final uri = _uriFromRecord(record);
      if (uri != null && _isSmartNotiesUnlockUri(uri)) return uri;
    }

    final fallback = _uriFromText(tag.data.toString());
    if (fallback != null && _isSmartNotiesUnlockUri(fallback)) return fallback;

    throw const NfcReaderException('На метке нет smart_noties NFC-токена');
  }

  NfcUnlockPayload _payloadFromUri(Uri uri) {
    final tagId = uri.queryParameters['tagId']?.trim() ?? '';
    final secret = uri.queryParameters['secret']?.trim() ?? '';
    if (tagId.isEmpty || secret.isEmpty) {
      throw const NfcReaderException('NFC-токен повреждён');
    }
    return NfcUnlockPayload(tagId: tagId, secret: secret);
  }

  Uri? _uriFromRecord(NdefRecord record) {
    final type = ascii.decode(record.type, allowInvalid: true);
    if (type == 'U') {
      return _uriFromNdefUriPayload(record.payload);
    }
    if (type == 'T') {
      return _uriFromTextPayload(record.payload);
    }
    return _uriFromText(utf8.decode(record.payload, allowMalformed: true));
  }

  Uri? _uriFromNdefUriPayload(Uint8List payload) {
    if (payload.isEmpty) return null;
    final prefix = _uriPrefix(payload.first);
    final suffix = utf8.decode(payload.sublist(1), allowMalformed: true);
    return Uri.tryParse('$prefix$suffix');
  }

  Uri? _uriFromTextPayload(Uint8List payload) {
    if (payload.isEmpty) return null;
    final languageLength = payload.first & 0x3F;
    if (payload.length <= languageLength + 1) return null;
    final text = utf8.decode(
      payload.sublist(languageLength + 1),
      allowMalformed: true,
    );
    return _uriFromText(text);
  }

  Uri? _uriFromText(String text) {
    final match =
        RegExp(r'smartnoties://nfc/unlock\?[^\s\]}]+').firstMatch(text);
    if (match == null) return null;
    return Uri.tryParse(match.group(0)!);
  }

  bool _isSmartNotiesUnlockUri(Uri uri) {
    return uri.scheme == 'smartnoties' &&
        uri.host == 'nfc' &&
        uri.path == '/unlock';
  }

  String _uriPrefix(int code) {
    const prefixes = <int, String>{
      0x00: '',
      0x01: 'http://www.',
      0x02: 'https://www.',
      0x03: 'http://',
      0x04: 'https://',
      0x05: 'tel:',
      0x06: 'mailto:',
      0x07: 'ftp://anonymous:anonymous@',
      0x08: 'ftp://ftp.',
      0x09: 'ftps://',
      0x0A: 'sftp://',
      0x0B: 'smb://',
      0x0C: 'nfs://',
      0x0D: 'ftp://',
      0x0E: 'dav://',
      0x0F: 'news:',
      0x10: 'telnet://',
      0x11: 'imap:',
      0x12: 'rtsp://',
      0x13: 'urn:',
      0x14: 'pop:',
      0x15: 'sip:',
      0x16: 'sips:',
      0x17: 'tftp:',
      0x18: 'btspp://',
      0x19: 'btl2cap://',
      0x1A: 'btgoep://',
      0x1B: 'tcpobex://',
      0x1C: 'irdaobex://',
      0x1D: 'file://',
      0x1E: 'urn:epc:id:',
      0x1F: 'urn:epc:tag:',
      0x20: 'urn:epc:pat:',
      0x21: 'urn:epc:raw:',
      0x22: 'urn:epc:',
      0x23: 'urn:nfc:',
    };
    return prefixes[code] ?? '';
  }
}
