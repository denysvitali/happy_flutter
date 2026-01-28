import 'package:flutter/material.dart';

/// Supported locales for the Happy app.
///
/// This list defines all languages that the app supports.
/// The order determines the fallback order when a translation is missing.
///
/// RTL (Right-to-Left) languages are properly supported.
const List<Locale> supportedLocales = [
  // English variants
  Locale('en'), // English (default)
  Locale('en', 'GB'), // English (UK)
  Locale('en', 'AU'), // English (Australia)
  Locale('en', 'CA'), // English (Canada)

  // Spanish variants
  Locale('es'), // Spanish (default - Spain)
  Locale('es', 'MX'), // Spanish (Mexico)
  Locale('es', 'AR'), // Spanish (Argentina)

  // French variants
  Locale('fr'), // French (default - France)
  Locale('fr', 'CA'), // French (Canada)

  // German variants
  Locale('de'), // German
  Locale('de', 'AT'), // German (Austria)

  // Italian
  Locale('it'), // Italian

  // Portuguese variants
  Locale('pt'), // Portuguese (default - Brazil)
  Locale('pt', 'PT'), // Portuguese (Portugal)

  // Russian
  Locale('ru'), // Russian

  // Chinese variants
  Locale('zh', 'Hans'), // Chinese (Simplified)
  Locale('zh', 'Hant'), // Chinese (Traditional)

  // Japanese
  Locale('ja'), // Japanese

  // Korean
  Locale('ko'), // Korean

  // Arabic (RTL)
  Locale('ar'), // Arabic

  // Hindi
  Locale('hi'), // Hindi

  // Dutch
  Locale('nl'), // Dutch

  // Polish
  Locale('pl'), // Polish

  // Turkish
  Locale('tr'), // Turkish

  // Vietnamese
  Locale('vi'), // Vietnamese

  // Indonesian
  Locale('id'), // Indonesian

  // Ukrainian
  Locale('uk'), // Ukrainian

  // Czech
  Locale('cs'), // Czech

  // Romanian
  Locale('ro'), // Romanian

  // Hungarian
  Locale('hu'), // Hungarian

  // Greek
  Locale('el'), // Greek

  // Hebrew (RTL)
  Locale('he'), // Hebrew

  // Thai
  Locale('th'), // Thai

  // Swedish
  Locale('sv'), // Swedish

  // Danish
  Locale('da'), // Danish

  // Finnish
  Locale('fi'), // Finnish

  // Norwegian
  Locale('no'), // Norwegian

  // Bulgarian
  Locale('bg'), // Bulgarian

  // Croatian
  Locale('hr'), // Croatian

  // Slovak
  Locale('sk'), // Slovak

  // Slovenian
  Locale('sl'), // Slovenian

  // Catalan
  Locale('ca'), // Catalan
];

/// Locale names for display purposes (in their native language).
const Map<String, String> localeNativeNames = {
  // English
  'en': 'English',
  'en_GB': 'English (UK)',
  'en_AU': 'English (Australia)',
  'en_CA': 'English (Canada)',

  // Spanish
  'es': 'Español',
  'es_MX': 'Español (México)',
  'es_AR': 'Español (Argentina)',

  // French
  'fr': 'Français',
  'fr_CA': 'Français (Canada)',

  // German
  'de': 'Deutsch',
  'de_AT': 'Deutsch (Österreich)',

  // Italian
  'it': 'Italiano',

  // Portuguese
  'pt': 'Português (Brasil)',
  'pt_PT': 'Português (Portugal)',

  // Russian
  'ru': 'Русский',

  // Chinese
  'zh_Hans': '简体中文',
  'zh_Hant': '繁體中文',

  // Japanese
  'ja': '日本語',

  // Korean
  'ko': '한국어',

  // Arabic (RTL)
  'ar': 'العربية',

  // Hindi
  'hi': 'हिन्दी',

  // Dutch
  'nl': 'Nederlands',

  // Polish
  'pl': 'Polski',

  // Turkish
  'tr': 'Türkçe',

  // Vietnamese
  'vi': 'Tiếng Việt',

  // Indonesian
  'id': 'Bahasa Indonesia',

  // Ukrainian
  'uk': 'Українська',

  // Czech
  'cs': 'Čeština',

  // Romanian
  'ro': 'Română',

  // Hungarian
  'hu': 'Magyar',

  // Greek
  'el': 'Ελληνικά',

  // Hebrew (RTL)
  'he': 'עברית',

  // Thai
  'th': 'ไทย',

  // Swedish
  'sv': 'Svenska',

  // Danish
  'da': 'Dansk',

  // Finnish
  'fi': 'Suomi',

  // Norwegian
  'no': 'Norsk',

  // Bulgarian
  'bg': 'Български',

  // Croatian
  'hr': 'Hrvatski',

  // Slovak
  'sk': 'Slovenčina',

  // Slovenian
  'sl': 'Slovenščina',

  // Catalan
  'ca': 'Català',
};

