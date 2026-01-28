/// Language constants for the Happy app
/// This file contains all supported languages, their metadata, and configuration
///
/// When adding a new language:
/// 1. Add the language metadata to allLanguages map
/// 2. Add regional variants to the regionalVariants map if applicable
/// 3. Add translations if available

/// Language metadata interface
class LanguageInfo {
  final String code;
  final String nativeName;
  final String englishName;
  final String? region;
  final bool isElevenLabsSupported;

  const LanguageInfo({
    required this.code,
    required this.nativeName,
    required this.englishName,
    this.region,
    this.isElevenLabsSupported = true,
  });

  /// Display name with region if available
  String getDisplayName {
    if (region != null && region!.isNotEmpty) {
      return '$englishName - $nativeName ($region)';
    }
    if (englishName != nativeName) {
      return '$englishName ($nativeName)';
    }
    return nativeName;
  }
}

/// Regional variant of a language
class RegionalVariant {
  final String code;
  final String region;
  final String nativeName;

  const RegionalVariant({
    required this.code,
    required this.region,
    required this.nativeName,
  });
}

/// All supported languages with their native and English names (45+ languages)
const Map<String, LanguageInfo> allLanguages = {
  // English variants
  'en-US': LanguageInfo(
    code: 'en-US',
    nativeName: 'English',
    englishName: 'English',
    region: 'United States',
  ),
  'en-GB': LanguageInfo(
    code: 'en-GB',
    nativeName: 'English',
    englishName: 'English',
    region: 'United Kingdom',
  ),
  'en-AU': LanguageInfo(
    code: 'en-AU',
    nativeName: 'English',
    englishName: 'English',
    region: 'Australia',
  ),
  'en-CA': LanguageInfo(
    code: 'en-CA',
    nativeName: 'English',
    englishName: 'English',
    region: 'Canada',
  ),
  // Spanish variants
  'es-ES': LanguageInfo(
    code: 'es-ES',
    nativeName: 'Español',
    englishName: 'Spanish',
    region: 'Spain',
  ),
  'es-MX': LanguageInfo(
    code: 'es-MX',
    nativeName: 'Español',
    englishName: 'Spanish',
    region: 'Mexico',
  ),
  'es-AR': LanguageInfo(
    code: 'es-AR',
    nativeName: 'Español',
    englishName: 'Spanish',
    region: 'Argentina',
  ),
  // French variants
  'fr-FR': LanguageInfo(
    code: 'fr-FR',
    nativeName: 'Français',
    englishName: 'French',
    region: 'France',
  ),
  'fr-CA': LanguageInfo(
    code: 'fr-CA',
    nativeName: 'Français',
    englishName: 'French',
    region: 'Canada',
  ),
  // German variants
  'de-DE': LanguageInfo(
    code: 'de-DE',
    nativeName: 'Deutsch',
    englishName: 'German',
    region: 'Germany',
  ),
  'de-AT': LanguageInfo(
    code: 'de-AT',
    nativeName: 'Deutsch',
    englishName: 'German',
    region: 'Austria',
  ),
  // Italian
  'it-IT': LanguageInfo(
    code: 'it-IT',
    nativeName: 'Italiano',
    englishName: 'Italian',
    region: 'Italy',
  ),
  // Portuguese variants
  'pt-BR': LanguageInfo(
    code: 'pt-BR',
    nativeName: 'Português',
    englishName: 'Portuguese',
    region: 'Brazil',
  ),
  'pt-PT': LanguageInfo(
    code: 'pt-PT',
    nativeName: 'Português',
    englishName: 'Portuguese',
    region: 'Portugal',
  ),
  // Russian
  'ru-RU': LanguageInfo(
    code: 'ru-RU',
    nativeName: 'Русский',
    englishName: 'Russian',
    region: 'Russia',
  ),
  // Chinese variants
  'zh-CN': LanguageInfo(
    code: 'zh-CN',
    nativeName: '中文',
    englishName: 'Chinese',
    region: 'Simplified',
  ),
  'zh-TW': LanguageInfo(
    code: 'zh-TW',
    nativeName: '中文',
    englishName: 'Chinese',
    region: 'Traditional',
  ),
  // Japanese
  'ja-JP': LanguageInfo(
    code: 'ja-JP',
    nativeName: '日本語',
    englishName: 'Japanese',
    region: 'Japan',
  ),
  // Korean
  'ko-KR': LanguageInfo(
    code: 'ko-KR',
    nativeName: '한국어',
    englishName: 'Korean',
    region: 'Korea',
  ),
  // Arabic
  'ar-SA': LanguageInfo(
    code: 'ar-SA',
    nativeName: 'العربية',
    englishName: 'Arabic',
    region: 'Saudi Arabia',
  ),
  // Hindi
  'hi-IN': LanguageInfo(
    code: 'hi-IN',
    nativeName: 'हिन्दी',
    englishName: 'Hindi',
    region: 'India',
  ),
  // Dutch
  'nl-NL': LanguageInfo(
    code: 'nl-NL',
    nativeName: 'Nederlands',
    englishName: 'Dutch',
    region: 'Netherlands',
  ),
  // Swedish
  'sv-SE': LanguageInfo(
    code: 'sv-SE',
    nativeName: 'Svenska',
    englishName: 'Swedish',
    region: 'Sweden',
  ),
  // Norwegian
  'no-NO': LanguageInfo(
    code: 'no-NO',
    nativeName: 'Norsk',
    englishName: 'Norwegian',
    region: 'Norway',
  ),
  // Danish
  'da-DK': LanguageInfo(
    code: 'da-DK',
    nativeName: 'Dansk',
    englishName: 'Danish',
    region: 'Denmark',
  ),
  // Finnish
  'fi-FI': LanguageInfo(
    code: 'fi-FI',
    nativeName: 'Suomi',
    englishName: 'Finnish',
    region: 'Finland',
  ),
  // Polish
  'pl-PL': LanguageInfo(
    code: 'pl-PL',
    nativeName: 'Polski',
    englishName: 'Polish',
    region: 'Poland',
  ),
  // Turkish
  'tr-TR': LanguageInfo(
    code: 'tr-TR',
    nativeName: 'Türkçe',
    englishName: 'Turkish',
    region: 'Turkey',
  ),
  // Hebrew
  'he-IL': LanguageInfo(
    code: 'he-IL',
    nativeName: 'עברית',
    englishName: 'Hebrew',
    region: 'Israel',
    isElevenLabsSupported: false,
  ),
  // Thai
  'th-TH': LanguageInfo(
    code: 'th-TH',
    nativeName: 'ไทย',
    englishName: 'Thai',
    region: 'Thailand',
    isElevenLabsSupported: false,
  ),
  // Vietnamese
  'vi-VN': LanguageInfo(
    code: 'vi-VN',
    nativeName: 'Tiếng Việt',
    englishName: 'Vietnamese',
    region: 'Vietnam',
  ),
  // Indonesian
  'id-ID': LanguageInfo(
    code: 'id-ID',
    nativeName: 'Bahasa Indonesia',
    englishName: 'Indonesian',
    region: 'Indonesia',
  ),
  // Malay
  'ms-MY': LanguageInfo(
    code: 'ms-MY',
    nativeName: 'Bahasa Melayu',
    englishName: 'Malay',
    region: 'Malaysia',
  ),
  // Ukrainian
  'uk-UA': LanguageInfo(
    code: 'uk-UA',
    nativeName: 'Українська',
    englishName: 'Ukrainian',
    region: 'Ukraine',
  ),
  // Czech
  'cs-CZ': LanguageInfo(
    code: 'cs-CZ',
    nativeName: 'Čeština',
    englishName: 'Czech',
    region: 'Czech Republic',
  ),
  // Hungarian
  'hu-HU': LanguageInfo(
    code: 'hu-HU',
    nativeName: 'Magyar',
    englishName: 'Hungarian',
    region: 'Hungary',
  ),
  // Romanian
  'ro-RO': LanguageInfo(
    code: 'ro-RO',
    nativeName: 'Română',
    englishName: 'Romanian',
    region: 'Romania',
  ),
  // Bulgarian
  'bg-BG': LanguageInfo(
    code: 'bg-BG',
    nativeName: 'Български',
    englishName: 'Bulgarian',
    region: 'Bulgaria',
  ),
  // Greek
  'el-GR': LanguageInfo(
    code: 'el-GR',
    nativeName: 'Ελληνικά',
    englishName: 'Greek',
    region: 'Greece',
  ),
  // Croatian
  'hr-HR': LanguageInfo(
    code: 'hr-HR',
    nativeName: 'Hrvatski',
    englishName: 'Croatian',
    region: 'Croatia',
  ),
  // Slovak
  'sk-SK': LanguageInfo(
    code: 'sk-SK',
    nativeName: 'Slovenčina',
    englishName: 'Slovak',
    region: 'Slovakia',
  ),
  // Slovenian
  'sl-SI': LanguageInfo(
    code: 'sl-SI',
    nativeName: 'Slovenščina',
    englishName: 'Slovenian',
    region: 'Slovenia',
    isElevenLabsSupported: false,
  ),
  // Estonian
  'et-EE': LanguageInfo(
    code: 'et-EE',
    nativeName: 'Eesti',
    englishName: 'Estonian',
    region: 'Estonia',
    isElevenLabsSupported: false,
  ),
  // Latvian
  'lv-LV': LanguageInfo(
    code: 'lv-LV',
    nativeName: 'Latviešu',
    englishName: 'Latvian',
    region: 'Latvia',
    isElevenLabsSupported: false,
  ),
  // Lithuanian
  'lt-LT': LanguageInfo(
    code: 'lt-LT',
    nativeName: 'Lietuvių',
    englishName: 'Lithuanian',
    region: 'Lithuania',
    isElevenLabsSupported: false,
  ),
};

