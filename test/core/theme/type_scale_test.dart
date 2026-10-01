import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';

/// The app's type scale lives in [AppFontSize]; the theme must only use it
/// for text that ships in components (buttons, list tiles, dialogs, ...), so
/// a screen built from stock widgets cannot drift to a stray 15 or 11.
void main() {
  final scale = <double>{
    AppFontSize.sm,
    AppFontSize.md,
    AppFontSize.base,
    AppFontSize.lg,
    AppFontSize.xl,
  };

  for (final dark in [false, true]) {
    final theme = dark
        ? ThemeHelper.buildDarkTheme()
        : ThemeHelper.buildLightTheme();
    final label = dark ? 'dark' : 'light';

    test('$label small text styles share one size', () {
      final t = theme.textTheme;
      expect(t.bodySmall?.fontSize, AppFontSize.sm);
      expect(t.labelSmall?.fontSize, AppFontSize.sm);
      expect(t.labelMedium?.fontSize, AppFontSize.sm);
    });

    test('$label body, label and title styles sit on the scale', () {
      final t = theme.textTheme;
      expect(t.bodyMedium?.fontSize, AppFontSize.base);
      expect(t.labelLarge?.fontSize, AppFontSize.base);
      expect(t.bodyLarge?.fontSize, AppFontSize.lg);
      expect(t.titleMedium?.fontSize, AppFontSize.lg);
      expect(t.titleSmall?.fontSize, AppFontSize.base);
    });

    test('$label component themes use scale sizes only', () {
      final sizes = <String, double?>{
        'appBar title': theme.appBarTheme.titleTextStyle?.fontSize,
        'dialog title': theme.dialogTheme.titleTextStyle?.fontSize,
        'dialog content': theme.dialogTheme.contentTextStyle?.fontSize,
        'snack bar': theme.snackBarTheme.contentTextStyle?.fontSize,
        'list title': theme.listTileTheme.titleTextStyle?.fontSize,
        'list subtitle': theme.listTileTheme.subtitleTextStyle?.fontSize,
        'chip': theme.chipTheme.labelStyle?.fontSize,
        'elevated button': theme.elevatedButtonTheme.style?.textStyle
            ?.resolve({})
            ?.fontSize,
        'filled button': theme.filledButtonTheme.style?.textStyle
            ?.resolve({})
            ?.fontSize,
        'outlined button': theme.outlinedButtonTheme.style?.textStyle
            ?.resolve({})
            ?.fontSize,
      };
      for (final entry in sizes.entries) {
        expect(
          scale,
          contains(entry.value),
          reason: '${entry.key} uses ${entry.value}, which is off the scale',
        );
      }
    });
  }
}
