# Текущее состояние проекта smart_noties

Дата фиксации этапа: 2026-08-01.

Проект состоит из двух репозиториев:

- Flutter-приложение: `/Users/vlad/StudioProjects/smart_noties`.
- Go-бэкенд: `/Users/vlad/projects/bar/backend`.

Бэкенд работает на `:8070`. Базовый URL для приложения задаётся в
`lib/services/api_config.dart`.

## Что реализовано на фронте

### Авторизация и восстановление пароля

- Добавлен экран восстановления пароля: `lib/screens/forgot_password_screen.dart`.
- На экране логина добавлена ссылка `Забыли пароль?`.
- Если пользователь уже ввёл email на экране логина, этот email передаётся и
  предзаполняется на экране восстановления пароля.
- Добавлены методы:
  - `AuthService.resetPassword`;
  - `AuthProvider.resetPassword`.

### Загрузка заметок после перезапуска

- Раньше приложение после перезапуска показывало только локальные pending-заметки.
- Добавлена загрузка серверных заметок после авторизации:
  - `NotesService.fetchNotes`;
  - `NotesProvider.loadServerNotes`;
  - вызов загрузки в `_HomeRouter` из `lib/main.dart`.
- Пока список серверных заметок загружается, показывается `CircularProgressIndicator`.

### Режим просмотра и редактирования заметок

- Нажатие на заметку в списке теперь открывает режим просмотра, а не редактирование.
- Долгое нажатие открывает меню действий:
  - редактировать;
  - удалить.
- Добавлен экран просмотра `lib/screens/note_view_screen.dart`.
- Из режима просмотра можно вернуться назад.
- Для защищённых заметок просмотр доступен только после ввода пароля.
- После успешной проверки пароля фронт заменяет замаскированную заметку на
  расшифрованную версию, полученную от бэкенда.

### Профиль пользователя

- На стартовом экране и экране списка заметок добавлена аккуратная иконка профиля.
- Переход ведёт на `lib/screens/profile_screen.dart`.
- Иконка размещена справа от заголовка/основной надписи, не по центру экрана.

### Защищённые заметки

- В модель `Note` добавлены:
  - `isProtected`;
  - `protectionPassword`;
  - `hasProtection`.
- В редакторе заметки добавлена кнопка защиты.
- Для protected-заметки показывается иконка замка в списке.
- При открытии protected-заметки запрашивается пароль.
- При редактировании protected-заметки тоже запрашивается пароль.
- Пароль protected-заметки не логируется в открытом виде.
- Для protected-заметки в debug-логах маскируются `title` и `body`.
- Добавлен дополнительный клиентский слой шифрования protected-заметок:
  - поля шифруются на клиенте до отправки на backend;
  - формат клиентского шифротекста: `cenc:v1:<salt>:<secretBox>`;
  - backend поверх этого продолжает применять серверное шифрование.

### Цвет текста в режиме просмотра

- В режиме просмотра цвет текста выбирается по яркости фона:
  - на тёмном фоне белый текст;
  - на светлом фоне чёрный текст.

### Обложка и фотографии заметки

- Старое поле `imagePath` теперь используется как обложка заметки.
- Верхний блок изображения в редакторе стал кликабельным:
  - нажатие выбирает/меняет обложку;
  - обложка остаётся отдельной от фотографий внутри заметки.
- Добавлено поле `photoPaths` в модель `Note`.
- Нижняя кнопка камеры теперь добавляет фото внутрь заметки:
  - можно сделать одно фото;
  - можно выбрать одно или несколько фото из галереи.
- Фото внутри заметки отображаются отдельной горизонтальной лентой.
- В режиме просмотра фото можно открыть на весь экран:
  - тап по обложке открывает fullscreen;
  - тап по фото из ленты открывает fullscreen с выбранного фото;
  - fullscreen-режим использует `PageView`;
  - фото листаются свайпом;
  - поддерживается zoom через `InteractiveViewer`;
  - сверху показывается счётчик `N / total`.

### Web-совместимость

- Исправлена ошибка `Unsupported operation: Platform._operatingSystem`.
- `api_config.dart` больше не использует `dart:io Platform`; вместо этого:
  - `kIsWeb`;
  - `defaultTargetPlatform`.
