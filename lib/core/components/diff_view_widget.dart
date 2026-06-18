import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/theme/diff_theme.dart';
import 'package:happy_flutter/core/ui/diff/diff_types.dart' as ui;
import 'package:happy_flutter/core/ui/diff/diff_view.dart' as ui;

/// Diff view colors for theming.
///
/// Legacy color model retained for backward compatibility. Internally
/// mapped onto the canonical [ui.DiffTheme] used by `core/ui/diff`.
///
/// **Deprecated** — the static `DiffViewColors.light()` /
/// `DiffViewColors.dark()` factories were the source of the prior
/// olive "inline removed" bug. New code should construct a value
/// from a [DiffTheme] extension lookup and call [toDiffTheme], e.g.:
///
/// ```dart
/// final colors = DiffViewColors.fromTheme(context.diffTheme);
/// colors.toDiffTheme();
/// ```
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

  /// Adapt a [DiffTheme] (the canonical ThemeExtension palette) into
  /// the legacy [DiffViewColors] value type.
  factory DiffViewColors.fromTheme(DiffTheme theme) {
    return DiffViewColors(
      addedBg: theme.addedBg,
      removedBg: theme.removedBg,
      contextBg: theme.contextBg,
      hunkHeaderBg: theme.hunkHeaderBg,
      lineNumberBg: theme.lineNumberBg,
      addedText: theme.addedText,
      removedText: theme.removedText,
      contextText: theme.contextText,
      hunkHeaderText: theme.hunkHeaderText,
      lineNumberText: theme.lineNumberText,
      inlineAddedBg: theme.inlineAddedBg,
      inlineAddedText: theme.inlineAddedText,
      inlineRemovedBg: theme.inlineRemovedBg,
      inlineRemovedText: theme.inlineRemovedText,
      leadingSpaceDot: theme.leadingSpaceDot,
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
    // Resolve the diff palette from the ambient DiffTheme extension.
    // No more inlined hex literals (the prior version of this fallback
    // hardcoded `#A39E4D` olive for inline-removed, which read as
    // "modified" instead of "removed" in Edit and MultiEdit tool
    // outputs — see the regression test in
    // test/core/theme/diff_theme_test.dart).
    final resolvedColors = colors ?? DiffViewColors.fromTheme(context.diffTheme);

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
