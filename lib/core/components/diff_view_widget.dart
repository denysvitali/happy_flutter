import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/ui/diff/diff_types.dart' as ui;
import 'package:happy_flutter/core/ui/diff/diff_view.dart' as ui;

/// Diff view colors for theming.
///
/// Legacy color model retained for backward compatibility. Internally
/// mapped onto the canonical [ui.DiffTheme] used by `core/ui/diff`.
class DiffViewColors {

  DiffViewColors({
    required this.addedBg,
    required this.removedBg,
    required this.contextBg,
    required this.hunkHeaderBg,
    required this.lineNumberBg,
    required this.addedText,
    required this.removedText,
    required this.contextText,
    required this.hunkHeaderText,
    required this.lineNumberText,
    required this.inlineAddedBg,
    required this.inlineAddedText,
    required this.inlineRemovedBg,
    required this.inlineRemovedText,
    required this.leadingSpaceDot,
  });

  /// Light theme colors
  factory DiffViewColors.light() {
    return DiffViewColors(
      addedBg: AppColors.diffAddedBgLight,
      removedBg: AppColors.diffRemovedBgLight,
      contextBg: Colors.transparent,
      hunkHeaderBg: const Color(0xFFF0F0F0),
      lineNumberBg: const Color(0xFFF5F5F5),
      addedText: AppColors.diffAddedTextLight,
      removedText: AppColors.diffRemovedTextLight,
      contextText: const Color(0xFF24292F),
      hunkHeaderText: const Color(0xFF656D76),
      lineNumberText: const Color(0xFF6E7781),
      inlineAddedBg: const Color(0x4AC26B4D),
      inlineAddedText: AppColors.diffAddedTextLight,
      inlineRemovedBg: const Color(0xFFA39E4D),
      inlineRemovedText: AppColors.diffRemovedTextLight,
      leadingSpaceDot: const Color(0xFFD4D4D4),
    );
  }

  /// Dark theme colors
  factory DiffViewColors.dark() {
    return DiffViewColors(
      addedBg: AppColors.diffAddedBgDark,
      removedBg: AppColors.diffRemovedBgDark,
      contextBg: Colors.transparent,
      hunkHeaderBg: const Color(0xFF2D2D2D),
      lineNumberBg: const Color(0xFF252525),
      addedText: AppColors.diffAddedTextDark,
      removedText: AppColors.diffRemovedTextDark,
      contextText: const Color(0xFFC9D1D9),
      hunkHeaderText: const Color(0xFF8B949E),
      lineNumberText: const Color(0xFF6E7681),
      inlineAddedBg: const Color(0x4AC26B33),
      inlineAddedText: AppColors.diffAddedTextDark,
      inlineRemovedBg: const Color(0xFFA39E33),
      inlineRemovedText: AppColors.diffRemovedTextDark,
      leadingSpaceDot: const Color(0xFF4A4A4A),
    );
  }
  /// Background colors
  final Color addedBg;
  final Color removedBg;
  final Color contextBg;
  final Color hunkHeaderBg;
  final Color lineNumberBg;

  /// Text colors
  final Color addedText;
  final Color removedText;
  final Color contextText;
  final Color hunkHeaderText;
  final Color lineNumberText;

  /// Inline highlight colors
  final Color inlineAddedBg;
  final Color inlineAddedText;
  final Color inlineRemovedBg;
  final Color inlineRemovedText;

  /// Other colors
  final Color leadingSpaceDot;

  /// Map onto the canonical [ui.DiffTheme].
  ui.DiffTheme toDiffTheme() {
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

/// Configuration for diff view styling.
class DiffWidgetConfig {

  DiffWidgetConfig({
    this.fontSize = AppFontSize.md,
    this.lineHeight = AppFontSize.md * AppLineHeight.relaxed,
    this.linePaddingHorizontal = AppSpacing.sm,
    this.hunkHeaderPadding = AppSpacing.sm,
    this.lineNumberWidth = AppSpacing.xxxl + AppSpacing.sm,
    this.useMonospaceFont = true,
  });
  /// Font size for diff content
  final double fontSize;

  /// Line height for diff lines
  final double lineHeight;

  /// Horizontal padding for lines
  final double linePaddingHorizontal;

  /// Padding for hunk headers
  final double hunkHeaderPadding;

  /// Width for line number column
  final double lineNumberWidth;

  /// Whether to use monospace font
  final bool useMonospaceFont;
}

/// A Flutter widget for displaying git diffs with syntax highlighting.
///
/// Backward-compatible facade over the canonical `core/ui/diff` [ui.DiffView].
/// Translates the legacy [DiffViewColors] / [DiffWidgetConfig] inputs into the
/// canonical [ui.DiffTheme] / [ui.DiffViewConfig].
class DiffView extends StatelessWidget {

  const DiffView({
    required this.oldText, required this.newText, super.key,
    this.contextLines = 3,
    this.showLineNumbers = true,
    this.showPlusMinusSymbols = true,
    this.wrapLines = false,
    this.colors,
    this.config,
    this.oldTitle,
    this.newTitle,
    this.maxHeight,
    this.backgroundColor,
  });
  /// The old/original text
  final String oldText;

  /// The new/modified text
  final String newText;

  /// Number of context lines around changes (default: 3)
  final int contextLines;

  /// Whether to show line numbers (default: true)
  final bool showLineNumbers;

  /// Whether to show +/- symbols (default: true)
  final bool showPlusMinusSymbols;

  /// Whether to wrap long lines (default: false)
  final bool wrapLines;

  /// Custom colors for the diff view (null = use theme-based colors)
  final DiffViewColors? colors;

  /// Custom configuration for styling
  final DiffWidgetConfig? config;

  /// Title for the old file (optional)
  final String? oldTitle;

  /// Title for the new file (optional)
  final String? newTitle;

  /// Maximum height constraint
  final double? maxHeight;

  /// Background color override
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final resolvedColors = colors ??
        (Theme.of(context).brightness == Brightness.dark
            ? DiffViewColors.dark()
            : DiffViewColors.light());

    final diffView = ui.DiffView(
      oldText: oldText,
      newText: newText,
      oldTitle: oldTitle,
      newTitle: newTitle,
      config: ui.DiffViewConfig(
        contextLines: contextLines,
        showLineNumbers: showLineNumbers,
        showPlusMinusSymbols: showPlusMinusSymbols,
        wrapLines: wrapLines,
        theme: resolvedColors.toDiffTheme(),
      ),
    );

    final content = Container(
      constraints: maxHeight != null
          ? BoxConstraints(maxHeight: maxHeight!)
          : null,
      color: backgroundColor,
      child: diffView,
    );

    if (maxHeight == null) return content;
    return SingleChildScrollView(child: content);
  }
}