/// Auto-detect option
const String autoLanguageCode = 'auto';

/// Array of all supported language codes
List<String> get supportedLanguageCodes => allLanguages.keys.toList();

/// Default language code
const String defaultLanguage = 'en-US';

/// Get language native name by code
String getLanguageNativeName(String code) {
  return allLanguages[code]?.nativeName ?? 'English';
}

/// Get language English name by code
String getLanguageEnglishName(String code) {
  return allLanguages[code]?.englishName ?? 'English';
}

/// Get language info by code
LanguageInfo? getLanguageInfo(String code) {
  return allLanguages[code];
}

/// Get display name for a language (includes region info)
String getLanguageDisplayName(String code) {
  final info = allLanguages[code];
  if (info == null) return 'English';
  return info.displayName;
}

/// Get device detected language code from locale string
String getDeviceLanguageCode(String localeString) {
  final parts = localeString.split('-');
  final languageCode = parts[0].toLowerCase();
  final countryCode = parts.length > 1 ? parts[1].toUpperCase() : '';

  // Try exact match first
  final exactCode = countryCode.isNotEmpty ? '$languageCode-$countryCode' : languageCode;
  if (allLanguages.containsKey(exactCode)) {
    return exactCode;
  }

  // Try base language code match
  for (final code in allLanguages.keys) {
    if (code.startsWith('$languageCode-')) {
      return code;
    }
  }

  // Default to English US
  return 'en-US';
}

/// Filter languages by search query
List<String> filterLanguages(String query) {
  if (query.trim().isEmpty) {
    return supportedLanguageCodes;
  }

  final lowerQuery = query.toLowerCase().trim();
  return supportedLanguageCodes.where((code) {
    final info = allLanguages[code];
    if (info == null) return false;

    return info.englishName.toLowerCase().contains(lowerQuery) ||
        info.nativeName.toLowerCase().contains(lowerQuery) ||
        (info.region?.toLowerCase().contains(lowerQuery) ?? false) ||
        code.toLowerCase().contains(lowerQuery);
  }).toList();
}