- Для web базовый URL бэкенда: `http://localhost:8070`.
- Исправлена ошибка `Unsupported operation: _Namespace` при выборе фото в web:
  - выбранные картинки хранятся как `XFile`;
  - upload web-картинок идёт через bytes;
  - для blob-path превью используется `NetworkImage`, а не `FileImage(File(...))`.

### Голосовые заметки

- Сохранена существующая логика голосовых заметок:
  - локальная запись в temp-файл;
  - upload на бэкенд через `POST /api/upload/voice`;
  - воспроизведение серверного файла через защищённый endpoint с Bearer JWT.
- В режиме просмотра `VoiceMessagePlayer` используется без кнопки удаления.

## Что реализовано на бэкенде

### Общие изменения API

- `POST /api/notes` теперь берёт владельца заметки из JWT, а не доверяет `userId`
  из тела запроса.
- Добавлен `GET /api/notes`:
  - требует Bearer JWT;
  - возвращает только заметки текущего пользователя;
  - сортирует по `"createdAt" DESC`.
- Добавлен `PATCH /api/notes/<id>`:
  - сохраняет редактирование существующей заметки в БД;
  - проверяет владельца через JWT.
- Удаление заметки удаляет связанные серверные медиа-файлы:
  - voice;
  - cover image;
  - фото из `photoPaths`.

### Восстановление пароля

- Добавлен endpoint `POST /api/auth/reset-password`.
- Пароль пользователя обновляется через bcrypt-хеш.
- Формат ошибок сохраняет контракт `{"error": "..."}`.

### Защита и шифрование protected-заметок

- Добавлены/используются поля таблицы `notes`:
  - `"isProtected"`;
  - `"passwordHash"`;
  - `"encryptionSalt"`.
- Пароль заметки хранится только как bcrypt hash в `"passwordHash"`.
- Для protected-заметок реализовано серверное шифрование:
  - ключ получается из пароля заметки через `scrypt`;
  - алгоритм шифрования: `AES-GCM`;
  - каждое поле шифруется с отдельным nonce;
  - encrypted value хранится как строка `enc:v1:<base64>`.
- Шифруются поля:
  - `title`;
  - `body`;
  - `"imagePath"`;
  - `"photoPaths"`;
  - `"voicePath"`.
- `GET /api/notes` не отдаёт содержимое protected-заметок:
  - `title` маскируется как `Защищённая заметка`;
  - `body`, медиа-пути и voice очищаются;
  - остаётся флаг `"isProtected": true`.
- `POST /api/notes/<id>/verify-password`:
  - проверяет bcrypt-hеш пароля;
  - расшифровывает заметку;
  - возвращает расшифрованный `Note`.
- Legacy protected-заметки без `"encryptionSalt"` открываются по старому сценарию:
  - пароль проверяется через bcrypt;
  - plaintext-поля возвращаются как есть;
  - после следующего сохранения такая заметка будет записана уже в зашифрованном виде.

### Клиентское шифрование поверх серверного

- Добавлен файл `lib/services/note_client_crypto.dart`.
- Для protected-заметок клиент шифрует:
  - `title`;
  - `body`;
  - `imagePath`;
  - `photoPaths`;
  - `voicePath`.
- Клиентское шифрование использует:
  - `cryptography`;
  - `PBKDF2-HMAC-SHA256`;
  - 120000 итераций;
  - `AES-GCM 256-bit`;
  - случайную соль на каждое значение;
  - nonce, ciphertext и MAC внутри `SecretBox.concatenation()`.
- После `POST /api/notes/<id>/verify-password` backend снимает серверный слой,
  а клиент снимает клиентский слой.
- Это гибридная схема, не чистый E2E: backend всё ещё получает пароль, чтобы
  проверить bcrypt и снять серверное шифрование. Но в БД теперь лежит двойной слой:
  серверно-зашифрованный клиентский шифротекст.
- Для offline/pending protected-заметок клиентский шифротекст сохраняется в
  `SharedPreferences`, чтобы локальное хранилище не держало plaintext.

### Загрузка изображений

- Добавлен endpoint `POST /api/upload/image`.
- Файл сохраняется в `uploads/image/<userId>/`.
- Возвращается защищённый URL вида `/api/image/<userId>/<file>`.
- Поддерживаемые расширения:
  - `.jpg`;
  - `.jpeg`;
  - `.png`;
  - `.webp`;
  - `.heic`.
