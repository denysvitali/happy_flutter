/// Diff token for inline highlighting
library;
import 'package:flutter/material.dart';

import 'package:happy_flutter/core/theme/app_colors.dart';

class DiffToken {

  const DiffToken({
    required this.value,
    this.added = false,
    this.removed = false,
  });
  final String value;
  final bool added;
  final bool removed;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiffToken &&
        other.value == value &&
        other.added == added &&
        other.removed == removed;
  }

  @override
  int get hashCode => Object.hash(value, added, removed);
}

/// Diff line types
enum DiffLineType {
  add,
  remove,
  normal,
}

/// Single line in a diff
class DiffLine {

  const DiffLine({
    required this.type,
    required this.content,
    this.oldLineNumber,
    this.newLineNumber,
    this.tokens,
  });
  final DiffLineType type;
  final String content;
  final int? oldLineNumber;
  final int? newLineNumber;
  final List<DiffToken>? tokens;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiffLine &&
        other.type == type &&
        other.content == content &&
        other.oldLineNumber == oldLineNumber &&
        other.newLineNumber == newLineNumber &&
        other.tokens?.length == tokens?.length &&
        (tokens == null ||
            List.generate(
              tokens!.length,
              (i) => tokens![i] == other.tokens![i],
            ).every((e) => e));
  }

  @override
  int get hashCode => Object.hash(
    type,
    content,
    oldLineNumber,
    newLineNumber,
    tokens,
  );
}

/// Diff hunk containing related changes
class DiffHunk {

  const DiffHunk({
    required this.oldStart,
    required this.oldLines,
    required this.newStart,
    required this.newLines,
    required this.lines,
  });
  final int oldStart;
  final int oldLines;
  final int newStart;
  final int newLines;
  final List<DiffLine> lines;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiffHunk &&
        other.oldStart == oldStart &&
        other.oldLines == oldLines &&
        other.newStart == newStart &&
        other.newLines == newLines &&
        other.lines.length == lines.length &&
        List.generate(
          lines.length,
          (i) => lines[i] == other.lines[i],
        ).every((e) => e);
  }

  @override
  int get hashCode =>
      Object.hash(oldStart, oldLines, newStart, newLines, lines);
}

/// Complete diff result
class DiffResult {

  const DiffResult({
    required this.hunks,
    required this.stats,
  });
  final List<DiffHunk> hunks;
  final DiffStats stats;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiffResult &&
        other.hunks.length == hunks.length &&
        other.stats == stats &&
        List.generate(
          hunks.length,
          (i) => hunks[i] == other.hunks[i],
        ).every((e) => e);
  }

  @override
  int get hashCode => Object.hash(hunks, stats);
}

/// Diff statistics
class DiffStats {

  const DiffStats({
    required this.additions,
    required this.deletions,
  });
  final int additions;
  final int deletions;

  int get totalChanges => additions + deletions;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiffStats &&
        other.additions == additions &&
        other.deletions == deletions;
  }

  @override
  int get hashCode => Object.hash(additions, deletions);
}

/// Diff view configuration
class DiffViewConfig {

  const DiffViewConfig({
    this.contextLines = 3,
    this.showLineNumbers = true,
    this.showPlusMinusSymbols = true,
    this.showDiffStats = false,
    this.wrapLines = false,
    this.fontScaleX = 1,
    this.theme = const DiffTheme(),
  });
  final int contextLines;
  final bool showLineNumbers;
  final bool showPlusMinusSymbols;
  final bool showDiffStats;
  final bool wrapLines;
  final double fontScaleX;
  final DiffTheme theme;

  DiffViewConfig copyWith({
    int? contextLines,
    bool? showLineNumbers,
    bool? showPlusMinusSymbols,
    bool? showDiffStats,
    bool? wrapLines,
    double? fontScaleX,
    DiffTheme? theme,
  }) {
    return DiffViewConfig(
      contextLines: contextLines ?? this.contextLines,
      showLineNumbers: showLineNumbers ?? this.showLineNumbers,
      showPlusMinusSymbols: showPlusMinusSymbols ?? this.showPlusMinusSymbols,
      showDiffStats: showDiffStats ?? this.showDiffStats,
      wrapLines: wrapLines ?? this.wrapLines,
      fontScaleX: fontScaleX ?? this.fontScaleX,
      theme: theme ?? this.theme,
    );
  }
}

