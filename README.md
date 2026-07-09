# smart_noties

Мобильное приложение для заметок на **Flutter**. Поддерживает текстовые,
голосовые и «цветные» заметки, аутентификацию по JWT и офлайн-режим с
последующей синхронизацией.

## Возможности

- 📝 **Заметки** — заголовок, текст, изображение, цвет фона.
- 🎙️ **Голосовые заметки** — запись через `flutter_sound`, аудио заливается на
  сервер и раздаётся только владельцу (защита по Bearer JWT).
- 🔐 **Аутентификация** — регистрация и логин, JWT + userId хранятся в
  `shared_preferences`, автологин при старте.
- 📶 **Офлайн-режим** — если нет сети (или токена), заметка сохраняется локально
  с пометкой `isPending` и досинхронизируется позже.
- 🎨 **Темы и оформление** — Material Design, `google_fonts`, анимации
  (`flutter_animate`).

## Технологии

| Слой        | Стек                                                            |
|-------------|-----------------------------------------------------------------|
| Фронтенд    | Flutter, Dart `^3.5.1`                                           |
| State-mgmt  | `provider` (`ChangeNotifier`)                                    |
| Сеть        | `http`                                                          |
| Хранилище   | `shared_preferences`                                            |
| Медиа       | `image_picker`, `flutter_sound`, `permission_handler`           |
| UI          | `google_fonts`, `flutter_animate`, `cupertino_icons`            |

## Структура проекта

```
lib/
├── main.dart            # точка входа: MultiProvider + роутинг по AuthStatus
├── models/              # модели (Note: copyWith / toJson / fromJson)
├── services/            # HTTP-клиенты (AuthService, NotesService), api_config.dart
├── providers/           # AuthProvider, NotesProvider — состояние + вызовы сервисов
├── screens/             # экраны: login, register, start, notes_grid, note_edit, …
├── widgets/             # переиспользуемые виджеты (VoiceMessagePlayer, color picker)
├── theme/               # app_theme.dart
└── data/                # статические данные
```

Поток управления: `main.dart` поднимает `MultiProvider` с `AuthProvider` и
`NotesProvider`; `_HomeRouter` роутит по `AuthStatus`
(`checking → login / grid / start`).

## Быстрый старт

### Требования

- Flutter SDK с Dart `^3.5.1`
- Доступный API-сервер на `:8070`
- Для Android — **JDK 17** (не 21, см. [примечание о тулчейне](#сборка-под-android))

### Запуск

```bash
flutter pub get      # установить зависимости
flutter run          # запустить (нужен доступный API-сервер на :8070)
```

Полезные команды:

```bash
flutter analyze      # статический анализ (flutter_lints ^4.0.0)
flutter test         # тесты
```

## Настройка сети (адрес API-сервера)

Базовый URL задаётся в `lib/services/api_config.dart` (`apiBaseUrl`) и выбирается
по платформе автоматически:

| Платформа                     | Адрес                          |
|-------------------------------|--------------------------------|
| Android-эмулятор              | `http://10.0.2.2:8070`         |
| iOS-симулятор / desktop       | `http://localhost:8070`        |
| Реальное устройство           | `http://<IP-хоста>:8070` (та же сеть) |

> **Почему так:** `localhost` внутри эмулятора указывает на сам эмулятор, а не на
> host-машину. `10.0.2.2` — спец-алиас Android-эмулятора на localhost хоста.
> Для реального устройства нужен IP хоста в локальной сети; Android дополнительно
> может требовать `android:usesCleartextTraffic="true"` для HTTP.

Симптом неверного адреса: `Connection refused` при логине/регистрации, хотя
`curl http://localhost:8070/health` на хосте отвечает `ok`.

## Сборка под Android

Проект завязан на **AGP 7.3.0**, поэтому три параметра зафиксированы вручную —
**не сбрасывать «на дефолт»**, иначе `flutter run` падает:

| Настройка          | Значение | Где                            | Зачем                                    |
|--------------------|----------|--------------------------------|------------------------------------------|
| JDK для Gradle     | **17**   | `android/gradle.properties`    | AGP 7.3.0 несовместим с JDK 21           |
| `compileSdk`       | **34**   | `android/app/build.gradle`     | встроенный `aapt2` не читает android-35   |
| Kotlin             | **1.9.24** | `android/settings.gradle`    | старый Kotlin не компилирует `shared_preferences_android` |

Warning'и «plugin requires Android SDK 35 … backward compatible» — некритичны,
это следствие `compileSdk 34`. Долгосрочный фикс — обновить AGP до 8.x, тогда
костыли можно убрать.

> Путь к JDK 17 (`org.gradle.java.home`) машинно-зависимый — на другой машине
> поправить.

## Как это работает: ключевые детали

- **Auth.** Токен и userId в `shared_preferences`. `AuthProvider` умеет доставать
  userId из JWT-payload вручную, если сервер не вернул `id` в теле.
- **Голосовые заметки.** Запись пишется в temp-файл; при сохранении заливается на
  сервер, и в `voicePath` пишется **серверный URL**, а не локальный путь.
  Скачивание — через защищённый эндпоинт с Bearer JWT (чужой файл → 403).
  Плеер скачивает удалённый файл в кэш и играет локально; свежую локальную запись
  играет напрямую. Если аплоад не удался — остаётся локальный путь (fallback).
- **Офлайн.** Нет сети/токена → `NotesProvider._saveLocally` сохраняет заметку с
  `isPending: true` и id вида `local_<timestamp>`; позже — `syncNote`.
- **Удаление.** Серверная заметка удаляется запросом `DELETE /api/notes/<id>`
  (сервер проверяет владельца и сносит аудио-файл); локальные — только из памяти.
