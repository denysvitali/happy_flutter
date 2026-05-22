import 'package:flutter/material.dart';

import 'package:happy_flutter/core/theme/app_colors.dart';

/// Theme extension for semantic and app-specific colors.
@immutable
class AppColorScheme extends ThemeExtension<AppColorScheme> {
  const AppColorScheme({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.bubbleUser,
    required this.bubbleAssistant,
    required this.bubbleUserText,
    required this.bubbleAssistantText,
    // ── Text hierarchy ────────────────────────────────────────────────────
    /// High-emphasis foreground — headings, titles, primary body copy.
    required this.textPrimary,
    /// Medium-emphasis foreground — list tile titles, body large/medium.
    required this.textSecondary,
    /// Low-emphasis foreground — subtitles, captions, secondary list text.
    required this.textMuted,
    /// Placeholder / hint foreground — input hints, icon tints, nav labels.
    required this.textSubtle,
    // ── Interactive ───────────────────────────────────────────────────────
    /// Border color used on error / danger input states.
    required this.errorBorder,
    /// Fill color for disabled filled-button states.
    required this.disabledFill,
    // ── Overlay ───────────────────────────────────────────────────────────
    /// Background for floating snack-bars.
    required this.snackBarBackground,
  });

  factory AppColorScheme.light() {
    return const AppColorScheme(
      success: AppColors.success,
      onSuccess: Colors.white,
      successContainer: Color(0xFFDDF6E5),
      warning: AppColors.warning,
      onWarning: Color(0xFF3D2500),
      warningContainer: Color(0xFFFFE7C2),
      info: AppColors.info,
      onInfo: Color(0xFF3B2A00),
      infoContainer: Color(0xFFFFEDBF),
      danger: Color(0xFFEF4444),
      onDanger: Colors.white,
      dangerContainer: Color(0xFFFEE2E2),
      shimmerBase: AppColors.shimmerBase,
      shimmerHighlight: AppColors.shimmerHighlight,
      bubbleUser: Color(0xFF2563EB),
      bubbleAssistant: Color(0xFFF1F5F9),
      bubbleUserText: Colors.white,
      bubbleAssistantText: Color(0xFF1E293B),
      // Text hierarchy
      textPrimary: Color(0xFF0F172A),
      textSecondary: Color(0xFF1E293B),
      textMuted: Color(0xFF475569),
      textSubtle: Color(0xFF64748B),
      // Interactive
      errorBorder: Color(0xFFEF4444),
      disabledFill: Color(0xFF94A3B8),
      // Overlay
      snackBarBackground: Color(0xFF1E293B),
    );
  }

  factory AppColorScheme.dark() {
    return const AppColorScheme(
      success: AppColors.success,
      onSuccess: Color(0xFF052E16),
      successContainer: Color(0xFF123822),
      warning: AppColors.warning,
      onWarning: Color(0xFF432C00),
      warningContainer: Color(0xFF5A3B00),
      info: AppColors.info,
      onInfo: Color(0xFF432F00),
      infoContainer: Color(0xFF5B4100),
      danger: Color(0xFFF87171),
      onDanger: Color(0xFF450A0A),
      dangerContainer: Color(0xFF5F1D1D),
      shimmerBase: Color(0xFF252836),
      shimmerHighlight: Color(0xFF31374A),
      bubbleUser: Color(0xFF3B82F6),
      bubbleAssistant: Color(0xFF252836),
      bubbleUserText: Colors.white,
      bubbleAssistantText: Color(0xFFE2E8F0),
      // Text hierarchy
      textPrimary: Colors.white,
      textSecondary: Color(0xFFE2E8F0),
      textMuted: Color(0xFFCBD5E1),
      textSubtle: Color(0xFF94A3B8),
      // Interactive
      errorBorder: Color(0xFFEF4444),
      disabledFill: Color(0xFF94A3B8),
      // Overlay
      snackBarBackground: Color(0xFF334155),
    );
  }

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color danger;
  final Color onDanger;
  final Color dangerContainer;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final Color bubbleUser;
  final Color bubbleAssistant;
  final Color bubbleUserText;
  final Color bubbleAssistantText;
  // Text hierarchy
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textSubtle;
  // Interactive
  final Color errorBorder;
  final Color disabledFill;
  // Overlay
  final Color snackBarBackground;

  @override
  AppColorScheme copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? danger,
    Color? onDanger,
    Color? dangerContainer,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? bubbleUser,
    Color? bubbleAssistant,
    Color? bubbleUserText,
    Color? bubbleAssistantText,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textSubtle,
    Color? errorBorder,
    Color? disabledFill,
    Color? snackBarBackground,
  }) {
    return AppColorScheme(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      bubbleUser: bubbleUser ?? this.bubbleUser,
      bubbleAssistant: bubbleAssistant ?? this.bubbleAssistant,
      bubbleUserText: bubbleUserText ?? this.bubbleUserText,
      bubbleAssistantText: bubbleAssistantText ?? this.bubbleAssistantText,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textSubtle: textSubtle ?? this.textSubtle,
      errorBorder: errorBorder ?? this.errorBorder,
      disabledFill: disabledFill ?? this.disabledFill,
      snackBarBackground: snackBarBackground ?? this.snackBarBackground,
    );
  }

  @override
  AppColorScheme lerp(
    covariant ThemeExtension<AppColorScheme>? other,
    double t,
  ) {
    if (other is! AppColorScheme) {
      return this;
    }

    return AppColorScheme(
      success: Color.lerp(success, other.success, t) ?? success,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t) ?? onSuccess,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t) ??
          successContainer,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      onWarning: Color.lerp(onWarning, other.onWarning, t) ?? onWarning,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t) ??
          warningContainer,
      info: Color.lerp(info, other.info, t) ?? info,
      onInfo: Color.lerp(onInfo, other.onInfo, t) ?? onInfo,
      infoContainer:
          Color.lerp(infoContainer, other.infoContainer, t) ?? infoContainer,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      onDanger: Color.lerp(onDanger, other.onDanger, t) ?? onDanger,
      dangerContainer:
          Color.lerp(dangerContainer, other.dangerContainer, t) ??
          dangerContainer,
      shimmerBase:
          Color.lerp(shimmerBase, other.shimmerBase, t) ?? shimmerBase,
      shimmerHighlight:
          Color.lerp(shimmerHighlight, other.shimmerHighlight, t) ??
          shimmerHighlight,
      bubbleUser: Color.lerp(bubbleUser, other.bubbleUser, t) ?? bubbleUser,
      bubbleAssistant:
          Color.lerp(bubbleAssistant, other.bubbleAssistant, t) ??
          bubbleAssistant,
      bubbleUserText:
          Color.lerp(bubbleUserText, other.bubbleUserText, t) ?? bubbleUserText,
      bubbleAssistantText:
          Color.lerp(bubbleAssistantText, other.bubbleAssistantText, t) ??
          bubbleAssistantText,
      textPrimary:
          Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      textSubtle: Color.lerp(textSubtle, other.textSubtle, t) ?? textSubtle,
      errorBorder:
          Color.lerp(errorBorder, other.errorBorder, t) ?? errorBorder,
      disabledFill:
          Color.lerp(disabledFill, other.disabledFill, t) ?? disabledFill,
      snackBarBackground:
          Color.lerp(
            snackBarBackground,
            other.snackBarBackground,
            t,
          ) ??
          snackBarBackground,
    );
  }
}
