import 'package:flutter/material.dart';

/// Supported locales for the Happy app.
///
/// This list defines all languages that the app supports.
/// The order determines the fallback order when a translation is missing.
const List<Locale> supportedLocales = [
  Locale('en'), // English
  Locale('es'), // Spanish
  Locale('zh', 'Hans'), // Chinese (Simplified)
  Locale('ja'), // Japanese
  Locale('ru'), // Russian
  Locale('pl'), // Polish
  Locale('pt'), // Portuguese
  Locale('ca'), // Catalan
  Locale('it'), // Italian
];

/// Locale names for display purposes.
const Map<String, String> localeNames = {
  'en': 'English',
  'es': 'Español',
  'zh': '中文 (简体)',
  'ja': '日本語',
  'ru': 'Русский',
  'pl': 'Polski',
  'pt': 'Português',
  'ca': 'Català',
  'it': 'Italiano',
};

/// Locale native names for display purposes.
const Map<String, String> localeNativeNames = {
  'en': 'English',
  'es': 'Español',
  'zh': '简体中文',
  'ja': '日本語',
  'ru': 'Русский',
  'pl': 'Polski',
  'pt': 'Português',
  'ca': 'Català',
  'it': 'Italiano',
};

/// Get the display name for a locale.
String getLocaleDisplayName(Locale locale) {
  final key = locale.languageCode;
  if (locale.scriptCode != null) {
    return localeNativeNames['${locale.languageCode}_${locale.scriptCode}'] ??
        localeNames[key] ?? locale.languageCode;
  }
  return localeNativeNames[key] ?? localeNames[key] ?? locale.languageCode;
}

/// Parse a locale string (e.g., 'en', 'zh_Hans') to a Locale object.
Locale parseLocale(String localeString) {
  final parts = localeString.split('_');
  if (parts.length == 2) {
    return Locale(parts[0], parts[1]);
  }
  return Locale(parts[0]);
}
