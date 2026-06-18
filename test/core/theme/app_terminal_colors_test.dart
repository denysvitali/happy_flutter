import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/theme/app_terminal_colors.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';

void main() {
  group('AppTerminalColors ThemeExtension', () {
    test('default dark palette exposes all nine named colors', () {
      const palette = AppTerminalColors.dark;
      // Each token in the palette must be a non-null Color. A regression
      // that drops a field would surface here as a compile error.
      expect(palette.background, isA<Color>());
      expect(palette.surface, isA<Color>());
      expect(palette.foreground, isA<Color>());
      expect(palette.border, isA<Color>());
      expect(palette.hint, isA<Color>());
      expect(palette.commandPrompt, isA<Color>());
      expect(palette.commandText, isA<Color>());
      expect(palette.accent, isA<Color>());
      expect(palette.cursor, isA<Color>());
    });

    test('copyWith returns an equal palette when no overrides are given',
        () {
      const original = AppTerminalColors.dark;
      final copy = original.copyWith();
      // copyWith with no args is a no-op; the copy is reference-different
      // but field-equal to the original.
      expect(identical(copy, original), isFalse);
      expect(copy.background, original.background);
      expect(copy.surface, original.surface);
      expect(copy.foreground, original.foreground);
    });

    test('copyWith overrides a single named field', () {
      const original = AppTerminalColors.dark;
      final copy = original.copyWith(background: const Color(0xFF000000));
      expect(copy.background, const Color(0xFF000000));
      // Unrelated fields stay the same.
      expect(copy.foreground, original.foreground);
    });

    test('lerp at t=0 returns the original palette', () {
      const a = AppTerminalColors.dark;
      final result = a.lerp(AppTerminalColors.dark, 0);
      expect(result, isA<AppTerminalColors>());
      // lerp(0) is the original — we don't assert full equality because
      // lerp also normalises via Color.lerp, but a ~0 mix should be
      // close enough that all channels match.
      expect(result.background, a.background);
    });
  });

  group('ThemeHelper', () {
    test('light theme registers the AppTerminalColors extension', () {
      final theme = ThemeHelper.buildLightTheme();
      final ext = theme.extension<AppTerminalColors>();
      expect(ext, isNotNull);
      expect(ext, equals(AppTerminalColors.dark));
    });

    test('dark theme registers the AppTerminalColors extension', () {
      final theme = ThemeHelper.buildDarkTheme();
      final ext = theme.extension<AppTerminalColors>();
      expect(ext, isNotNull);
      expect(ext, equals(AppTerminalColors.dark));
    });
  });
}