/// Diff theme colors
class DiffTheme {

  /// Light-mode defaults. All values are sourced from
  /// `AppColors.diff*Light` so the legacy default ctor matches the
  /// canonical palette produced by `DiffTheme.light` (the
  /// `ThemeExtension` in `core/theme/diff_theme.dart`).
  ///
  /// **Note:** no production caller uses the default ctor — every
  /// consumer routes through either `DiffViewColors.fromTheme(context
  /// .diffTheme)` (the legacy `DiffView` facade) or
  /// `context.diffTheme.asLegacy()` (the bridge added in batch 9).
  /// These defaults are kept for backward compatibility with the
  /// public constructor signature and so any future caller that
  /// constructs `DiffTheme()` without args gets consistent values.
  const DiffTheme({
    this.addedBg = AppColors.diffAddedBgLight,
    this.addedText = AppColors.diffAddedTextLight,
    this.removedBg = AppColors.diffRemovedBgLight,
    this.removedText = AppColors.diffRemovedTextLight,
    this.contextBg = Colors.transparent,
    this.contextText = AppColors.diffContextTextLight,
    this.lineNumberBg = AppColors.diffLineNumberBgLight,
    this.lineNumberText = AppColors.diffLineNumberTextLight,
    this.hunkHeaderBg = AppColors.diffHunkHeaderBgLight,
    this.hunkHeaderText = AppColors.diffHunkHeaderTextLight,
    this.inlineAddedBg = AppColors.diffInlineAddedBgLight,
    this.inlineAddedText = AppColors.diffInlineAddedTextLight,
    this.inlineRemovedBg = AppColors.diffInlineRemovedBgLight,
    this.inlineRemovedText = AppColors.diffInlineRemovedTextLight,
    this.leadingSpaceDot = AppColors.diffLeadingSpaceDot,
  });
  final Color addedBg;
  final Color addedText;
  final Color removedBg;
  final Color removedText;
  final Color contextBg;
  final Color contextText;
  final Color lineNumberBg;
  final Color lineNumberText;
  final Color hunkHeaderBg;
  final Color hunkHeaderText;
  final Color inlineAddedBg;
  final Color inlineAddedText;
  final Color inlineRemovedBg;
  final Color inlineRemovedText;
  final Color leadingSpaceDot;

  DiffTheme copyWith({
    Color? addedBg,
    Color? addedText,
    Color? removedBg,
    Color? removedText,
    Color? contextBg,
    Color? contextText,
    Color? lineNumberBg,
    Color? lineNumberText,
    Color? hunkHeaderBg,
    Color? hunkHeaderText,
    Color? inlineAddedBg,
    Color? inlineAddedText,
    Color? inlineRemovedBg,
    Color? inlineRemovedText,
    Color? leadingSpaceDot,
  }) {
    return DiffTheme(
      addedBg: addedBg ?? this.addedBg,
      addedText: addedText ?? this.addedText,
      removedBg: removedBg ?? this.removedBg,
      removedText: removedText ?? this.removedText,
      contextBg: contextBg ?? this.contextBg,
      contextText: contextText ?? this.contextText,
      lineNumberBg: lineNumberBg ?? this.lineNumberBg,
      lineNumberText: lineNumberText ?? this.lineNumberText,
      hunkHeaderBg: hunkHeaderBg ?? this.hunkHeaderBg,
      hunkHeaderText: hunkHeaderText ?? this.hunkHeaderText,
      inlineAddedBg: inlineAddedBg ?? this.inlineAddedBg,
      inlineAddedText: inlineAddedText ?? this.inlineAddedText,
      inlineRemovedBg: inlineRemovedBg ?? this.inlineRemovedBg,
      inlineRemovedText: inlineRemovedText ?? this.inlineRemovedText,
      leadingSpaceDot: leadingSpaceDot ?? this.leadingSpaceDot,
    );
  }
}