- Максимальный размер изображения: 15 MB.
- Добавлен endpoint `GET /api/image/<userId>/<file>`:
  - требует Bearer JWT;
  - отдаёт файл только владельцу.

### Отдельная защита media-файлов protected-заметок

- Для обычных заметок медиа-файлы сохраняются и отдаются как раньше.
- Для protected-заметок при загрузке фото, обложки или голоса фронт отправляет
  в multipart-запрос дополнительные поля:
  - `isProtected=true`;
  - `password=<пароль заметки>`.
- Backend шифрует содержимое файла перед записью на диск:
  - формат файла на диске: `smedia:v1:<salt>:<nonce+ciphertext>`;
  - ключ получается из пароля заметки через тот же `scrypt`-derivation;
  - алгоритм: `AES-GCM`.
- Поэтому файл из `uploads/image/<userId>/<file>` или
  `uploads/voice/<userId>/<file>` для protected-заметки нельзя открыть напрямую
  как обычную картинку/аудио: на диске лежит шифротекст.
- При чтении `/api/image/...` и `/api/voice/...` backend:
  - проверяет Bearer JWT и владельца файла по `userId` в пути;
  - если файл encrypted, требует header `X-Media-Password`;
  - расшифровывает файл в памяти и отдаёт клиенту исходные bytes.
- Фронт прокидывает `X-Media-Password` после успешной разблокировки protected-заметки:
  - в preview обложки и фото;
  - в fullscreen-галерее;
  - в `VoiceMessagePlayer`.
- Ограничение текущей реализации: если поменять пароль уже существующей
  protected-заметки, ранее загруженные encrypted media-файлы остаются
  зашифрованными старым паролем. Их нужно переупаковать отдельной миграцией/API
  или загрузить заново.
- Медиа-файлы, загруженные до появления этого слоя защиты, автоматически не
  шифруются: backend не знает plaintext-пароль заметки. Для защиты старого файла
  его нужно загрузить заново в уже разблокированную protected-заметку.

### CORS для web

- Добавлен middleware `withCORS`.
- Разрешены:
  - `Authorization`;
  - `Content-Type`;
  - `X-Media-Password`;
  - методы `GET, POST, PATCH, DELETE, OPTIONS`.
- Это нужно для запуска Flutter web на `localhost:<порт>` и API на `localhost:8070`.

## Миграции БД

Актуальные новые миграции:

- `005_add_note_protection.sql`
  - добавляет `"isProtected"`;
  - добавляет `"passwordHash"`.
- `006_add_note_photo_paths.sql`
  - добавляет `"photoPaths" TEXT[] NOT NULL DEFAULT '{}'`.
- `007_add_note_encryption_salt.sql`
  - добавляет `"encryptionSalt" TEXT NOT NULL DEFAULT ''`.

Миграции применяются автоматически при старте backend через `runMigrations`.

## Текущий JSON-контракт заметки

На фронте и бэке используется модель:

- `id`;
- `title`;
- `body`;
- `imagePath`;
- `photoPaths`;
- `voicePath`;
- `isVoice`;
- `isVideo`;
- `color`;
- `userId`;
- `isProtected`;
- `createdAt`;
- `updatedAt`.

Поле `protectionPassword` отправляется с фронта только при создании/сохранении
protected-заметки. В ответах API пароль не возвращается.

## Медиа-пути

- `imagePath` - обложка заметки.
- `photoPaths` - фото внутри заметки.
- `voicePath` - голосовая запись.
- Серверные медиа-пути имеют вид:
  - `/api/image/<userId>/<file>`;
  - `/api/voice/<userId>/<file>`.
- Для отображения относительные пути приводятся к полному URL через
  `resolveMediaUrl`.

## Проверки, которые выполнялись

Бэкенд:

```bash
cd /Users/vlad/projects/bar/backend
go test ./...
```

Результат: проходит.

Фронт:

```bash
flutter analyze
```

Сейчас на этой машине падает не на коде проекта, а из-за локального Flutter/Dart SDK:

```text
cpuinfo_macos.cc: 42: error: unreachable code
version=3.5.1 ... on "macos_x64"
```

Проблема окружения: x64 Dart SDK запускается на arm64 Mac.

