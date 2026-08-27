import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Базовый URL бэкенда.
///
/// На Android-эмуляторе host-машина доступна по 10.0.2.2 — `localhost` там
/// указывает на сам эмулятор. На iOS-симуляторе, desktop и web работает localhost.
final String apiBaseUrl = kIsWeb
    ? 'http://localhost:8070'
    : defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8070'
        : 'http://localhost:8070';

/// Признак удалённого (серверного) медиа-пути: полный URL или относительный
/// путь к API бэкенда (`/api/voice/...`, устар. `/uploads/...`). Локальные
/// записи — абсолютные пути файловой системы (`/data/...`, `/private/...`).
bool isRemoteMedia(String path) =>
    path.startsWith('http') ||
    path.startsWith('/api/') ||
    path.startsWith('/uploads');

/// Приводит относительный путь бэкенда к полному URL. Полные URL и локальные
/// пути возвращаются как есть.
String resolveMediaUrl(String path) {
  if (path.startsWith('http')) return path;
  if (path.startsWith('/')) return '$apiBaseUrl$path';
  return path;
}
