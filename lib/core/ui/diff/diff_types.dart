/// Diff token for inline highlighting
library;

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
