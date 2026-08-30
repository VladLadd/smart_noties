# План: добавление видео в заметку по ссылке

Дата плана: 2026-08-21.

Цель: пользователь вставляет ссылку на видео, приложение добавляет видео в
заметку вместе с остальным содержимым. Для источников, где разрешено получить
файл, сохраняем видеофайл на нашем backend. Для платформ с ограничениями
скачивания, например YouTube/Instagram, сохраняем ссылку, превью и embedded
player/metadata без нелегального копирования файла.

## Что видно по похожим приложениям

- App Store ссылка `id1624635075` ведёт на `Blackhole Spliter`. В текущем
  описании это приложение для нарезки длинных видео под соцсети, а не чистый
  downloader. В отзывах пользователи путают его с другим `Blackhole`, который
  якобы скачивал видео по ссылкам.
- Типичный сценарий таких приложений:
  - пользователь вставляет ссылку;
  - приложение определяет провайдера;
  - серверный extractor получает metadata/thumbnail/stream URL;
  - создаётся задача скачивания;
  - показывается прогресс;
  - результат сохраняется во внутреннюю медиатеку;
  - часто есть реклама, ошибки скачивания и ограничения на длинные видео.
- Технически такие приложения обычно держат серверный слой, потому что логика
  извлечения видео часто ломается при изменениях сайтов, требует тяжёлых
  зависимостей и не подходит для мобильного клиента.

## Важное ограничение по платформам

Нельзя строить публичную App Store/Google Play фичу как универсальный downloader
чужих видео со всех платформ.

- YouTube прямо запрещает download/import/backup/cache/store копий
  audiovisual content без письменного разрешения YouTube.
- YouTube можно поддержать безопасно как ссылку, metadata, thumbnail и
  встроенный player.
- Instagram public content можно показывать через embed/oEmbed, но не стоит
  делать скрытое извлечение и сохранение файла без прав на контент.
- Для прямых файлов `.mp4/.mov/.webm`, собственных файлов пользователя и
  источников с явным разрешением можно сохранять файл на backend.

Рекомендация для нашего приложения: делать compliant MVP, а не
blackhole-style universal downloader.

## Пользовательский сценарий MVP

1. Пользователь открывает создание/редактирование заметки.
2. Нажимает новую кнопку `video`.
3. Выбирает:
   - `Вставить ссылку`;
   - позже: `Выбрать видео с устройства`.
4. Вставляет URL.
5. Приложение показывает preview:
   - название;
   - источник;
   - thumbnail;
   - длительность, если доступна;
   - статус: `Будет сохранено как файл` или `Будет сохранено как ссылка`.
6. Пользователь подтверждает добавление.
7. В заметке появляется плитка видео.
8. В режиме просмотра:
   - для локально сохранённого файла открывается наш video player;
   - для YouTube/Instagram открывается embedded/webview/external player.

## Поведение по типам ссылок

### Direct video URL

Примеры:

- `https://example.com/file.mp4`;
- signed URL из личного хранилища пользователя;
- URL, который отвечает `Content-Type: video/*`.

Поведение:

- backend скачивает файл;
- проверяет размер, MIME, длительность;
- сохраняет в `uploads/video/<userId>/<random>.<ext>`;
- создаёт thumbnail;
- возвращает video attachment в приложение.

### YouTube

Поведение MVP:

- не скачивать файл;
- получить metadata через YouTube Data API или oEmbed/парсинг публичной
  страницы только для preview;
- хранить `sourceUrl`, `provider=YouTube`, `thumbnailUrl`, `title`;
- показывать видео через YouTube IFrame/player или открывать системно.

Отдельный режим скачивания YouTube-файла не включать в публичную сборку без
юридического решения и явного письменного разрешения/прав.

### Instagram / Reels

Поведение MVP:

- не скачивать файл;
- использовать embed/oEmbed для public posts/reels, где это доступно;
- хранить `sourceUrl`, `provider=Instagram`, `thumbnailUrl`, `title/author`;
- показывать embedded view или открывать источник.

Stories/private/restricted content не поддерживать.

### TikTok / Vimeo / другие

Поведение MVP:

- сначала metadata/preview + external/embed playback;
- скачивание файла включать только для провайдеров, где это разрешено API или
  пользователь подтвердил права и платформа позволяет прямую загрузку.

