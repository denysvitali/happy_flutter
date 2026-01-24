/// Diff token for inline highlighting
class DiffToken {
  final String value;
  final bool added;
  final bool removed;

  const DiffToken({
    required this.value,
    this.added = false,
    this.removed = false,
  });

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
  final DiffLineType type;
  final String content;
  final int? oldLineNumber;
  final int? newLineNumber;
  final List<DiffToken>? tokens;

  const DiffLine({
    required this.type,
    required this.content,
    this.oldLineNumber,
    this.newLineNumber,
    this.tokens,
  });

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
  int get hashCode => Object.hash(type, content, oldLineNumber, newLineNumber, tokens);
}

/// Diff hunk containing related changes
class DiffHunk {
  final int oldStart;
  final int oldLines;
  final int newStart;
  final int newLines;
  final List<DiffLine> lines;

  const DiffHunk({
    required this.oldStart,
    required this.oldLines,
    required this.newStart,
    required this.newLines,
    required this.lines,
  });

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
  final List<DiffHunk> hunks;
  final DiffStats stats;

  const DiffResult({
    required this.hunks,
    required this.stats,
  });

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
  final int additions;
  final int deletions;

  const DiffStats({
    required this.additions,
    required this.deletions,
  });

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
  final int contextLines;
  final bool showLineNumbers;
  final bool showPlusMinusSymbols;
  final bool showDiffStats;
  final bool wrapLines;
  final double fontScaleX;
  final DiffTheme theme;

  const DiffViewConfig({
    this.contextLines = 3,
    this.showLineNumbers = true,
    this.showPlusMinusSymbols = true,
    this.showDiffStats = false,
    this.wrapLines = false,
    this.fontScaleX = 1,
    this.theme = const DiffTheme(),
  });

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

  const DiffTheme({
    this.addedBg = Color(0xFFDaf8e5),
    this.addedText = Color(0xFF1a7f37),
    this.removedBg = Color(0xFFffebe9),
    this.removedText = Color(0xFFcf222e),
    this.contextBg = Colors.transparent,
    this.contextText = Color(0xFF1f2328),
    this.lineNumberBg = Color(0xFFF6F8FA),
    this.lineNumberText = Color(0xFF656d76),
    this.hunkHeaderBg = Color(0xFFf6f8fa),
    this.hunkHeaderText = Color(0xFF656d76),
    this.inlineAddedBg = Color(0xFFdaf8e5),
    this.inlineAddedText = Color(0xFF1a7f37),
    this.inlineRemovedBg = Color(0xFFffebe9),
    this.inlineRemovedText = Color(0xFFcf222e),
    this.leadingSpaceDot = Color(0xFFd0d7de),
  });

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
