import '../l10n/app_strings.dart';

const nfcToolsAppStoreUrl = 'https://apps.apple.com/app/nfc-tools/id1252962749';
const nfcToolsGooglePlayUrl =
    'https://play.google.com/store/apps/details?id=com.wakdev.wdnfc';

class FaqEntry {
  final String id;
  final String question;
  final String answer;
  const FaqEntry(this.id, this.question, this.answer);
}

List<FaqEntry> nfcFaq(AppLanguage language) => language == AppLanguage.ru
    ? const [
        FaqEntry('purpose', 'Для чего нужна NFC-карта?',
            'NFC-карта открывает скрытые заметки, связанные с её токеном. Сами заметки хранятся в Smart Notes, а на карту записывается ссылка доступа. Для проверки токена нужно войти в свой аккаунт и подключиться к интернету.'),
        FaqEntry('request', 'Как получить NFC-токен?',
            'Откройте «Профиль» → «NFC-токен» → «Запросить NFC-токен». Дождитесь одобрения администратора и обновите список кнопкой со стрелкой. У одобренного запроса появится ссылка и кнопка «Копировать».'),
        FaqEntry(
            'write',
            'Как записать токен через NFC Tools?',
            '1. Установите NFC Tools от разработчика wakdev по ссылкам выше.\n'
                '2. В профиле Smart Notes скопируйте ссылку одобренного NFC-токена целиком.\n'
                '3. В NFC Tools откройте «Запись / Write» → «Добавить запись / Add a record» → «Текст / Text».\n'
                '4. Вставьте скопированную ссылку без изменений: она начинается с smartnoties://. Не добавляйте к ней https:// и не удаляйте параметры.\n'
                '5. Подтвердите запись, нажмите «Записать / Write» и поднесите совместимую NFC-карту к телефону.\n'
                '6. После успешной записи вернитесь в Smart Notes и проверьте карту через кнопку показа скрытых заметок.\n\n'
                'Используйте свою перезаписываемую карту с достаточным объёмом памяти. Названия пунктов NFC Tools могут отличаться в разных версиях. Не включайте необратимую блокировку записи, если хотите менять токен на карте.'),
        FaqEntry('open', 'Как скрыть заметку и открыть её картой?',
            'На экране списка заметок нажмите кнопку показа скрытых заметок с перечёркнутым глазом и приложите карту во время сканирования. Затем откройте нужную заметку, выберите «Скрыть заметку по NFC» и сохраните её. Для последующего доступа снова используйте кнопку показа скрытых заметок и ту же карту. NFC не заменяет пароль, если заметка дополнительно защищена паролем.'),
        FaqEntry('device', 'Почему телефон не читает карту?',
            'Проверьте поддержку NFC телефоном и совместимость карты. На Android включите NFC в настройках. Запустите сканирование внутри Smart Notes и удерживайте карту возле NFC-антенны телефона до результата; положение антенны зависит от модели. Уберите толстый или металлический чехол. Проверьте чтение карты в NFC Tools. Банковские и транспортные карты могут быть непригодны для записи вашего токена.'),
        FaqEntry(
            'invalid',
            'Что означает «NFC-токен недействителен или отозван»?',
            'Токен мог быть отозван, принадлежать другому аккаунту или быть записан с ошибкой. Убедитесь, что вы вошли в нужный аккаунт, обновите список токенов в профиле и проверьте статус. Прочитайте карту в NFC Tools и сравните запись с полной ссылкой одобренного токена. Если ошибка остаётся, обратитесь к администратору. Наличие записи на карте само по себе не означает, что токен активен.'),
        FaqEntry('lost', 'Что делать, если карта потеряна?',
            'В профиле нажмите «Отозвать все NFC-токены» или попросите администратора отозвать потерянную карту. После отзыва её токен перестанет открывать скрытые заметки; сами заметки не удаляются. Запросите новый токен. Если потерян доступ к ранее скрытым заметкам, обратитесь к администратору.'),
        FaqEntry('secret', 'Можно ли делиться ссылкой NFC-токена?',
            'Ссылка содержит секрет доступа. Не публикуйте её, не пересылайте посторонним и не показывайте на скриншотах. Записывайте её только на свою карту. Если ссылка стала известна другому человеку, отзовите токен и запросите новый. Скрытие ссылки в профиле не отзывает токен — карта остаётся активной.'),
        FaqEntry('web', 'Работает ли NFC в браузере?',
            'Веб-версия Smart Notes не поддерживает чтение NFC-карт. Для сканирования используйте мобильное приложение на устройстве с NFC. Открывайте скрытые заметки через кнопку сканирования внутри приложения: автоматический запуск по касанию карты не требуется.'),
      ]
    : const [
        FaqEntry('purpose', 'What is the NFC card for?',
            'An NFC card opens hidden notes associated with its token. Notes stay in Smart Notes; the card stores an access link. Sign in to your account and connect to the internet to validate the token.'),
        FaqEntry('request', 'How do I get an NFC token?',
            'Open Profile → NFC token → Request NFC token. Wait for administrator approval, then refresh the list using the arrow button. An approved request shows a link and a Copy button.'),
        FaqEntry(
            'write',
            'How do I write the token using NFC Tools?',
            '1. Install NFC Tools by wakdev using the links above.\n'
                '2. Copy the complete approved NFC token link from your Smart Notes profile.\n'
                '3. In NFC Tools, open Write → Add a record → Text.\n'
                '4. Paste the link unchanged. It starts with smartnoties://. Do not add https:// or remove any parameters.\n'
                '5. Confirm the record, tap Write and hold a compatible NFC card near your phone.\n'
                '6. After writing succeeds, return to Smart Notes and check the card using the show hidden notes button.\n\n'
                'Use your own writable card with enough free memory. NFC Tools labels may vary by version. Do not permanently lock the card if you want to change its token later.'),
        FaqEntry('open', 'How do I hide a note and open it with a card?',
            'On the notes list, tap the show hidden notes button with the crossed-out eye and scan your card. Open the note, select “Hide note by NFC” and save it. To access it later, use the show hidden notes button and the same card again. NFC does not replace a password if the note also has password protection.'),
        FaqEntry('device', 'Why does my phone not read the card?',
            'Check NFC support on your phone and card compatibility. Enable NFC in Android settings. Start scanning inside Smart Notes and hold the card near the phone’s NFC antenna until you get a result; antenna placement varies. Remove thick or metal cases. Check the card in NFC Tools. Payment and transit cards may not allow writing your token.'),
        FaqEntry('invalid', 'What does “Invalid or revoked NFC token” mean?',
            'The token may have been revoked, belong to another account or be written incorrectly. Check your account, refresh tokens in your profile and check the status. Read the card in NFC Tools and compare its record with the complete approved token link. Contact the administrator if the error persists. A record on a card does not guarantee that the token is active.'),
        FaqEntry('lost', 'What if I lose my card?',
            'Use “Revoke all NFC tokens” in your profile or ask the administrator to revoke the lost card. Its token will stop opening hidden notes; the notes themselves are not deleted. Request a new token. Contact the administrator if you have lost access to previously hidden notes.'),
        FaqEntry('secret', 'Can I share my NFC token link?',
            'The link contains an access secret. Do not publish it, send it to other people or expose it in screenshots. Write it only to your own card. If someone else learns the link, revoke the token and request a new one. Hiding the link in your profile does not revoke the token: the card stays active.'),
        FaqEntry('web', 'Does NFC work in a browser?',
            'Smart Notes on the web does not read NFC cards. Scan using the mobile app on an NFC-capable device. Use the scan button inside the app to open hidden notes; automatic launch when tapping a card is not required.'),
      ];

