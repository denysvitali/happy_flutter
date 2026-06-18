import 'package:flutter/material.dart';

import '../ui/diff/diff_types.dart' as ui;
import 'app_colors.dart';

/// Theme extension carrying the diff palette used by the chat tool
/// diff views (Edit, MultiEdit, Codex, Gemini) and the legacy
/// `DiffView` facade.
///
/// The light palette mirrors GitHub's PR-diff styling (translucent
/// inline highlights over solid pastel line backgrounds). The dark
/// palette mirrors the same slots with a darker surface tier and
/// translucent inline highlights.
///
/// Resolved via `Theme.of(context).extension<DiffTheme>()` or the
/// `context.diffTheme` convenience.
///
/// **Bug fix:** the previous in-file `DiffViewColors.light().inlineRemovedBg`
/// was `#A39E4D` (olive), which read as "modified" instead of "removed"
/// in Edit and MultiEdit tool outputs. The new light/dark `inlineRemovedBg`
/// values are translucent red and the prior olive values are no longer
/// referenced anywhere in the project.
@immutable
class DiffTheme extends ThemeExtension<DiffTheme> {
  const DiffTheme({
    required this.addedBg,
    required this.removedBg,
    required this.contextBg,
    required this.addedText,
    required this.removedText,
    required this.contextText,
    required this.hunkHeaderBg,
    required this.hunkHeaderText,
    required this.lineNumberBg,
    required this.lineNumberText,
    required this.inlineAddedBg,
    required this.inlineAddedText,
    required this.inlineRemovedBg,
    required this.inlineRemovedText,
    required this.leadingSpaceDot,
  });

  final Color addedBg;
  final Color removedBg;
  final Color contextBg;
  final Color addedText;
  final Color removedText;
  final Color contextText;
  final Color hunkHeaderBg;
  final Color hunkHeaderText;
  final Color lineNumberBg;
  final Color lineNumberText;
  final Color inlineAddedBg;
  final Color inlineAddedText;
  final Color inlineRemovedBg;
  final Color inlineRemovedText;
  final Color leadingSpaceDot;

  /// Light palette (GitHub PR-diff style).
  static const DiffTheme light = DiffTheme(
    addedBg: AppColors.diffAddedBgLight,
    removedBg: AppColors.diffRemovedBgLight,
    contextBg: Color(0x00000000), // transparent — encoded as const Color
    addedText: AppColors.diffAddedTextLight,
    removedText: AppColors.diffRemovedTextLight,
    contextText: AppColors.diffContextTextLight,
    hunkHeaderBg: AppColors.diffHunkHeaderBgLight,
    hunkHeaderText: AppColors.diffHunkHeaderTextLight,
    lineNumberBg: AppColors.diffLineNumberBgLight,
    lineNumberText: AppColors.diffLineNumberTextLight,
    inlineAddedBg: AppColors.diffInlineAddedBgLight,
    inlineAddedText: AppColors.diffInlineAddedTextLight,
    inlineRemovedBg: AppColors.diffInlineRemovedBgLight,
    inlineRemovedText: AppColors.diffInlineRemovedTextLight,
    leadingSpaceDot: AppColors.diffLeadingSpaceDot,
  );

  /// Dark palette.
  static const DiffTheme dark = DiffTheme(
    addedBg: AppColors.diffAddedBgDark,
    removedBg: AppColors.diffRemovedBgDark,
    contextBg: Color(0x00000000),
    addedText: AppColors.diffAddedTextDark,
    removedText: AppColors.diffRemovedTextDark,
    contextText: AppColors.diffContextTextDark,
    hunkHeaderBg: AppColors.diffHunkHeaderBgDark,
    hunkHeaderText: AppColors.diffHunkHeaderTextDark,
    lineNumberBg: AppColors.diffLineNumberBgDark,
    lineNumberText: AppColors.diffLineNumberTextDark,
    inlineAddedBg: AppColors.diffInlineAddedBgDark,
    inlineAddedText: AppColors.diffInlineAddedTextDark,
    inlineRemovedBg: AppColors.diffInlineRemovedBgDark,
    inlineRemovedText: AppColors.diffInlineRemovedTextDark,
    leadingSpaceDot: AppColors.diffLeadingSpaceDotDark,
  );

