/// Voice language constants for the Happy app
/// Contains all supported languages with ElevenLabs language code mapping
///
/// Based on React Native's LANGUAGES constant from:
/// /home/workspace/git/happy/expo-app/sources/constants/Languages.ts

/// ElevenLabs supported language codes
class ElevenLabsLanguageCode {
  static const String english = 'en';
  static const String japanese = 'ja';
  static const String chinese = 'zh';
  static const String german = 'de';
  static const String hindi = 'hi';
  static const String french = 'fr';
  static const String korean = 'ko';
  static const String portuguese = 'pt';
  static const String portugueseBrazil = 'pt-br';
  static const String italian = 'it';
  static const String spanish = 'es';
  static const String indonesian = 'id';
  static const String dutch = 'nl';
  static const String turkish = 'tr';
  static const String polish = 'pl';
  static const String swedish = 'sv';
  static const String bulgarian = 'bg';
  static const String romanian = 'ro';
  static const String arabic = 'ar';
  static const String czech = 'cs';
  static const String greek = 'el';
  static const String finnish = 'fi';
  static const String malay = 'ms';
  static const String danish = 'da';
  static const String tamil = 'ta';
  static const String ukrainian = 'uk';
  static const String russian = 'ru';
  static const String hungarian = 'hu';
  static const String croatian = 'hr';
  static const String slovak = 'sk';
  static const String norwegian = 'no';
  static const String vietnamese = 'vi';
}

/// Voice language metadata interface
class VoiceLanguage {
  final String code; // null for auto-detect
  final String name;
  final String nativeName;
  final String? region;
  final String? elevenLabsCode; // ElevenLabs language code mapping

  const VoiceLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    this.region,
    this.elevenLabsCode,
  });

  /// Get display name for the language (e.g., "English (English) - United States")
  String get displayName {
    final parts = <String>[];

    if (name != nativeName) {
      parts.add('$name ($nativeName)');
    } else {
      parts.add(name);
    }

    if (region != null) {
      parts.add(region!);
    }

    return parts.join(' - ');
  }

  /// Get subtitle text showing language code or "Auto-detect"
  String get subtitle => code.isEmpty ? 'Auto-detect' : code;

  /// Check if this language is supported by ElevenLabs
  bool get isElevenLabsSupported => elevenLabsCode != null;
}

