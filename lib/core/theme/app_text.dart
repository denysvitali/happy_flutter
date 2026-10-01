import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// The app's text roles for lists, rows, headers and badges.
///
/// Every row-like text run is one of these roles, so the same job renders
/// identically on every screen: same size, weight, line height and color
/// logic. Do not build row text from `textTheme.xxx?.copyWith(fontSize: …)`;
/// pick a role (the design-system guard test enforces this for the sessions
/// feature) and pass only a [Color] when the state needs one.
///
/// | role        | size | weight | use |
/// |-------------|------|--------|-----|
/// | [title]     | 14   | 600    | row names: sessions, workspaces, folders |
/// | [secondary] | 12   | 400    | text under a title, previews, timestamps |
/// | [label]     | 12   | 600    | section headers, chip labels |
/// | [badge]     | 12   | 700    | counts, pills, timers (tabular figures) |
/// | [screenTitle] | 18 | 600    | app bar titles, on every screen |
abstract final class AppText {
  /// App bar title — the theme's own app bar style, so a pushed screen's
  /// title is the same size as a tab's.
  static TextStyle screenTitle(ThemeData theme) =>
      theme.appBarTheme.titleTextStyle ??
      _base(
        theme,
        size: AppFontSize.xl,
        weight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      );

  /// Row names. [color] defaults to `onSurface` — never the theme's muted
  /// title color — so a title is equally legible on every screen.
  static TextStyle title(ThemeData theme, [Color? color]) => _base(
    theme,
    size: AppFontSize.base,
    weight: FontWeight.w600,
    color: color ?? theme.colorScheme.onSurface,
  );

  /// Secondary detail under a row name. [color] defaults to
  /// `onSurfaceVariant`.
  static TextStyle secondary(ThemeData theme, [Color? color]) => _base(
    theme,
    size: AppFontSize.sm,
    weight: FontWeight.w400,
    color: color ?? theme.colorScheme.onSurfaceVariant,
  );

  /// Section headers, filter chips and their labels.
  static TextStyle label(ThemeData theme, [Color? color]) => _base(
    theme,
    size: AppFontSize.sm,
    weight: FontWeight.w600,
    color: color ?? theme.colorScheme.onSurfaceVariant,
  );

  /// Counts, pills and timers, with tabular figures so digits do not jitter.
  static TextStyle badge(ThemeData theme, [Color? color]) => _base(
    theme,
    size: AppFontSize.sm,
    weight: FontWeight.w700,
    color: color ?? theme.colorScheme.onSurfaceVariant,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// [secondary] in the monospace family, for paths and identifiers.
  static TextStyle mono(ThemeData theme, [Color? color]) =>
      secondary(theme, color).copyWith(fontFamily: 'monospace');

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
