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

  /// Error red – destructive actions, offline state, failed operations.
  /// Used for error messages, high-utilization indicators, and alerts.
  static const Color error = Color(0xFFFF3B30);

  /// Info amber – informational states, permissions pending, disabled features.
  /// Used for permission requests and informational messages.
  static const Color info = Color(0xFFF59E0B);

  /// iOS system blue – interactive elements, links, toggles in settings.
  /// Used in iOS-style settings screens and interactive components.
  static const Color iosBlue = Color(0xFF007AFF);

  /// Z.AI brand indigo – Z.AI (Zhipu GLM) provider accent.
  /// Matches [colorForProfile]'s `'zai'` case so the brand color has one home.
  static const Color zai = Color(0xFF6366F1);

  /// Grok (xAI) provider accent – mid slate that stays legible on light and
  /// dark surfaces (the xAI brand itself is pure black/white).
  /// Qwen brand purple, used by the provider usage card icon.
  static const Color qwen = Color(0xFF615CED);

  /// Matches [colorForProfile]'s `'grok'` case so the brand color has one
  /// home.
  static const Color grok = Color(0xFF64748B);

  /// Permission mode: automatically accept edits.
  static const Color permissionAutoEdit = Color(0xFF9C27B0);

  /// Permission mode: read-only execution.
  static const Color permissionReadOnly = Color(0xFF00897B);

  /// Permission mode: bypass prompts (destructive emphasis).
  static const Color permissionBypass = Color(0xFFE53935);

  /// Permission mode: unrestricted execution.
  static const Color permissionUnrestricted = Color(0xFFE64A19);

  static const Color permissionSurfaceLight = Color(0xFFFFF8E1);
  static const Color permissionSurfaceDark = Color(0xFF2D1F00);
  static const Color permissionBorderLight = Color(0xFFFFB300);
  static const Color permissionBorderDark = Color(0xFF7A5C00);

  // ─── Priority Colors (Zen / Todo) ────────────────────────────────────

  /// Priority: critical — iOS system red. Aliased to [error] so the two
  /// signals never drift apart.
  static const Color priorityCritical = error;

  /// Priority: high — iOS system orange. Aliased to [warning].
  static const Color priorityHigh = warning;

  /// Priority: medium — iOS system amber.
  static const Color priorityMedium = Color(0xFFF59E0B);

  /// Priority: low — iOS system gray.
  static const Color priorityLow = Color(0xFF8E8E93);

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

  /// Diff: inline removed background (light mode) — translucent red.
  /// Replaces the prior olive `#A39E4D` value, which read as a "modified"
  /// yellow-green and broke the added/removed mental model.
  static const Color diffInlineRemovedBgLight = Color(0x4ACF222E);

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

  /// Diff: hunk header text (dark mode).
  static const Color diffHunkHeaderTextDark = Color(0xFF8B949E);

  /// Diff: line number text (dark mode).
  static const Color diffLineNumberTextDark = Color(0xFF6E7681);

  /// Diff: inline added background (dark mode) — translucent green.
  static const Color diffInlineAddedBgDark = Color(0x4AC26B33);

  /// Diff: inline added text (dark mode).
  static const Color diffInlineAddedTextDark = Color(0xFF4AC26B);

  /// Diff: inline removed background (dark mode) — translucent red.
  /// Replaces the prior olive `#A39E33` value, which read as a "modified"
  /// yellow-green and broke the added/removed mental model. Uses a
  /// distinct red shade from the light value so the two modes aren't
  /// visually identical (and so the regression test that asserts
  /// light≠dark stays meaningful).
  static const Color diffInlineRemovedBgDark = Color(0x4AFF7B72);

  /// Diff: inline removed text (dark mode).
  static const Color diffInlineRemovedTextDark = Color(0xFFFF7B72);

  /// Diff: leading space dot (dark mode).
  static const Color diffLeadingSpaceDotDark = Color(0xFF4A4A4A);
}

// ─── Opacity ─────────────────────────────────────────────────────────────────

// ─── Profile Colors ──────────────────────────────────────────────────────────

/// Returns the brand color associated with a profile ID.
Color colorForProfile(String id) {
  switch (id) {
    case 'anthropic':
      return const Color(0xFFD97757);
    case 'deepseek':
      return const Color(0xFF4A6CF7);
    case 'zai':
      return AppColors.zai;
    case 'grok':
      return AppColors.grok;
    case 'qwen':
    case 'qwen-token-plan-codex':
      return AppColors.qwen;
    case 'minimax':
      return const Color(0xFFFF6B35);
    case 'xiaomi-mimo':
      return const Color(0xFFFF6900);
    case 'openrouter':
      return const Color(0xFF6D28D9);
    case 'openai':
      return const Color(0xFF10A37F);
    case 'azure-openai':
      return const Color(0xFF0078D4);
    default:
      return const Color(0xFF6B7280);
  }
}

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
