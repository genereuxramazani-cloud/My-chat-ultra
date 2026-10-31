import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const supportedLanguageCodes = ['fr', 'en'];

  static const supportedLocales = [
    Locale('fr'),
    Locale('en'),
  ];

  static const _languagePrefKey = 'app_language';

  Locale _locale = const Locale('fr');

  Locale get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languagePrefKey) ?? 'fr';
    if (supportedLanguageCodes.contains(languageCode)) {
      _locale = Locale(languageCode);
    } else {
      _locale = const Locale('fr');
    }
    notifyListeners();
  }

  Future<void> setLocale(String languageCode) async {
    if (!supportedLanguageCodes.contains(languageCode)) return;
    _locale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePrefKey, languageCode);
    notifyListeners();
  }

  static String languageLabel(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'fr':
      default:
        return 'Français';
    }
  }
}
