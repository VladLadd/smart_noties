enum AppLanguage {
  ru('ru'),
  en('en');

  final String code;

  const AppLanguage(this.code);

  static AppLanguage fromCode(String? code) {
    if (code == 'en') return AppLanguage.en;
    return AppLanguage.ru;
  }
}

class AppStrings {
  final AppLanguage language;

  const AppStrings(this.language);

  bool get _ru => language == AppLanguage.ru;

  String get languageLabel => _ru ? 'Язык' : 'Language';
  String get russian => _ru ? 'Русский' : 'Russian';
  String get english => _ru ? 'Английский' : 'English';

  String get profile => _ru ? 'Профиль' : 'Profile';
  String get logout => _ru ? 'Выйти' : 'Log out';
  String get logoutQuestion => _ru ? 'Выйти из аккаунта?' : 'Log out?';
  String get cancel => _ru ? 'Отмена' : 'Cancel';
  String get hide => _ru ? 'Скрыть' : 'Hide';
  String get open => _ru ? 'Открыть' : 'Open';
  String get delete => _ru ? 'Удалить' : 'Delete';
  String get edit => _ru ? 'Редактировать' : 'Edit';
  String get refresh => _ru ? 'Обновить' : 'Refresh';
  String get copy => _ru ? 'Копировать' : 'Copy';
  String get close => _ru ? 'Закрыть' : 'Close';
  String get save => _ru ? 'Сохранить' : 'Save';
  String get send => _ru ? 'Отправить' : 'Send';
  String get select => _ru ? 'Выбрать' : 'Select';
  String get replace => _ru ? 'Заменить' : 'Replace';
  String get add => _ru ? 'Добавить' : 'Add';
  String get check => _ru ? 'Проверить' : 'Check';
  String get back => _ru ? 'Назад' : 'Back';

  String get email => 'Email';
  String get phone => _ru ? 'Телефон' : 'Phone';
  String get phoneNumber => _ru ? 'Номер телефона' : 'Phone number';
  String get password => _ru ? 'Пароль' : 'Password';
  String get newPassword => _ru ? 'Новый пароль' : 'New password';
  String get confirmPassword => _ru ? 'Подтвердите пароль' : 'Confirm password';
  String get name => _ru ? 'Имя' : 'Name';

  String get welcome => _ru ? 'Добро\nпожаловать' : 'Welcome\nback';
  String get signInSubtitle =>
      _ru ? 'Войдите в свой аккаунт' : 'Sign in to your account';
  String get forgotPassword => _ru ? 'Забыли пароль?' : 'Forgot password?';
  String get signIn => _ru ? 'Войти' : 'Sign in';
  String get getCode => _ru ? 'Получить код' : 'Get code';
  String get noAccount => _ru ? 'Нет аккаунта? ' : 'No account? ';
  String get register => _ru ? 'Зарегистрироваться' : 'Create one';
  String get createAccount => _ru ? 'Создать\nаккаунт' : 'Create\naccount';
  String get createAccountButton => _ru ? 'Создать аккаунт' : 'Create account';
  String get registerSubtitle =>
      _ru ? 'Зарегистрируйтесь, чтобы начать' : 'Register to get started';
  String get alreadyHaveAccount =>
      _ru ? 'Уже есть аккаунт? ' : 'Already have an account? ';
  String get resetPasswordTitle => _ru ? 'Сброс\nпароля' : 'Reset\npassword';
  String get resetPasswordSubtitle => _ru
      ? 'Введите email и новый пароль'
      : 'Enter your email and a new password';
  String get updatePassword => _ru ? 'Обновить пароль' : 'Update password';
  String get passwordUpdated => _ru ? 'Пароль обновлён' : 'Password updated';
  String get smsCodeTitle => _ru ? 'Введите\nкод из SMS' : 'Enter\nSMS code';
  String smsCodeSent(String phone) =>
      _ru ? 'Код отправлен на $phone' : 'Code sent to $phone';
  String get smsCode => _ru ? 'SMS-код' : 'SMS code';
  String get confirm => _ru ? 'Подтвердить' : 'Confirm';
  String get sending => _ru ? 'Отправляем...' : 'Sending...';
  String get resendCode => _ru ? 'Отправить код ещё раз' : 'Send code again';
  String get codeSentAgain =>
      _ru ? 'Код отправлен повторно' : 'Code sent again';
  String get phoneCodeHelp => _ru
      ? 'Мы отправим SMS-код для входа. В dev-режиме код выводится в лог backend.'
      : 'We will send an SMS sign-in code. In dev mode the code is printed in the backend log.';

