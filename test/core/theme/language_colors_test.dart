import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/theme/language_colors.dart';

void main() {
  group('kLanguageBrandColors', () {
    test('covers all canonical languages', () {
      for (final lang in const [
        'dart',
        'python',
        'javascript',
        'typescript',
        'rust',
        'go',
        'swift',
        'kotlin',
        'java',
        'ruby',
        'bash',
        'css',
        'html',
        'json',
        'sql',
        'yaml',
        'markdown',
      ]) {
        expect(
          kLanguageBrandColors[lang],
          isNotNull,
          reason: 'missing canonical language: $lang',
        );
        expect(
          kLanguageBrandColors[lang],
          isA<Color>(),
        );
      }
    });

    test('language aliases share a colour with their canonical key', () {
      // GitHub Linguist treats `py` as an alias for `python`, `js`
      // for `javascript`, etc. Make sure every alias maps to the
      // same colour as its canonical language.
      for (final entry in const <String, String>{
        'py': 'python',
        'jsx': 'javascript',
        'ts': 'typescript',
        'tsx': 'typescript',
        'rs': 'rust',
        'golang': 'go',
        'kt': 'kotlin',
        'rb': 'ruby',
        'sh': 'bash',
        'shell': 'bash',
        'scss': 'css',
        'sass': 'css',
        'xml': 'html',
        'yml': 'yaml',
        'md': 'markdown',
      }.entries) {
        expect(
          kLanguageBrandColors[entry.key],
          equals(kLanguageBrandColors[entry.value]),
          reason: 'alias ${entry.key} must share colour with '
              '${entry.value}',
        );
      }
    });

    test('all entries are lowercased keys', () {
      for (final key in kLanguageBrandColors.keys) {
        expect(key, equals(key.toLowerCase()),
            reason: 'language key "$key" is not lowercased');
      }
    });
  });

  group('colorForLanguage', () {
    test('returns the brand colour for known languages (case-insensitive)',
        () {
      expect(colorForLanguage('dart'), const Color(0xFF00B4AB));
      expect(colorForLanguage('DART'), const Color(0xFF00B4AB));
      expect(colorForLanguage('Py'), const Color(0xFF3572A5));
      expect(colorForLanguage('rust'), const Color(0xFFDEA584));
    });

    test('returns the unknown-language colour for null', () {
      expect(colorForLanguage(null), kUnknownLanguageColor);
    });

    test('returns the unknown-language colour for empty string', () {
      expect(colorForLanguage(''), kUnknownLanguageColor);
    });

    test('returns the unknown-language colour for unknown language', () {
      expect(colorForLanguage('klingon'), kUnknownLanguageColor);
      expect(colorForLanguage('brainfuck'), kUnknownLanguageColor);
    });
  });
}
