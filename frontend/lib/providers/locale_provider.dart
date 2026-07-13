import 'package:flutter/material.dart';

class LocaleProvider with ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }

  /// Convertit le tag BCP-47-ish stocké côté compte ("en-US", "fr-FR") en
  /// Locale Flutter. Défaut anglais si absent/inconnu.
  static Locale localeFromLanguageTag(String? tag) {
    if (tag != null && tag.toLowerCase().startsWith('fr')) {
      return const Locale('fr');
    }
    return const Locale('en');
  }

  void toggleLocale() {
    if (_locale.languageCode == 'en') {
      setLocale(const Locale('fr'));
    } else {
      setLocale(const Locale('en'));
    }
  }
}
