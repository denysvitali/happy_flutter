import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// The one type scale for the Sessions list (Mission Control).
///
/// Every text run on the screen is one of four roles, so sizes, weights and
/// tracking cannot drift apart between the focus queue, the workspace list,
/// the filter chips and the section headers.
abstract final class MissionType {
  /// Row names — session and workspace titles. 14sp / 600.
  static TextStyle title(ThemeData theme, Color color) => _base(
    theme,
    size: AppFontSize.base,
    weight: FontWeight.w600,
    color: color,
  );

  /// Secondary detail under a row name. 12sp / 400.
  static TextStyle meta(ThemeData theme, Color color) =>
      _base(theme, size: AppFontSize.sm, weight: FontWeight.w400, color: color);

  /// Section headers, filter chips and their labels. 12sp / 600.
  static TextStyle label(ThemeData theme, Color color) =>
      _base(theme, size: AppFontSize.sm, weight: FontWeight.w600, color: color);

  /// Counts, pills and timers. 12sp / 700 with tabular figures.
  static TextStyle badge(ThemeData theme, Color color) => _base(
    theme,
    size: AppFontSize.sm,
    weight: FontWeight.w700,
    color: color,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static TextStyle _base(
    ThemeData theme, {
    required double size,
    required FontWeight weight,
    required Color color,
  }) => (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: 0,
    height: 1.3,
  );
}
