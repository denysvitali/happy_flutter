import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/theme/diff_theme.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';

void main() {
  group('DiffTheme', () {
    test('light palette has translucent red inlineRemovedBg, not olive', () {
      // Regression: the prior DiffViewColors.light() used
      // `Color(0xFFA39E4D)` (olive/khaki) for inline-removed, which
      // read as "modified" instead of "removed" in Edit and MultiEdit
      // tool outputs. The new value must be a red-tinted colour, not
      // olive.
      const palette = DiffTheme.light;
      final inlineRemoved = palette.inlineRemovedBg;

      // Resolve to (r, g, b, a) and assert: red channel dominant, green
      // is not the dominant channel (which is the signature of olive).
      final r = (inlineRemoved.r * 255).round();
      final g = (inlineRemoved.g * 255).round();
      final b = (inlineRemoved.b * 255).round();
      // Olive is roughly R≈163, G≈158, B≈77. Anything where green
      // dominates over red is suspect. The new value is a translucent
      // red over a red base — red should clearly exceed green.
      expect(
        r,
        greaterThan(g),
        reason: 'inlineRemovedBg in light mode should be red, not olive '
            '(got R=$r G=$g B=$b)',
      );
    });

    test('dark palette has translucent red inlineRemovedBg, not olive', () {
      const palette = DiffTheme.dark;
      final inlineRemoved = palette.inlineRemovedBg;
      final r = (inlineRemoved.r * 255).round();
      final g = (inlineRemoved.g * 255).round();
      expect(
        r,
        greaterThan(g),
        reason: 'inlineRemovedBg in dark mode should be red, not olive '
            '(got R=$r G=$g)',
      );
    });

    test('light palette exposes all 15 named slots', () {
      const palette = DiffTheme.light;
      expect(palette.addedBg, isA<Color>());
      expect(palette.removedBg, isA<Color>());
      expect(palette.contextBg, isA<Color>());
      expect(palette.addedText, isA<Color>());
      expect(palette.removedText, isA<Color>());
      expect(palette.contextText, isA<Color>());
      expect(palette.hunkHeaderBg, isA<Color>());
      expect(palette.hunkHeaderText, isA<Color>());
      expect(palette.lineNumberBg, isA<Color>());
      expect(palette.lineNumberText, isA<Color>());
      expect(palette.inlineAddedBg, isA<Color>());
      expect(palette.inlineAddedText, isA<Color>());
      expect(palette.inlineRemovedBg, isA<Color>());
      expect(palette.inlineRemovedText, isA<Color>());
      expect(palette.leadingSpaceDot, isA<Color>());
    });

    test('dark palette exposes all 15 named slots', () {
      const palette = DiffTheme.dark;
      expect(palette.addedBg, isA<Color>());
      expect(palette.removedBg, isA<Color>());
      expect(palette.contextBg, isA<Color>());
      expect(palette.addedText, isA<Color>());
      expect(palette.removedText, isA<Color>());
      expect(palette.contextText, isA<Color>());
      expect(palette.hunkHeaderBg, isA<Color>());
      expect(palette.hunkHeaderText, isA<Color>());
      expect(palette.lineNumberBg, isA<Color>());
      expect(palette.lineNumberText, isA<Color>());
      expect(palette.inlineAddedBg, isA<Color>());
      expect(palette.inlineAddedText, isA<Color>());
      expect(palette.inlineRemovedBg, isA<Color>());
      expect(palette.inlineRemovedText, isA<Color>());
      expect(palette.leadingSpaceDot, isA<Color>());
    });

    test('copyWith preserves the original palette when no override', () {
      const original = DiffTheme.light;
      final copy = original.copyWith();
      expect(identical(copy, original), isFalse);
      expect(copy.addedBg, original.addedBg);
      expect(copy.inlineRemovedBg, original.inlineRemovedBg);
    });

    test('light and dark inlineRemovedBg differ', () {
      // The two modes must use distinct colour sets; a regression that
      // accidentally returned the same palette for both would surface
      // here.
      expect(
        DiffTheme.light.inlineRemovedBg,
        isNot(equals(DiffTheme.dark.inlineRemovedBg)),
      );
    });
  });

  group('AppColors diff tokens', () {
    test('the olive hex is no longer used by any token', () {
      // Belt-and-suspenders: the prior bug originated from the literal
      // `Color(0xFFA39E4D)`. Make sure no AppColors token now exposes
      // that exact value.
      final allDiffTokens = <Color>[
        AppColors.diffAddedBgLight,
        AppColors.diffRemovedBgLight,
        AppColors.diffHunkHeaderBgLight,
        AppColors.diffLineNumberBgLight,
        AppColors.diffAddedTextLight,
        AppColors.diffRemovedTextLight,
        AppColors.diffContextTextLight,
        AppColors.diffHunkHeaderTextLight,
        AppColors.diffLineNumberTextLight,
        AppColors.diffInlineAddedBgLight,
        AppColors.diffInlineAddedTextLight,
        AppColors.diffInlineRemovedBgLight,
        AppColors.diffInlineRemovedTextLight,
        AppColors.diffLeadingSpaceDot,
        AppColors.diffAddedBgDark,
        AppColors.diffRemovedBgDark,
        AppColors.diffHunkHeaderBgDark,
        AppColors.diffLineNumberBgDark,
        AppColors.diffAddedTextDark,
        AppColors.diffRemovedTextDark,
        AppColors.diffContextTextDark,
        AppColors.diffHunkHeaderTextDark,
        AppColors.diffLineNumberTextDark,
        AppColors.diffInlineAddedBgDark,
        AppColors.diffInlineAddedTextDark,
        AppColors.diffInlineRemovedBgDark,
        AppColors.diffInlineRemovedTextDark,
        AppColors.diffLeadingSpaceDotDark,
      ];
      for (final c in allDiffTokens) {
        expect(
          c,
          isNot(equals(const Color(0xFFA39E4D))),
          reason: 'olive value leaked into a diff token',
        );
        expect(
          c,
          isNot(equals(const Color(0xFFA39E33))),
          reason: 'dark-mode olive value leaked into a diff token',
        );
      }
    });
  });

  group('ThemeHelper DiffTheme registration', () {
    test('light theme registers the DiffTheme extension', () {
      final theme = ThemeHelper.buildLightTheme();
      final ext = theme.extension<DiffTheme>();
      expect(ext, isNotNull);
      expect(ext, equals(DiffTheme.light));
    });

    test('dark theme registers the DiffTheme extension', () {
      final theme = ThemeHelper.buildDarkTheme();
      final ext = theme.extension<DiffTheme>();
      expect(ext, isNotNull);
      expect(ext, equals(DiffTheme.dark));
    });
  });
}
