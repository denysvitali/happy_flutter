/// Semantic color tokens for the Happy Flutter app.
///
/// All semantic colors (status, states, brands) are centralized here
/// as static const values so that every component references a single
/// source of truth. For light/dark theme-aware colors, use
/// `Theme.of(context).colorScheme.*` or Material 3 color schemes instead.
library;

import 'package:flutter/painting.dart';

// ─── Status & State Colors ───────────────────────────────────────────────────

/// Semantic status and state color tokens.
///
/// These colors convey status, presence, and user feedback across the app.
///
/// Usage: `color: AppColors.success`
abstract final class AppColors {
  /// Success green – online presence, connected state, confirmed actions.
  /// Used for "online" status, successful operations,
  /// and enabled states.
  static const Color success = Color(0xFF34C759);

  /// Warning orange – connecting/transitioning state, pending operations.
  /// Used for "connecting" session status and intermediate states.
  static const Color warning = Color(0xFFFF9500);

  /// Info amber – informational states, permissions pending, disabled features.
  /// Used for permission requests and informational messages.
  static const Color info = Color(0xFFF59E0B);

  /// iOS system blue – interactive elements, links, toggles in settings.
  /// Used in iOS-style settings screens and interactive components.
  static const Color iosBlue = Color(0xFF007AFF);

  // ─── Semantic Neutral & Text Colors (Light Mode) ──────────────────────

  /// Shimmer base – light background for skeleton loaders.
  static const Color shimmerBase = Color(0xFFE0E0E0);

  /// Shimmer highlight – lighter shimmer effect animation.
  static const Color shimmerHighlight = Color(0xFFF8F8F8);

  // ─── Diff & Code Colors (Light) ──────────────────────────────────────

  /// Diff: added line background (light mode).
  static const Color diffAddedBgLight = Color(0xFFE6FFEC);

  /// Diff: removed line background (light mode).
  static const Color diffRemovedBgLight = Color(0xFFFFEBE9);

  /// Diff: hunk header background (light mode).
  static const Color diffHunkHeaderBgLight = Color(0xFFF0F0F0);

  /// Diff: line number background (light mode).
  static const Color diffLineNumberBgLight = Color(0xFFF5F5F5);

  /// Diff: added text (light mode).
  static const Color diffAddedTextLight = Color(0xFF1A7F37);

  /// Diff: removed text (light mode).
  static const Color diffRemovedTextLight = Color(0xFFCF222E);

  /// Diff: context text (light mode).
  static const Color diffContextTextLight = Color(0xFF24292F);

  /// Diff: hunk header text (light mode).
  static const Color diffHunkHeaderTextLight = Color(0xFF656D76);

  /// Diff: line number text (light mode).
  static const Color diffLineNumberTextLight = Color(0xFF6E7781);

  /// Diff: inline added background (light mode).
  static const Color diffInlineAddedBgLight = Color(0x4AC26B4D);

  /// Diff: inline added text (light mode).
  static const Color diffInlineAddedTextLight = Color(0xFF1A7F37);

  /// Diff: inline removed background (light mode).
  static const Color diffInlineRemovedBgLight = Color(0xFFA39E4D);

  /// Diff: inline removed text (light mode).
  static const Color diffInlineRemovedTextLight = Color(0xFFCF222E);

  /// Diff: leading space indicator (light mode).
  static const Color diffLeadingSpaceDot = Color(0xFFD4D4D4);

  // ─── Diff & Code Colors (Dark) ───────────────────────────────────────

  /// Diff: added line background (dark mode).
  static const Color diffAddedBgDark = Color(0xFF1A2D1A);

  /// Diff: removed line background (dark mode).
  static const Color diffRemovedBgDark = Color(0xFF2D1A1A);

  /// Diff: hunk header background (dark mode).
  static const Color diffHunkHeaderBgDark = Color(0xFF2D2D2D);

  /// Diff: line number background (dark mode).
  static const Color diffLineNumberBgDark = Color(0xFF252525);

  /// Diff: added text (dark mode).
  static const Color diffAddedTextDark = Color(0xFF4AC26B);

  /// Diff: removed text (dark mode).
  static const Color diffRemovedTextDark = Color(0xFFFF7B72);

  /// Diff: context text (dark mode).
  static const Color diffContextTextDark = Color(0xFFC9D1D9);
}

// ─── Opacity ─────────────────────────────────────────────────────────────────

/// Shared opacity levels for overlays, tints, and disabled states.
abstract final class AppOpacity {
  /// 0.08 – barely visible tint (hover state).
  static const double faint = 0.08;

  /// 0.12 – subtle overlay (selection, focus ring).
  static const double subtle = 0.12;

  /// 0.15 – soft scrim (divider, placeholder bg).
  static const double soft = 0.15;

  /// 0.30 – medium overlay (disabled surface).
  static const double medium = 0.30;

  /// 0.50 – half opacity, placeholder text, modal backdrop.
  static const double half = 0.50;

  /// 0.50 – alias for [half].
  static const double strong = half;

  /// 0.70 – prominent but not full opacity.
  static const double high = 0.70;
}