/// All supported voice languages for ElevenLabs text-to-speech
/// First entry is always auto-detect (null code)
const List<VoiceLanguage> voiceLanguages = [
  // Auto-detect option
  VoiceLanguage(
    code: '',
    name: 'Auto-detect',
    nativeName: 'Auto-detect',
  ),
  // English variants
  VoiceLanguage(
    code: 'en-US',
    name: 'English',
    nativeName: 'English',
    region: 'United States',
    elevenLabsCode: ElevenLabsLanguageCode.english,
  ),
  VoiceLanguage(
    code: 'en-GB',
    name: 'English',
    nativeName: 'English',
    region: 'United Kingdom',
    elevenLabsCode: ElevenLabsLanguageCode.english,
  ),
  VoiceLanguage(
    code: 'en-AU',
    name: 'English',
    nativeName: 'English',
    region: 'Australia',
    elevenLabsCode: ElevenLabsLanguageCode.english,
  ),
  VoiceLanguage(
    code: 'en-CA',
    name: 'English',
    nativeName: 'English',
    region: 'Canada',
    elevenLabsCode: ElevenLabsLanguageCode.english,
  ),
  // Spanish variants
  VoiceLanguage(
    code: 'es-ES',
    name: 'Spanish',
    nativeName: 'Español',
    region: 'Spain',
    elevenLabsCode: ElevenLabsLanguageCode.spanish,
  ),
  VoiceLanguage(
    code: 'es-MX',
    name: 'Spanish',
    nativeName: 'Español',
    region: 'Mexico',
    elevenLabsCode: ElevenLabsLanguageCode.spanish,
  ),
  VoiceLanguage(
    code: 'es-AR',
    name: 'Spanish',
    nativeName: 'Español',
    region: 'Argentina',
    elevenLabsCode: ElevenLabsLanguageCode.spanish,
  ),
  // French variants
  VoiceLanguage(
    code: 'fr-FR',
    name: 'French',
    nativeName: 'Français',
    region: 'France',
    elevenLabsCode: ElevenLabsLanguageCode.french,
  ),
  VoiceLanguage(
    code: 'fr-CA',
    name: 'French',
    nativeName: 'Français',
    region: 'Canada',
    elevenLabsCode: ElevenLabsLanguageCode.french,
  ),
  // German variants
  VoiceLanguage(
    code: 'de-DE',
    name: 'German',
    nativeName: 'Deutsch',
    region: 'Germany',
    elevenLabsCode: ElevenLabsLanguageCode.german,
  ),
  VoiceLanguage(
    code: 'de-AT',
    name: 'German',
    nativeName: 'Deutsch',
    region: 'Austria',
    elevenLabsCode: ElevenLabsLanguageCode.german,
  ),
  // Italian
  VoiceLanguage(
    code: 'it-IT',
    name: 'Italian',
    nativeName: 'Italiano',
    elevenLabsCode: ElevenLabsLanguageCode.italian,
  ),
  // Portuguese variants
  VoiceLanguage(
    code: 'pt-BR',
    name: 'Portuguese',
    nativeName: 'Português',
    region: 'Brazil',
    elevenLabsCode: ElevenLabsLanguageCode.portugueseBrazil,
  ),
  VoiceLanguage(
    code: 'pt-PT',
    name: 'Portuguese',
    nativeName: 'Português',
    region: 'Portugal',
    elevenLabsCode: ElevenLabsLanguageCode.portuguese,
  ),
  // Russian
  VoiceLanguage(
    code: 'ru-RU',
    name: 'Russian',
    nativeName: 'Русский',
    elevenLabsCode: ElevenLabsLanguageCode.russian,
  ),
  // Chinese variants
  VoiceLanguage(
    code: 'zh-CN',
    name: 'Chinese',
    nativeName: '中文',
    region: 'Simplified',
    elevenLabsCode: ElevenLabsLanguageCode.chinese,
  ),
  VoiceLanguage(
    code: 'zh-TW',
    name: 'Chinese',
    nativeName: '中文',
    region: 'Traditional',
    elevenLabsCode: ElevenLabsLanguageCode.chinese,
  ),
  // Japanese
  VoiceLanguage(
    code: 'ja-JP',
    name: 'Japanese',
    nativeName: '日本語',
    elevenLabsCode: ElevenLabsLanguageCode.japanese,
  ),
  // Korean
  VoiceLanguage(
    code: 'ko-KR',
    name: 'Korean',
    nativeName: '한국어',
    elevenLabsCode: ElevenLabsLanguageCode.korean,
  ),
  // Arabic
  VoiceLanguage(
    code: 'ar-SA',
    name: 'Arabic',
    nativeName: 'العربية',
    elevenLabsCode: ElevenLabsLanguageCode.arabic,
  ),
  // Hindi
  VoiceLanguage(
    code: 'hi-IN',
    name: 'Hindi',
    nativeName: 'हिन्दी',
    elevenLabsCode: ElevenLabsLanguageCode.hindi,
  ),
  // Dutch
  VoiceLanguage(
    code: 'nl-NL',
    name: 'Dutch',
    nativeName: 'Nederlands',
    elevenLabsCode: ElevenLabsLanguageCode.dutch,
  ),
  // Swedish
  VoiceLanguage(
    code: 'sv-SE',
    name: 'Swedish',
    nativeName: 'Svenska',
    elevenLabsCode: ElevenLabsLanguageCode.swedish,
  ),
  // Norwegian
  VoiceLanguage(
    code: 'no-NO',
    name: 'Norwegian',
    nativeName: 'Norsk',
    elevenLabsCode: ElevenLabsLanguageCode.norwegian,
  ),
  // Danish
  VoiceLanguage(
    code: 'da-DK',
    name: 'Danish',
    nativeName: 'Dansk',
    elevenLabsCode: ElevenLabsLanguageCode.danish,
  ),
  // Finnish
  VoiceLanguage(
    code: 'fi-FI',
    name: 'Finnish',
    nativeName: 'Suomi',
    elevenLabsCode: ElevenLabsLanguageCode.finnish,
  ),
  // Polish
  VoiceLanguage(
    code: 'pl-PL',
    name: 'Polish',
    nativeName: 'Polski',
    elevenLabsCode: ElevenLabsLanguageCode.polish,
  ),
  // Turkish
  VoiceLanguage(
    code: 'tr-TR',
    name: 'Turkish',
    nativeName: 'Türkçe',
    elevenLabsCode: ElevenLabsLanguageCode.turkish,
  ),
  // Hebrew (not supported by ElevenLabs)
  VoiceLanguage(
    code: 'he-IL',
    name: 'Hebrew',
    nativeName: 'עברית',
  ),
  // Thai (not supported by ElevenLabs)
  VoiceLanguage(
    code: 'th-TH',
    name: 'Thai',
    nativeName: 'ไทย',
  ),
  // Vietnamese
  VoiceLanguage(
    code: 'vi-VN',
    name: 'Vietnamese',
    nativeName: 'Tiếng Việt',
    elevenLabsCode: ElevenLabsLanguageCode.vietnamese,
  ),
  // Indonesian
  VoiceLanguage(
    code: 'id-ID',
    name: 'Indonesian',
    nativeName: 'Bahasa Indonesia',
    elevenLabsCode: ElevenLabsLanguageCode.indonesian,
  ),
  // Malay
  VoiceLanguage(
    code: 'ms-MY',
    name: 'Malay',
    nativeName: 'Bahasa Melayu',
    elevenLabsCode: ElevenLabsLanguageCode.malay,
  ),
  // Ukrainian
  VoiceLanguage(
    code: 'uk-UA',
    name: 'Ukrainian',
    nativeName: 'Українська',
    elevenLabsCode: ElevenLabsLanguageCode.ukrainian,
  ),
  // Czech
  VoiceLanguage(
    code: 'cs-CZ',
    name: 'Czech',
    nativeName: 'Čeština',
    elevenLabsCode: ElevenLabsLanguageCode.czech,
  ),
  // Hungarian
  VoiceLanguage(
    code: 'hu-HU',
    name: 'Hungarian',
    nativeName: 'Magyar',
    elevenLabsCode: ElevenLabsLanguageCode.hungarian,
  ),
  // Romanian
  VoiceLanguage(
    code: 'ro-RO',
    name: 'Romanian',
    nativeName: 'Română',
    elevenLabsCode: ElevenLabsLanguageCode.romanian,
  ),
  // Bulgarian
  VoiceLanguage(
    code: 'bg-BG',
    name: 'Bulgarian',
    nativeName: 'Български',
    elevenLabsCode: ElevenLabsLanguageCode.bulgarian,
  ),
  // Greek
  VoiceLanguage(
    code: 'el-GR',
    name: 'Greek',
    nativeName: 'Ελληνικά',
    elevenLabsCode: ElevenLabsLanguageCode.greek,
  ),
  // Croatian
  VoiceLanguage(
    code: 'hr-HR',
    name: 'Croatian',
    nativeName: 'Hrvatski',
    elevenLabsCode: ElevenLabsLanguageCode.croatian,
  ),
  // Slovak
  VoiceLanguage(
    code: 'sk-SK',
    name: 'Slovak',
    nativeName: 'Slovenčina',
    elevenLabsCode: ElevenLabsLanguageCode.slovak,
  ),
  // Slovenian (not supported by ElevenLabs)
  VoiceLanguage(
    code: 'sl-SI',
    name: 'Slovenian',
    nativeName: 'Slovenščina',
  ),
  // Estonian (not supported by ElevenLabs)
  VoiceLanguage(
    code: 'et-EE',
    name: 'Estonian',
    nativeName: 'Eesti',
  ),
  // Latvian (not supported by ElevenLabs)
  VoiceLanguage(
    code: 'lv-LV',
    name: 'Latvian',
    nativeName: 'Latviešu',
  ),
  // Lithuanian (not supported by ElevenLabs)
  VoiceLanguage(
    code: 'lt-LT',
    name: 'Lithuanian',
    nativeName: 'Lietuvių',
  ),
];