/// Locale names for display purposes (in English).
const Map<String, String> localeEnglishNames = {
  'en': 'English',
  'en_GB': 'English (UK)',
  'en_AU': 'English (Australia)',
  'en_CA': 'English (Canada)',
  'es': 'Spanish',
  'es_MX': 'Spanish (Mexico)',
  'es_AR': 'Spanish (Argentina)',
  'fr': 'French',
  'fr_CA': 'French (Canada)',
  'de': 'German',
  'de_AT': 'German (Austria)',
  'it': 'Italian',
  'pt': 'Portuguese (Brazil)',
  'pt_PT': 'Portuguese (Portugal)',
  'ru': 'Russian',
  'zh_Hans': 'Chinese (Simplified)',
  'zh_Hant': 'Chinese (Traditional)',
  'ja': 'Japanese',
  'ko': 'Korean',
  'ar': 'Arabic',
  'hi': 'Hindi',
  'nl': 'Dutch',
  'pl': 'Polish',
  'tr': 'Turkish',
  'vi': 'Vietnamese',
  'id': 'Indonesian',
  'uk': 'Ukrainian',
  'cs': 'Czech',
  'ro': 'Romanian',
  'hu': 'Hungarian',
  'el': 'Greek',
  'he': 'Hebrew',
  'th': 'Thai',
  'sv': 'Swedish',
  'da': 'Danish',
  'fi': 'Finnish',
  'no': 'Norwegian',
  'bg': 'Bulgarian',
  'hr': 'Croatian',
  'sk': 'Slovak',
  'sl': 'Slovenian',
  'ca': 'Catalan',
};

/// RTL (Right-to-Left) language codes.
const Set<String> rtlLanguageCodes = {
  'ar', // Arabic
  'he', // Hebrew
  'fa', // Persian/Farsi
  'ur', // Urdu
};

/// Check if a locale is RTL (Right-to-Left).
bool isLocaleRtl(Locale locale) {
  return rtlLanguageCodes.contains(locale.languageCode);
}

/// Get the locale key for lookup in maps.
String _getLocaleKey(Locale locale) {
  if (locale.scriptCode != null) {
    return '${locale.languageCode}_${locale.scriptCode}';
  }
  if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
    return '${locale.languageCode}_${locale.countryCode}';
  }
  return locale.languageCode;
}

/// Get the display name for a locale (in the locale's native language).
String getLocaleNativeDisplayName(Locale locale) {
  final key = _getLocaleKey(locale);
  return localeNativeNames[key] ?? localeNativeNames[locale.languageCode] ?? locale.languageCode;
}

/// Get the display name for a locale (in English).
String getLocaleEnglishDisplayName(Locale locale) {
  final key = _getLocaleKey(locale);
  return localeEnglishNames[key] ?? localeEnglishNames[locale.languageCode] ?? locale.languageCode;
}

/// Parse a locale string (e.g., 'en', 'zh_Hans', 'pt_BR') to a Locale object.
Locale parseLocaleString(String localeString) {
  final parts = localeString.split('_');
  if (parts.length == 2) {
    final countryOrScript = parts[1];
    // Check if it's a script code (3-4 chars, capitalized) or country code (2 chars)
    if (countryOrScript.length >= 3) {
      return Locale.fromSubtags(
        languageCode: parts[0],
        scriptCode: countryOrScript,
      );
    }
    return Locale(parts[0], parts[1]);
  }
  if (parts.length == 3) {
    // format: language_script_country (e.g., zh_Hans_CN)
    return Locale.fromSubtags(
      languageCode: parts[0],
      scriptCode: parts[1],
      countryCode: parts[2],
    );
  }
  return Locale(parts[0]);
}

/// Get the fallback locale for a given locale.
/// Used when a specific regional variant is not available.
Locale getFallbackLocale(Locale locale) {
  // Map regional variants to base language
  final fallbackMap = <String, Locale>{
    // English variants
    'en_GB': Locale('en'),
    'en_AU': Locale('en'),
    'en_CA': Locale('en'),
    // Spanish variants
    'es_MX': Locale('es'),
    'es_AR': Locale('es'),
    // French variants
    'fr_CA': Locale('fr'),
    // German variants
    'de_AT': Locale('de'),
    // Portuguese variants
    'pt_PT': Locale('pt'),
    // Chinese variants
    'zh_Hant': Locale('zh', 'Hans'),
  };

  final key = _getLocaleKey(locale);
  return fallbackMap[key] ?? Locale(locale.languageCode);
}