List<FaqEntry> generalFaq(AppLanguage language) => language == AppLanguage.ru
    ? const [
        FaqEntry('guest', 'Можно ли пользоваться без регистрации?',
            'В приложениях iOS и Android выберите «Продолжить без регистрации» на экране входа. Заметки и вложения сохраняются только на этом устройстве и работают без интернета. При удалении приложения данные могут быть удалены. Вход в аккаунт не отправляет эти заметки в облако. В браузере требуется вход в аккаунт.'),
        FaqEntry('save', 'Как создать и сохранить заметку?',
            'Нажмите «+» в списке заметок, заполните заголовок и содержимое, добавьте нужные вложения и нажмите «Сохранить». До сохранения изменения могут быть потеряны при закрытии приложения.'),
        FaqEntry('storage', 'Сколько места доступно для заметок?',
            'Для аккаунта доступно 2 ГБ в облаке. Гостевые заметки занимают память устройства и не входят в облачную квоту. Использование показано в профиле в разделе «Хранилище заметок». Медиафайлы тоже занимают место. При достижении лимита удалите ненужные заметки и обновите информацию в профиле.'),
        FaqEntry('account', 'Можно ли добавить телефон или email к аккаунту?',
            'Да. Если в профиле не указан email или телефон, нажмите «Добавить email» или «Добавить телефон» и следуйте шагам подтверждения. Используйте контакт, который ещё не связан с другим аккаунтом. Это добавляет способ входа к текущему аккаунту, а не объединяет два существующих аккаунта.'),
      ]
    : const [
        FaqEntry('guest', 'Can I use the app without registering?',
            'On iOS and Android, choose Continue without an account on the sign-in screen. Notes and attachments stay on this device and work offline. Uninstalling the app may remove them. Signing in does not upload these notes to the cloud. The web version requires an account.'),
        FaqEntry('save', 'How do I create and save a note?',
            'Tap + on the notes list, enter a title and content, add any attachments and tap Save. Unsaved edits may be lost if you close the app.'),
        FaqEntry('storage', 'How much storage do I have?',
            'Each account has 2 GB of cloud storage. Guest notes use device storage and do not count towards the cloud quota. Your profile shows usage under Note storage. Media files also take up space. If you reach the limit, delete unwanted notes and refresh the storage information in your profile.'),
        FaqEntry('account', 'Can I add a phone number or email to my account?',
            'Yes. If your profile has no email or phone number, tap Add email or Add phone and follow the verification steps. Use a contact that is not linked to another account. This adds a sign-in method to the current account; it does not merge two existing accounts.'),
      ];
