import 'package:flutter/painting.dart';

/// Brand-colour map for the language dot indicator in the code-block
/// header. One shade per language, lifted from GitHub Linguist's
/// canonical palette so the dots match the colour used on GitHub.com.
///
/// The map is keyed by lowercased language identifier. Several
/// languages have multiple aliases (e.g. `py` for `python`); all
/// aliases resolve to the same colour.
///
/// Lookup is O(1) via [colorForLanguage].
const Map<String, Color> kLanguageBrandColors = <String, Color>{
  'dart': Color(0xFF00B4AB),
  'flutter': Color(0xFF54C5F8),
  'python': Color(0xFF3572A5),
  'py': Color(0xFF3572A5),
  'javascript': Color(0xFFF1E05A),
  'js': Color(0xFFF1E05A),
  'jsx': Color(0xFFF1E05A),
  'typescript': Color(0xFF3178C6),
  'ts': Color(0xFF3178C6),
  'tsx': Color(0xFF3178C6),
  'rust': Color(0xFFDEA584),
  'rs': Color(0xFFDEA584),
  'go': Color(0xFF00ADD8),
  'golang': Color(0xFF00ADD8),
  'swift': Color(0xFFF05138),
  'kotlin': Color(0xFFA97BFF),
  'kt': Color(0xFFA97BFF),
  'java': Color(0xFFB07219),
  'ruby': Color(0xFF701516),
  'rb': Color(0xFF701516),
  'bash': Color(0xFF89E051),
  'sh': Color(0xFF89E051),
  'shell': Color(0xFF89E051),
  'css': Color(0xFF563D7C),
  'scss': Color(0xFF563D7C),
  'sass': Color(0xFF563D7C),
  'html': Color(0xFFE34C26),
  'xml': Color(0xFFE34C26),
  'json': Color(0xFF6B8E23),
  'sql': Color(0xFFE38C00),
  'yaml': Color(0xFFCB171E),
  'yml': Color(0xFFCB171E),
  'markdown': Color(0xFF083FA1),
  'md': Color(0xFF083FA1),
};

/// Default colour for unknown languages — GitHub grey.
const Color kUnknownLanguageColor = Color(0xFF8B949E);

/// Resolves the brand colour for [language] (case-insensitive).
///
/// Returns [kUnknownLanguageColor] when [language] is null, empty,
/// or not in [kLanguageBrandColors].
Color colorForLanguage(String? language) {
  if (language == null) return kUnknownLanguageColor;
  return kLanguageBrandColors[language.toLowerCase()] ??
      kUnknownLanguageColor;
}
