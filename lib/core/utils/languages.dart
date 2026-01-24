/// Language constants for the Happy app
/// This file contains all supported languages, their metadata, and configuration
///
/// When adding a new language:
/// 1. Add the language code to the SupportedLanguage type
/// 2. Add the language metadata to supportedLanguages
/// 3. Add translations if available

/// Supported language codes
typedef SupportedLanguage = String;

/// Language metadata interface
class LanguageInfo {
  final String code;
  final String nativeName;
  final String englishName;

  const LanguageInfo({
    required this.code,
    required this.nativeName,
    required this.englishName,
  });
}

/// All supported languages with their native and English names
const Map<String, LanguageInfo> supportedLanguages = {
  'en': LanguageInfo(
    code: 'en',
    nativeName: 'English',
    englishName: 'English',
  ),
  'ru': LanguageInfo(
    code: 'ru',
    nativeName: 'Русский',
    englishName: 'Russian',
  ),
  'pl': LanguageInfo(
    code: 'pl',
    nativeName: 'Polski',
    englishName: 'Polish',
  ),
  'es': LanguageInfo(
    code: 'es',
    nativeName: 'Español',
    englishName: 'Spanish',
  ),
  'it': LanguageInfo(
    code: 'it',
    nativeName: 'Italiano',
    englishName: 'Italian',
  ),
  'pt': LanguageInfo(
    code: 'pt',
    nativeName: 'Português',
    englishName: 'Portuguese',
  ),
  'ca': LanguageInfo(
    code: 'ca',
    nativeName: 'Català',
    englishName: 'Catalan',
  ),
  'zh-Hans': LanguageInfo(
    code: 'zh-Hans',
    nativeName: '中文(简体)',
    englishName: 'Chinese (Simplified)',
  ),
  'ja': LanguageInfo(
    code: 'ja',
    nativeName: '日本語',
    englishName: 'Japanese',
  ),
  'de': LanguageInfo(
    code: 'de',
    nativeName: 'Deutsch',
    englishName: 'German',
  ),
  'fr': LanguageInfo(
    code: 'fr',
    nativeName: 'Français',
    englishName: 'French',
  ),
  'nl': LanguageInfo(
    code: 'nl',
    nativeName: 'Nederlands',
    englishName: 'Dutch',
  ),
  'ko': LanguageInfo(
    code: 'ko',
    nativeName: '한국어',
    englishName: 'Korean',
  ),
  'tr': LanguageInfo(
    code: 'tr',
    nativeName: 'Türkçe',
    englishName: 'Turkish',
  ),
  'vi': LanguageInfo(
    code: 'vi',
    nativeName: 'Tiếng Việt',
    englishName: 'Vietnamese',
  ),
  'uk': LanguageInfo(
    code: 'uk',
    nativeName: 'Українська',
    englishName: 'Ukrainian',
  ),
};

/// Array of all supported language codes
List<String> get supportedLanguageCodes => supportedLanguages.keys.toList();

/// Default language code
const String defaultLanguage = 'en';

/// Get language native name by code
String getLanguageNativeName(String code) {
  return supportedLanguages[code]?.nativeName ?? 'English';
}

/// Get language English name by code
String getLanguageEnglishName(String code) {
  return supportedLanguages[code]?.englishName ?? 'English';
}

/// Get language info by code
LanguageInfo? getLanguageInfo(String code) {
  return supportedLanguages[code];
}
