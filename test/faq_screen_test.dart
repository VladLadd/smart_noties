import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_noties/data/faq_content.dart';
import 'package:smart_noties/l10n/app_strings.dart';
import 'package:smart_noties/providers/locale_provider.dart';
import 'package:smart_noties/screens/faq_screen.dart';

void main() {
  test('Both languages include the same NFC and general questions', () {
    expect(nfcFaq(AppLanguage.ru).map((entry) => entry.id),
        nfcFaq(AppLanguage.en).map((entry) => entry.id));
    expect(generalFaq(AppLanguage.ru).map((entry) => entry.id),
        generalFaq(AppLanguage.en).map((entry) => entry.id));
    for (final language in AppLanguage.values) {
      final writing =
          nfcFaq(language).firstWhere((entry) => entry.id == 'write');
      expect(writing.answer, contains('smartnoties://'));
      expect(writing.answer, contains('Text'));
      expect(writing.answer, contains('wakdev'));
    }
    expect(Uri.parse(nfcToolsAppStoreUrl).host, 'apps.apple.com');
    expect(Uri.parse(nfcToolsAppStoreUrl).path, contains('id1252962749'));
    expect(Uri.parse(nfcToolsGooglePlayUrl).queryParameters['id'],
        'com.wakdev.wdnfc');
  });

  testWidgets('FAQ expands answers and follows the profile language',
      (tester) async {
    SharedPreferences.setMockInitialValues({'app_language': 'ru'});
    final locale = LocaleProvider();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: locale,
      child: const MaterialApp(home: FaqScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Вопросы и ответы'), findsOneWidget);
    expect(find.text('App Store'), findsOneWidget);
    expect(find.text('Google Play'), findsOneWidget);
    final question = find.text('Как записать токен через NFC Tools?');
    await tester.scrollUntilVisible(question, 180);
    await tester.tap(question);
    await tester.pumpAndSettle();
    expect(find.textContaining('Не добавляйте к ней https://'), findsOneWidget);
    await locale.setLanguage(AppLanguage.en);
    await tester.pumpAndSettle();
    expect(find.text('FAQ'), findsOneWidget);
    expect(find.text('Как записать токен через NFC Tools?'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    locale.dispose();
  });
}
