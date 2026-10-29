import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';

class LocaleProvider extends ChangeNotifier {
  static const _languageKey = 'app_language';

  AppLanguage _language = AppLanguage.ru;

  LocaleProvider() {
    _loadLanguage();
  }

  AppLanguage get language => _language;
  Locale get locale => Locale(_language.code);

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language.code);
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = AppLanguage.fromCode(prefs.getString(_languageKey));
    if (_language == saved) return;
    _language = saved;
    notifyListeners();
  }
}

extension LocaleContext on BuildContext {
  AppStrings get strings => AppStrings(watch<LocaleProvider>().language);
  AppStrings get readStrings => AppStrings(read<LocaleProvider>().language);
}