Также из-за этой же проблемы сейчас падает:

```bash
flutter pub get
```

После исправления Flutter SDK нужно выполнить `flutter pub get`, потому что в
`pubspec.yaml` добавлена зависимость `cryptography`.

## Важные проблемы окружения

### Backend на `:8070`

Несколько раз порт `8070` был занят процессом `___go_build_backend` из GoLand,
но `curl http://localhost:8070/health` не отвечал.

Симптомы:

- Flutter web показывает `ClientException: Failed to fetch`;
- upload фото не работает;
- login из web не работает.

Нужно остановить старый процесс backend в GoLand и запустить свежий backend из
актуального кода:

```bash
cd /Users/vlad/projects/bar/backend
go run .
```

### iOS device signing

Сборка на реальное iOS-устройство доходила до Xcode signing и падала на:

```text
Failed to codesign ... Flutter.framework
```

Проверка:

```bash
security find-identity -v -p codesigning
```

Показывала:

```text
0 valid identities found
```

Это не ошибка Dart-кода. Нужно настроить Apple Development certificate в Xcode:

- Xcode -> Settings -> Accounts;
- выбрать Apple ID;
- Manage Certificates;
- создать/обновить Apple Development certificate;
- открыть `ios/Runner.xcworkspace`;
- проверить `Signing & Capabilities`;
- включить `Automatically manage signing`;
- выбрать правильную Team.

### Android emulator

Ранее эмулятор запускался командой:

```bash
/Users/vlad/Library/Android/sdk/emulator/emulator -avd Pixel_9_Pro_XL
```

Если возникает ошибка multiple emulators with same AVD, нужно завершить старый
экземпляр или запускать read-only режим.

## Что важно помнить при дальнейшей разработке

- После изменений backend нужно перезапускать, иначе новые endpoint'ы, CORS,
  миграции и шифрование не применятся.
- Для web нельзя использовать `dart:io File` напрямую для выбранных картинок.
  Нужно работать через `XFile`/bytes или web-safe image provider.
- Protected-заметки в списке намеренно замаскированы. Реальные данные приходят
  только после `verify-password`.
- Для protected-заметок теперь есть два слоя:
  - клиентский `cenc:v1`;
  - серверный `enc:v1`.
- Старые protected-заметки, созданные до шифрования, не зашифруются сами по себе,
  потому что пароль не известен миграции. Они будут зашифрованы после открытия и
  повторного сохранения.
- `imagePath` оставлен для обратной совместимости и теперь означает обложку.
- `photoPaths` хранит фотографии внутри заметки.

## Файлы, которые особенно важны на текущем этапе

Фронтенд:

- `lib/services/api_config.dart`;
- `lib/models/note_model.dart`;
- `lib/services/auth_service.dart`;
- `lib/services/notes_service.dart`;
- `lib/services/note_client_crypto.dart`;
- `lib/providers/auth_provider.dart`;
- `lib/providers/notes_provider.dart`;
- `lib/screens/login_screen.dart`;
- `lib/screens/forgot_password_screen.dart`;
- `lib/screens/start_screen.dart`;
- `lib/screens/notes_grid_screen.dart`;
- `lib/screens/note_edit_screen.dart`;
- `lib/screens/note_view_screen.dart`;
- `lib/screens/profile_screen.dart`;
- `lib/widgets/voice_message_player.dart`.

Бэкенд:

- `/Users/vlad/projects/bar/backend/main.go`;
- `/Users/vlad/projects/bar/backend/notes.go`;
- `/Users/vlad/projects/bar/backend/note_crypto.go`;
- `/Users/vlad/projects/bar/backend/media_crypto.go`;
- `/Users/vlad/projects/bar/backend/upload.go`;
- `/Users/vlad/projects/bar/backend/users.go`;
- `/Users/vlad/projects/bar/backend/types.go`;
- `/Users/vlad/projects/bar/backend/auth/login.go`;
- `/Users/vlad/projects/bar/backend/auth/verify.go`;
- `/Users/vlad/projects/bar/backend/migrations/005_add_note_protection.sql`;
- `/Users/vlad/projects/bar/backend/migrations/006_add_note_photo_paths.sql`;
- `/Users/vlad/projects/bar/backend/migrations/007_add_note_encryption_salt.sql`.