  String get enterEmail => _ru ? 'Введите email' : 'Enter email';
  String get invalidEmail => _ru ? 'Некорректный email' : 'Invalid email';
  String get enterPassword => _ru ? 'Введите пароль' : 'Enter password';
  String get enterNewPassword =>
      _ru ? 'Введите новый пароль' : 'Enter a new password';
  String get enterName => _ru ? 'Введите имя' : 'Enter name';
  String get minSixChars => _ru ? 'Минимум 6 символов' : 'Minimum 6 characters';
  String get passwordsDoNotMatch =>
      _ru ? 'Пароли не совпадают' : 'Passwords do not match';
  String get enterPhoneNumber =>
      _ru ? 'Введите номер телефона' : 'Enter phone number';
  String get invalidPhoneNumber =>
      _ru ? 'Некорректный номер телефона' : 'Invalid phone number';
  String get enterSixDigitCode =>
      _ru ? 'Введите 6-значный код' : 'Enter a 6-digit code';

  String get noNotesTitle => _ru ? 'У вас пока\nнет заметок' : 'No notes\nyet';
  String get noNotesSubtitle => _ru
      ? 'Нажмите на плюсик,\nчтобы создать первую'
      : 'Tap the plus button\nto create your first note';
  String get showList => _ru ? 'Показать списком' : 'Show as list';
  String get showGrid => _ru ? 'Показать плитками' : 'Show as grid';
  String get protectedNote => _ru ? 'Защищённая заметка' : 'Protected note';
  String get protectedNoteMultiline =>
      _ru ? 'Защищённая\nзаметка' : 'Protected\nnote';
  String get noteProtection => _ru ? 'Защита заметки' : 'Note protection';
  String get removeProtection => _ru ? 'Снять защиту' : 'Remove protection';
  String get enterPasswordButton => _ru ? 'Ввести пароль' : 'Enter password';
  String get enterPasswordToView =>
      _ru ? 'Введите пароль для просмотра' : 'Enter password to view';
  String get enterPasswordToReadNote => _ru
      ? 'Для чтения этой заметки введите пароль.'
      : 'Enter the password to read this note.';
  String get enterPasswordToReadAndEditNote => _ru
      ? 'Введите пароль, чтобы читать и редактировать заметку.'
      : 'Enter the password to read and edit this note.';
  String get enterPasswordToEditNote => _ru
      ? 'Для редактирования этой заметки введите пароль.'
      : 'Enter the password to edit this note.';
  String get passwordMinSix => _ru
      ? 'Пароль должен быть не короче 6 символов'
      : 'Password must be at least 6 characters';
  String get noTitle => _ru ? 'Без заголовка' : 'Untitled';
  String get noText => _ru ? 'Нет текста' : 'No text';
  String get notUploaded =>
      _ru ? 'Не отправлено на сервер' : 'Not uploaded to server';
  String get deleteNoteQuestion => _ru ? 'Удалить заметку?' : 'Delete note?';
  String get deleteNote => _ru ? 'Удалить заметку' : 'Delete note';
  String get noteWillBeDeleted =>
      _ru ? 'Заметка будет удалена.' : 'The note will be deleted.';
  String get replaceImageQuestion =>
      _ru ? 'Заменить картинку?' : 'Replace image?';
  String get replaceImageMessage => _ru
      ? 'Выбранный цвет заменит текущее изображение заметки.'
      : 'The selected color will replace the current note image.';
  String get coverImage => _ru ? 'Обложка заметки' : 'Note cover';
  String get notePhotos => _ru ? 'Фотографии заметки' : 'Note photos';
  String get takePhoto => _ru ? 'Сделать фото' : 'Take photo';
  String get chooseOneOrMorePhotos =>
      _ru ? 'Выбрать одно или несколько фото' : 'Choose one or more photos';
  String get chooseFromGallery =>
      _ru ? 'Выбрать из галереи' : 'Choose from gallery';
  String get chooseCoverTap =>
      _ru ? 'Нажмите, чтобы выбрать обложку' : 'Tap to choose cover';
  String get titleHint => _ru ? 'Заголовок...' : 'Title...';
  String get bodyHint =>
      _ru ? 'Введите текст заметки...' : 'Enter note text...';
  String get preview => _ru ? 'Предпросмотр' : 'Preview';
  String get editor => _ru ? 'Редактор' : 'Editor';
  String get bold => _ru ? 'Жирный' : 'Bold';
  String get italic => _ru ? 'Курсив' : 'Italic';
  String get heading => _ru ? 'Заголовок' : 'Heading';
  String get bulletList => _ru ? 'Маркированный список' : 'Bullet list';
  String get numberedList => _ru ? 'Нумерованный список' : 'Numbered list';
  String get checklist => _ru ? 'Чеклист' : 'Checklist';
  String get quote => _ru ? 'Цитата' : 'Quote';
  String get inlineCode => _ru ? 'Код' : 'Code';
  String get link => _ru ? 'Ссылка' : 'Link';
  String get formattedTextPreview => _ru
      ? 'Здесь будет предпросмотр форматированного текста'
      : 'Formatted text preview will appear here';
  String get boldSample => _ru ? 'жирный текст' : 'bold text';
  String get italicSample => _ru ? 'курсив' : 'italic';
  String get headingSample => _ru ? 'Заголовок' : 'Heading';
  String get listItemSample => _ru ? 'Пункт списка' : 'List item';
  String get taskSample => _ru ? 'Задача' : 'Task';
  String get quoteSample => _ru ? 'Цитата' : 'Quote';
  String get codeSample => _ru ? 'код' : 'code';
  String get linkSample => _ru ? 'ссылка' : 'link';
  String get drawOnBackground =>
      _ru ? 'Рисовать на фоне' : 'Draw on background';
  String get drawOnNote => _ru ? 'Рисовать по заметке' : 'Draw on note';
  String get closeDrawing => _ru ? 'Закрыть рисование' : 'Close drawing';
  String get pen => _ru ? 'Карандаш' : 'Pen';
  String get eraser => _ru ? 'Ластик' : 'Eraser';
  String get undo => _ru ? 'Отменить' : 'Undo';
  String get redo => _ru ? 'Повторить' : 'Redo';
  String get clearDrawing => _ru ? 'Очистить рисунок' : 'Clear drawing';
  String get uploadToServer => _ru ? 'Отправить на сервер' : 'Upload to server';
  String get hideNoteByNfc =>
      _ru ? 'Скрыть заметку по NFC' : 'Hide note by NFC';
  String get removeNfcHiding =>
      _ru ? 'Убрать скрытие по NFC' : 'Remove NFC hiding';
  String get protectNote => _ru ? 'Защитить заметку' : 'Protect note';
  String get changeProtection => _ru ? 'Изменить защиту' : 'Change protection';
  String get openHiddenFirst => _ru
      ? 'Сначала откройте скрытые заметки по NFC'
      : 'Open hidden notes by NFC first';
  String get hiddenNotesHidden =>
      _ru ? 'Скрытые заметки скрыты' : 'Hidden notes are hidden';
  String get hiddenNotesOpened => _ru
      ? 'Скрытые заметки открыты на 10 минут'
      : 'Hidden notes are open for 10 minutes';
  String get nfcWaitingTitle =>
      _ru ? 'Приложите NFC-карту' : 'Hold your NFC card near';
  String get nfcWaitingMessage => _ru
      ? 'Приложение ждёт метку со smart_noties NFC-токеном.'
      : 'The app is waiting for a tag with a smart_noties NFC token.';
  String get showHiddenByNfc =>
      _ru ? 'Показать скрытые заметки по NFC' : 'Show hidden notes by NFC';
  String hideHiddenWithRemaining(String value) =>
      _ru ? 'Скрыть скрытые заметки ($value)' : 'Hide hidden notes ($value)';
  String get faceDownHidden => _ru
      ? 'Телефон перевёрнут: скрытые заметки скрыты'
      : 'Phone is face down: hidden notes are hidden';
  String get micPermissionRequired => _ru
      ? 'Нужен доступ к микрофону для записи'
      : 'Microphone access is required';
  String get authRequiredToSend => _ru
      ? 'Необходима авторизация для отправки'
      : 'Authorization is required to upload';
  String get voiceNotUploadedLocal => _ru
      ? 'Голос не загружен, сохранён локально'
      : 'Voice was not uploaded, saved locally';
  String get imageNotUploadedLocal => _ru
      ? 'Изображение не загружено, сохранён локальный путь'
      : 'Image was not uploaded, local path saved';
  String get localProtectionWarning => _ru
      ? 'Защита включена локально. Перезапустите backend для сохранения на сервере.'
      : 'Protection was enabled locally. Restart the backend to save it on the server.';
  String get video => _ru ? 'Видео' : 'Video';
  String get record => _ru ? 'Запись' : 'Recording';
  String get stop => _ru ? 'Стоп' : 'Stop';
  String get saveUpper => _ru ? 'СОХРАНИТЬ' : 'SAVE';
  String get saveNoteFirstAddVideo => _ru
      ? 'Сначала сохраните заметку, затем добавьте видео'
      : 'Save the note first, then add video';
  String get syncNoteFirst =>
      _ru ? 'Сначала синхронизируйте заметку' : 'Sync the note first';
  String get protectedVideoUnsupported => _ru
      ? 'Видео для защищённых заметок пока не поддерживается'
      : 'Video for protected notes is not supported yet';
  String get deleteVideoQuestion => _ru ? 'Удалить видео?' : 'Delete video?';
  String get videoWillBeDeleted =>
      _ru ? 'Видео будет удалено.' : 'The video will be deleted.';
  String get videoLinkUnavailable =>
      _ru ? 'Ссылка на видео недоступна' : 'Video link is unavailable';
  String get pasteLink => _ru ? 'Вставьте ссылку' : 'Paste a link';
  String get addVideo => _ru ? 'Добавить видео' : 'Add video';
  String get videoLink => _ru ? 'Ссылка на видео' : 'Video link';
  String get audioLoadFailed =>
      _ru ? 'Не удалось загрузить аудио' : 'Could not load audio';
  String get videoFileUnavailable =>
      _ru ? 'Файл видео недоступен' : 'Video file is unavailable';
  String get invalidVideoPath =>
      _ru ? 'Некорректный путь видео' : 'Invalid video path';
  String get videoOpenFailed =>
      _ru ? 'Не удалось открыть видео' : 'Could not open video';
  String get pause => _ru ? 'Пауза' : 'Pause';
  String get play => _ru ? 'Воспроизвести' : 'Play';

