import 'package:flutter/material.dart';

import 'package:happy_flutter/core/theme/app_tokens.dart';

/// Centralized typography tokens aligned to the Material 3 type scale.
abstract final class AppTypography {
  static const String _fontFamily = 'Inter';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 57,
    fontWeight: FontWeight.w400,
    height: AppLineHeight.tight,
    letterSpacing: -0.25,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 45,
    fontWeight: FontWeight.w400,
    height: AppLineHeight.tight,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w400,
    height: AppLineHeight.tight,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w400,
    height: AppLineHeight.tight,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w400,
    height: AppLineHeight.tight,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w400,
    height: AppLineHeight.tight,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w400,
    height: AppLineHeight.tight,
    letterSpacing: 0,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: AppLineHeight.normal,
    letterSpacing: 0.15,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: AppLineHeight.normal,
    letterSpacing: 0.1,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: AppLineHeight.relaxed,
    letterSpacing: 0.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: AppLineHeight.normal,
    letterSpacing: 0.25,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: AppLineHeight.normal,
    letterSpacing: 0.4,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: AppLineHeight.normal,
    letterSpacing: 0.1,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: AppLineHeight.normal,
    letterSpacing: 0.5,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: AppLineHeight.normal,
    letterSpacing: 0.5,
  );

  static TextTheme applyToTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: _merge(base.displayLarge, displayLarge),
      displayMedium: _merge(base.displayMedium, displayMedium),
      displaySmall: _merge(base.displaySmall, displaySmall),
      headlineLarge: _merge(base.headlineLarge, headlineLarge),
      headlineMedium: _merge(base.headlineMedium, headlineMedium),
      headlineSmall: _merge(base.headlineSmall, headlineSmall),
      titleLarge: _merge(base.titleLarge, titleLarge),
      titleMedium: _merge(base.titleMedium, titleMedium),
      titleSmall: _merge(base.titleSmall, titleSmall),
      bodyLarge: _merge(base.bodyLarge, bodyLarge),
      bodyMedium: _merge(base.bodyMedium, bodyMedium),
      bodySmall: _merge(base.bodySmall, bodySmall),
      labelLarge: _merge(base.labelLarge, labelLarge),
      labelMedium: _merge(base.labelMedium, labelMedium),
      labelSmall: _merge(base.labelSmall, labelSmall),
    );
  }

  static TextStyle _merge(TextStyle? base, TextStyle token) {
    if (base == null) {
      return token;
    }

    return token.copyWith(
      color: base.color,
      backgroundColor: base.backgroundColor,
      decoration: base.decoration,
      decorationColor: base.decorationColor,
      decorationStyle: base.decorationStyle,
      decorationThickness: base.decorationThickness,
      debugLabel: base.debugLabel,
      fontFamilyFallback: base.fontFamilyFallback,
      overflow: base.overflow,
      shadows: base.shadows,
      textBaseline: base.textBaseline,
    );
  }
}