  @override
  DiffTheme copyWith({
    Color? addedBg,
    Color? removedBg,
    Color? contextBg,
    Color? addedText,
    Color? removedText,
    Color? contextText,
    Color? hunkHeaderBg,
    Color? hunkHeaderText,
    Color? lineNumberBg,
    Color? lineNumberText,
    Color? inlineAddedBg,
    Color? inlineAddedText,
    Color? inlineRemovedBg,
    Color? inlineRemovedText,
    Color? leadingSpaceDot,
  }) {
    return DiffTheme(
      addedBg: addedBg ?? this.addedBg,
      removedBg: removedBg ?? this.removedBg,
      contextBg: contextBg ?? this.contextBg,
      addedText: addedText ?? this.addedText,
      removedText: removedText ?? this.removedText,
      contextText: contextText ?? this.contextText,
      hunkHeaderBg: hunkHeaderBg ?? this.hunkHeaderBg,
      hunkHeaderText: hunkHeaderText ?? this.hunkHeaderText,
      lineNumberBg: lineNumberBg ?? this.lineNumberBg,
      lineNumberText: lineNumberText ?? this.lineNumberText,
      inlineAddedBg: inlineAddedBg ?? this.inlineAddedBg,
      inlineAddedText: inlineAddedText ?? this.inlineAddedText,
      inlineRemovedBg: inlineRemovedBg ?? this.inlineRemovedBg,
      inlineRemovedText: inlineRemovedText ?? this.inlineRemovedText,
      leadingSpaceDot: leadingSpaceDot ?? this.leadingSpaceDot,
    );
  }

  @override
  DiffTheme lerp(ThemeExtension<DiffTheme>? other, double t) {
    if (other is! DiffTheme) return this;
    return DiffTheme(
      addedBg: Color.lerp(addedBg, other.addedBg, t)!,
      removedBg: Color.lerp(removedBg, other.removedBg, t)!,
      contextBg: Color.lerp(contextBg, other.contextBg, t)!,
      addedText: Color.lerp(addedText, other.addedText, t)!,
      removedText: Color.lerp(removedText, other.removedText, t)!,
      contextText: Color.lerp(contextText, other.contextText, t)!,
      hunkHeaderBg: Color.lerp(hunkHeaderBg, other.hunkHeaderBg, t)!,
      hunkHeaderText: Color.lerp(hunkHeaderText, other.hunkHeaderText, t)!,
      lineNumberBg: Color.lerp(lineNumberBg, other.lineNumberBg, t)!,
      lineNumberText: Color.lerp(lineNumberText, other.lineNumberText, t)!,
      inlineAddedBg: Color.lerp(inlineAddedBg, other.inlineAddedBg, t)!,
      inlineAddedText:
          Color.lerp(inlineAddedText, other.inlineAddedText, t)!,
      inlineRemovedBg:
          Color.lerp(inlineRemovedBg, other.inlineRemovedBg, t)!,
      inlineRemovedText:
          Color.lerp(inlineRemovedText, other.inlineRemovedText, t)!,
      leadingSpaceDot:
          Color.lerp(leadingSpaceDot, other.leadingSpaceDot, t)!,
    );
  }
}

/// Convenience extension — `context.diffTheme` resolves the diff
/// palette from the ambient [ThemeData], or [DiffTheme.light] when no
/// extension is registered.
extension DiffThemeContext on BuildContext {
  DiffTheme get diffTheme =>
      Theme.of(this).extension<DiffTheme>() ?? DiffTheme.light;
}

/// Bridge from the new extension palette to the legacy
/// `core/ui/diff/diff_types.DiffTheme` value type.
///
/// `DiffView.config.theme` still expects the legacy value type. This
/// extension lets call sites that already consume the new extension
/// pass `context.diffTheme.asLegacy()` directly without going through
/// the `ToolViewColors` bridge.
extension DiffThemeLegacyBridge on DiffTheme {
  /// Map this extension palette onto the legacy
  /// `core/ui/diff/diff_types.DiffTheme` value type.
  ui.DiffTheme asLegacy() {
    return ui.DiffTheme(
      addedBg: addedBg,
      addedText: addedText,
      removedBg: removedBg,
      removedText: removedText,
      contextBg: contextBg,
      contextText: contextText,
      lineNumberBg: lineNumberBg,
      lineNumberText: lineNumberText,
      hunkHeaderBg: hunkHeaderBg,
      hunkHeaderText: hunkHeaderText,
      inlineAddedBg: inlineAddedBg,
      inlineAddedText: inlineAddedText,
      inlineRemovedBg: inlineRemovedBg,
      inlineRemovedText: inlineRemovedText,
      leadingSpaceDot: leadingSpaceDot,
    );
  }
}
