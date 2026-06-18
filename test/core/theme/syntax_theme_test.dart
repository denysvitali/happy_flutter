import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/theme/code_viewer_theme.dart';
import 'package:happy_flutter/core/theme/syntax_theme.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';

void main() {
  group('SyntaxTheme', () {
    test('light palette exposes all canonical token keys', () {
      const theme = SyntaxTheme.light;
      for (final key in const [
        'keyword',
        'string',
        'number',
        'boolean',
        'property',
        'comment',
        'default',
      ]) {
        expect(theme.colorFor(key), isA<Color>(),
            reason: 'light theme must define $key');
      }
    });

    test('dark palette exposes all canonical token keys', () {
      const theme = SyntaxTheme.dark;
      for (final key in const [
        'keyword',
        'string',
        'number',
        'boolean',
        'property',
        'comment',
        'default',
      ]) {
        expect(theme.colorFor(key), isA<Color>(),
            reason: 'dark theme must define $key');
      }
    });

    test('colorFor falls back to defaultText for unknown keys', () {
      const theme = SyntaxTheme.dark;
      expect(
        theme.colorFor('this-key-does-not-exist'),
        theme.defaultText,
      );
    });

    test('bracketFor cycles through the 5 rainbow levels', () {
      const theme = SyntaxTheme.dark;
      // The 5 levels should all be distinct colours.
      final levels = <Color>{
        for (var i = 1; i <= 5; i++) theme.bracketFor(i),
      };
      expect(levels.length, 5,
          reason: 'expected 5 distinct rainbow-bracket colours');
    });

    test('copyWith preserves the original tokens map when no override', () {
      const original = SyntaxTheme.dark;
      final copy = original.copyWith();
      // copyWith with no args returns a logically equivalent theme.
      expect(copy.tokens, same(original.tokens));
      expect(copy.bracketNesting, same(original.bracketNesting));
      expect(copy.defaultText, original.defaultText);
    });
  });

  group('ThemeHelper SyntaxTheme registration', () {
    test('light theme registers the SyntaxTheme extension', () {
      final theme = ThemeHelper.buildLightTheme();
      final ext = theme.extension<SyntaxTheme>();
      expect(ext, isNotNull);
      expect(ext, equals(SyntaxTheme.light));
    });

    test('dark theme registers the SyntaxTheme extension', () {
      final theme = ThemeHelper.buildDarkTheme();
      final ext = theme.extension<SyntaxTheme>();
      expect(ext, isNotNull);
      expect(ext, equals(SyntaxTheme.dark));
    });

    test('light theme registers the CodeViewerTheme extension', () {
      final theme = ThemeHelper.buildLightTheme();
      final ext = theme.extension<CodeViewerTheme>();
      expect(ext, isNotNull);
      expect(ext, equals(CodeViewerTheme.light));
    });

    test('dark theme registers the CodeViewerTheme extension', () {
      final theme = ThemeHelper.buildDarkTheme();
      final ext = theme.extension<CodeViewerTheme>();
      expect(ext, isNotNull);
      expect(ext, equals(CodeViewerTheme.dark));
    });
  });
}