  String get notesCount => _ru ? 'Заметок' : 'Notes';
  String get needAuth => _ru ? 'Нужна авторизация' : 'Authorization required';
  String get requestSentToAdmin =>
      _ru ? 'Запрос отправлен администратору' : 'Request sent to admin';
  String get nfcTokenCopied =>
      _ru ? 'NFC-токен скопирован' : 'NFC token copied';
  String get hideTokenQuestion =>
      _ru ? 'Скрыть токен из профиля?' : 'Hide token from profile?';
  String get hideTokenMessage => _ru
      ? 'После этого ссылка больше не будет показываться в профиле. Сама NFC-карта останется активной.'
      : 'After this, the link will no longer be shown in the profile. The NFC card itself will remain active.';
  String get requestNfcToken =>
      _ru ? 'Запросить NFC-токен' : 'Request NFC token';
  String get cardName => _ru ? 'Название карты' : 'Card name';
  String get cardNameHint =>
      _ru ? 'Например: ключи или рабочая карта' : 'Example: keys or work card';
  String get nfcToken => _ru ? 'NFC-токен' : 'NFC token';
  String get nfcTokenEmpty => _ru
      ? 'Запросите токен, администратор одобрит выдачу, и здесь появится ссылка для записи на NFC-карту.'
      : 'Request a token, the admin will approve it, and a link for writing to an NFC card will appear here.';
  String get iWroteCard => _ru ? 'Я записал карту' : 'I wrote the card';
  String get approved => _ru ? 'Одобрен' : 'Approved';
  String get rejected => _ru ? 'Отклонен' : 'Rejected';
  String get consumed => _ru ? 'Записан' : 'Written';
  String get pending => _ru ? 'Ожидает' : 'Pending';
  String get revoked => _ru ? 'Отозван' : 'Revoked';
  String get nfcKeyRevoked =>
      _ru ? 'Карта отозвана администратором' : 'Card revoked by administrator';
  String approvedAt(String value) =>
      _ru ? 'Одобрено $value' : 'Approved $value';
  String rejectedAt(String value) =>
      _ru ? 'Отклонено $value' : 'Rejected $value';
  String consumedAt(String value) => _ru ? 'Записано $value' : 'Written $value';
  String createdAt(String value) => _ru ? 'Создано $value' : 'Created $value';

  String get chooseColor => _ru ? 'Выберите цвет' : 'Choose color';
}