/// Filter languages based on search query
List<VoiceLanguage> searchVoiceLanguages(String query) {
  if (query.isEmpty) {
    return voiceLanguages;
  }

  final lowerQuery = query.toLowerCase();
  return voiceLanguages.where((lang) {
    return lang.name.toLowerCase().contains(lowerQuery) ||
        lang.nativeName.toLowerCase().contains(lowerQuery) ||
        lang.code.toLowerCase().contains(lowerQuery) ||
        (lang.region?.toLowerCase().contains(lowerQuery) ?? false);
  }).toList();
}

/// Find a language by its code (including empty string for auto-detect)
VoiceLanguage? findVoiceLanguageByCode(String code) {
  return voiceLanguages.firstWhere(
    (lang) => lang.code == code,
    orElse: () => voiceLanguages[0], // Default to auto-detect
  );
}

/// Get the ElevenLabs language code for a given language code
String? getElevenLabsCode(String languageCode) {
  final language = findVoiceLanguageByCode(languageCode);
  return language?.elevenLabsCode;
}

/// Get all languages that are supported by ElevenLabs
List<VoiceLanguage> getElevenLabsSupportedLanguages() {
  return voiceLanguages.where((lang) => lang.elevenLabsCode != null).toList();
}

/// Get the count of supported languages
int get supportedLanguageCount => voiceLanguages.length;
