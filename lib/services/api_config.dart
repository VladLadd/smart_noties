/// Production API по умолчанию. Для локальной разработки адрес можно
/// переопределить через `--dart-define=API_BASE_URL=...`.
const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

final String apiBaseUrl = _apiBaseUrlOverride.isNotEmpty
    ? _apiBaseUrlOverride
    : 'https://s-notes.ru';

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