## Модель данных

Сейчас `Note` уже содержит `isVideo`, но нет `videoPath` или списка видео.
Добавлять видео в `voicePath` нельзя: смешаются разные типы медиа.

Лучший вариант: отдельная таблица `note_media`, сначала использовать её только
для видео, позже можно перенести туда фото/voice.

Миграция. Номер должен быть `009`, потому что `008_add_phone_login.sql` уже
занята входом по телефону:

```sql
CREATE TABLE IF NOT EXISTS note_media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "noteId" UUID NULL,
    "userId" INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    provider TEXT NOT NULL DEFAULT '',
    "sourceUrl" TEXT NOT NULL DEFAULT '',
    "storagePath" TEXT NOT NULL DEFAULT '',
    "thumbnailPath" TEXT NOT NULL DEFAULT '',
    title TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'ready',
    error TEXT NOT NULL DEFAULT '',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    "isProtected" BOOLEAN NOT NULL DEFAULT FALSE,
    "createdAt" TIMESTAMP NOT NULL DEFAULT NOW(),
    "updatedAt" TIMESTAMP NOT NULL DEFAULT NOW()
);
```

Поля:

- `type`: `video`, позже `image`, `voice`;
- `provider`: `direct`, `youtube`, `instagram`, `tiktok`, `vimeo`, `unknown`;
- `sourceUrl`: исходная ссылка;
- `storagePath`: наш `/api/video/<userId>/<file>`, если файл реально сохранён;
- `thumbnailPath`: наш thumbnail или remote thumbnail;
- `status`: `queued`, `processing`, `ready`, `failed`, `link_only`;
- `metadata`: duration, width, height, original filename, author, etc.;
- `noteId`: может быть `NULL` для временного attachment до сохранения заметки.

Во фронтовой модели добавить:

```dart
class NoteVideo {
  final String id;
  final String provider;
  final String sourceUrl;
  final String? storagePath;
  final String? thumbnailPath;
  final String title;
  final String status;
  final Map<String, dynamic> metadata;
}
```

В `Note` добавить:

```dart
final List<NoteVideo> videos;
```

`isVideo` оставить для обратной совместимости, но вычислять как
`videos.isNotEmpty`.

## Backend API

### Metadata/preview

```text
POST /api/video/preview
Authorization: Bearer <token>

{
  "url": "https://..."
}
```

Ответ:

```json
{
  "provider": "youtube",
  "mode": "link_only",
  "title": "...",
  "thumbnailUrl": "...",
  "durationSeconds": 123,
  "canDownload": false,
  "reason": "Для этого источника сохраняем ссылку и embedded playback"
}
```

### Import

```text
POST /api/video/import
Authorization: Bearer <token>

{
  "url": "https://...",
  "noteId": "optional",
  "isProtected": true,
  "password": "optional"
}
```

Поведение:

- для `direct` URL создаёт job и скачивает файл;
- для `youtube/instagram` создаёт `link_only` attachment;
- для protected media применяет текущий слой `smedia:v1`;
- возвращает `mediaId` и текущий `status`.

### Status

```text
GET /api/video/import/<mediaId>
Authorization: Bearer <token>
```

Ответ:

```json
{
  "id": "...",
  "status": "processing",
  "progress": 42
}
```

### Serving video

```text
GET /api/video/<userId>/<file>
Authorization: Bearer <token>
X-Media-Password: <password for protected note>
```

Правила:

- файл отдаётся только владельцу;
- если файл encrypted, нужен `X-Media-Password`;
- `Range` requests обязательны, иначе video player будет плохо работать;
- `Content-Type` должен быть корректным: `video/mp4`, `video/webm`, etc.

### Delete

```text
DELETE /api/video/<mediaId>
Authorization: Bearer <token>
```

Удаляет attachment и локальный файл/thumbnail.

## Backend implementation

### Provider detector

Создать `video_import.go`:

- `DetectVideoProvider(rawURL string)`;
- нормализация URL;
- allowlist доменов;
- запрет private/local IP через DNS/IP checks;
- запрет `file://`, `ftp://`, `localhost`, `127.0.0.0/8`,
  `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, link-local.

### Direct downloader

Для direct URL:

- `HEAD` request;
- проверить `Content-Type`;
- проверить `Content-Length`;
- max size на MVP: 100 MB;
- max duration после скачивания: например 10 минут;
- stream download на диск через temp-файл;
- после успеха атомарно переименовать temp-файл;
- при protected note зашифровать через существующий media crypto;
- удалить temp при ошибке.

### Metadata extractor

Для MVP:

- YouTube: YouTube Data API/oEmbed для metadata, без скачивания файла;
- Instagram: oEmbed/embed metadata, без скачивания файла;
- Generic: OpenGraph tags (`og:title`, `og:image`, `og:video`) только для
  preview, не для обхода ограничений.

### Thumbnail

Для direct video:

- добавить `ffmpeg`/`ffprobe` на backend host;
- сгенерировать thumbnail:

```text
uploads/video_thumb/<userId>/<random>.jpg
```

Для protected note:

- thumbnail тоже считать protected media;
- либо не генерировать thumbnail, а показывать placeholder с lock-иконкой.

### Async jobs

Для скачивания лучше не держать HTTP request открытым.

Добавить таблицу/статусы:

- `queued`;
- `processing`;
- `ready`;
- `failed`;
- `link_only`.

На старте backend поднимать простой worker goroutine:

- берёт pending jobs из БД;
- обрабатывает по одному/несколько;
- пишет прогресс;
- сохраняет ошибку в `error`.

Для MVP можно начать синхронно для маленьких direct files, но архитектурно лучше
сразу заложить job.

## Protected notes

Если заметка защищена:

- frontend при import отправляет `isProtected=true` и `password`;
- backend шифрует video file через текущий `smedia:v1`;
- `storagePath`, `thumbnailPath`, `sourceUrl` должны попадать под существующий
  клиентский и серверный слой шифрования заметки;
- при просмотре protected note frontend передаёт `X-Media-Password` в video
  player;
- если пароль заметки меняется, video files, как и image/voice, нужно будет
  переупаковывать или перезагружать.

## Frontend changes

### Dependencies

Добавить:

- `video_player` для локального/серверного файла;
- опционально `chewie` или свой контрол для play/pause/fullscreen;
- для embedded YouTube/Instagram: либо `webview_flutter`, либо открытие во
  внешнем браузере на MVP.

### Model

Файлы:

- `lib/models/note_video_model.dart`;
- обновить `lib/models/note_model.dart`;
- обновить `Note.toJson/fromJson/copyWith`.

### Service

В `lib/services/notes_service.dart`:

- `previewVideoUrl(url)`;
- `importVideoUrl(url, noteId?, isProtected?, password?)`;
- `getVideoImportStatus(mediaId)`;
- `deleteVideo(mediaId)`.

### Provider

В `NotesProvider`:

- `previewVideoUrl`;
- `addVideoFromUrl`;
- polling статуса import job;
- удаление video attachment из заметки.

### Editor UI

В `NoteEditScreen`:

- добавить кнопку video рядом с mic/camera;
- modal:
  - поле URL;
  - paste из clipboard;
  - preview card;
  - статус `сохраняем файл` / `сохраняем ссылку`;
  - confirm.
- список video attachments плиткой:
  - thumbnail;
  - provider badge;
  - status/progress;
  - delete button.

### View UI

В `NoteViewScreen`:

- video grid под текстом/медиа;
- tap открывает:
  - fullscreen player для `storagePath`;
  - embedded/external source для `link_only`.
- для protected notes передавать media password.

### Grid/list screen

В `NotesGridScreen`:

- показывать маленькую video icon/badge, если заметка содержит видео;
- для protected note содержимое не раскрывать до password verify.

## Storage and serving details

Новые папки:

```text
uploads/video/<userId>/
uploads/video_thumb/<userId>/
```

Новые helpers:

- `videoDiskPath`;
- `handleUploadVideo` или `handleImportVideo`;
- `handleGetVideo`;
- `handleGetVideoThumbnail`.

Для video serving:

- поддержать `Range` header;
- корректно отдавать `206 Partial Content`;
- не читать весь файл в память для обычных больших видео;
- для encrypted protected video сложнее: текущий `smedia:v1` читает всё в память.
  На MVP можно ограничить protected video размером, например 50 MB. Долгосрочно
  нужен chunk encryption/streaming encryption.

## Security requirements

- SSRF protection для URL import.
- Только `http/https`.
- Redirect limit, например максимум 5.
- Max download size.
- Max duration.
- MIME sniffing, а не доверять только расширению.
- Virus/malware scan позже.
- Rate limit per user.
- Job timeout.
- Cleanup temp files.
- Удаление orphan attachments, если заметка так и не была сохранена.
- Не логировать protected note password.

## Этапы работ

### Этап 1. Product/API boundary

- Зафиксировать список поддерживаемых источников:
  - direct video URL: file import;
  - YouTube: link/preview/player only;
  - Instagram: link/embed/preview only;
  - остальные: generic link preview.
- Зафиксировать лимиты: размер, длительность, timeout.

### Этап 2. Backend schema

- Создать migration `009_create_note_media.sql`.
- Добавить Go-модель `NoteMedia`.
- Добавить CRUD helpers.
- Связать `Note` с `videos []NoteVideo` в ответах API.

### Этап 3. Backend direct video import

- Добавить provider detector.
- Добавить `/api/video/preview`.
- Добавить `/api/video/import`.
- Реализовать direct URL download.
- Добавить thumbnail generation.
- Добавить protected encryption для video files.

### Этап 4. Backend video serving

- Добавить `/api/video/<userId>/<file>`.
- Добавить `/api/video-thumbnail/<userId>/<file>`.
- Поддержать auth, owner check, `X-Media-Password`.
- Поддержать `Range` для обычных видео.

### Этап 5. Frontend model/service/provider

- Добавить `NoteVideo`.
- Обновить `Note`.
- Обновить `NotesService`.
- Обновить `NotesProvider`.
- Обновить client crypto для шифрования video metadata/path в protected notes.

### Этап 6. Editor UI

- Добавить video button.
- Добавить modal ввода URL.
- Добавить preview card.
- Добавить video attachments grid.
- Добавить удаление video attachment.

### Этап 7. View UI

- Добавить video grid.
- Добавить player screen.
- Добавить external/embed fallback для link-only sources.
- Проверить protected note flow.

### Этап 8. Cleanup and deletion

- При удалении заметки удалять video files и thumbnails.
- При удалении video attachment удалять file + thumbnail.
- Добавить cleanup orphan media.

### Этап 9. Проверки

Backend:

```bash
cd /Users/vlad/projects/bar/backend
go test ./...
```

Frontend:

```bash
flutter pub get
flutter analyze
flutter test
```

Ручные сценарии:

- direct `.mp4` добавляется в обычную заметку;
- direct `.mp4` добавляется в protected заметку;
- YouTube URL добавляется как link-only;
- Instagram URL добавляется как link-only/embed;
- удаление заметки удаляет video files;
- после перезапуска приложения video attachments подтягиваются из БД;
- fullscreen playback работает;
- нет доступа к чужому `/api/video/<otherUserId>/<file>`.

## Что не делать в MVP

- Не добавлять universal downloader через `yt-dlp` в публичную сборку.
- Не обходить private/restricted content.
- Не скачивать YouTube audiovisual content.
- Не хранить Instagram video file, если нет явного разрешения/официального API.
- Не пытаться поддержать все сайты сразу.

## Открытые решения

- Нужен ли embedded playback внутри приложения или достаточно external open для
  YouTube/Instagram на MVP.
- Максимальный размер video file.
- Нужны ли несколько видео на одну заметку или достаточно одного. План выше
  поддерживает несколько.
- Нужен ли background import, если приложение закрыто.
- Нужно ли сразу делать share extension, чтобы отправлять URL в smart_noties из
  Instagram/YouTube share sheet.

## Источники

- App Store: `Blackhole Spliter`, id `1624635075`.
- YouTube Terms of Service: `https://www.youtube.com/t/terms`.
- YouTube API Services Developer Policies:
  `https://developers.google.com/youtube/terms/developer-policies`.
- Instagram oEmbed / embeds:
  `https://developers.facebook.com/docs/instagram/oembed/`.
- Meta/Facebook Terms:
  `https://www.facebook.com/terms`.
