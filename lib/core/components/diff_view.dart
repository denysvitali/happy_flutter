import 'dart:math' as math;

/// Represents a single token in an inline diff for highlighting changes within a line.
class DiffToken {
  /// The text content of this token
  final String value;

  /// Whether this token was added in the new text
  final bool added;

  /// Whether this token was removed from the old text
  final bool removed;

  DiffToken({
    required this.value,
    this.added = false,
    this.removed = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DiffToken) return false;
    return other.value == value &&
        other.added == added &&
        other.removed == removed;
  }

  @override
  int get hashCode => Object.hash(value, added, removed);
}

/// Represents a single line in the diff output.
class DiffLine {
  /// Type of line: add, remove, or context (normal)
  final DiffLineType type;

  /// The content of the line
  final String content;

  /// Line number in the old file (for context and removals)
  final int? oldLineNumber;

  /// Line number in the new file (for context and additions)
  final int? newLineNumber;

  /// Optional tokens for inline highlighting within this line
  final List<DiffToken>? tokens;

  DiffLine({
    required this.type,
    required this.content,
    this.oldLineNumber,
    this.newLineNumber,
    this.tokens,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DiffLine) return false;
    return other.type == type &&
        other.content == content &&
        other.oldLineNumber == oldLineNumber &&
        other.newLineNumber == newLineNumber;
  }

  @override
  int get hashCode => Object.hash(type, content, oldLineNumber, newLineNumber);
}

/// Type of diff line.
enum DiffLineType {
  add,
  remove,
  normal,
}

/// Represents a hunk (a contiguous section of changes) in the diff.
class DiffHunk {
  /// Starting line number in the old file
  final int oldStart;

  /// Number of lines in the old file for this hunk
  final int oldLines;

  /// Starting line number in the new file
  final int newStart;

  /// Number of lines in the new file for this hunk
  final int newLines;

  /// The lines in this hunk
  final List<DiffLine> lines;

  DiffHunk({
    required this.oldStart,
    required this.oldLines,
    required this.newStart,
    required this.newLines,
    required this.lines,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DiffHunk) return false;
    return other.oldStart == oldStart &&
        other.oldLines == oldLines &&
        other.newStart == newStart &&
        other.newLines == newLines;
  }

  @override
  int get hashCode =>
      Object.hash(oldStart, oldLines, newStart, newLines);
}

/// The result of parsing a diff.
class DiffResult {
  /// All hunks in the diff
  final List<DiffHunk> hunks;

  /// Statistics about the diff
  final DiffStats stats;

  DiffResult({
    required this.hunks,
    required this.stats,
  });
}

/// Statistics about a diff.
class DiffStats {
  /// Number of lines added
  final int additions;

  /// Number of lines removed
  final int deletions;

  DiffStats({
    required this.additions,
    required this.deletions,
  });
}

/// Parser for unified diff format.
///
/// Parses git diff output and similar unified diff formats into structured data.
class DiffParser {
  /// Regular expression for hunk header lines.
  ///
  /// Matches: @@ -oldStart,oldLines +newStart,newLines @@
  static final _hunkHeaderRegex = RegExp(r'^@@\s+-(\d+),?(\d*)\s+\+(\d+),?(\d*)\s+@@');

  /// Regular expression for diff file header.
  ///
  /// Matches: a/b "filename" or similar file header lines
  static final _fileHeaderRegex = RegExp(r'^[abciwdbm]\s+(.+)');

  /// Regular expression for new/old mode lines.
  static final _modeRegex = RegExp(r'^(new|old)mode\s+(\d+)');

  /// Regular expression for similarity index lines (rename/copy).
  static final _similarityRegex = RegExp(r'^similarity index\s+(\d+)%');

  /// Parse unified diff format string into structured data.
  ///
  /// [diffText] - The unified diff text to parse
  /// Returns a [DiffResult] containing hunks and statistics
  static DiffResult parse(String diffText) {
    final hunks = <DiffHunk>[];
    int additions = 0;
    int deletions = 0;
    int oldLineNum = 0;
    int newLineNum = 0;

    final lines = diffText.split('\n');

    // Skip file headers and find hunk headers
    int i = 0;

    // Skip to first hunk header
    while (i < lines.length && !_hunkHeaderRegex.hasMatch(lines[i])) {
      i++;
    }

    while (i < lines.length) {
      final line = lines[i];

      final hunkMatch = _hunkHeaderRegex.firstMatch(line);
      if (hunkMatch != null) {
        final hunkOldStart = int.parse(hunkMatch.group(1)!);
        final hunkOldLines = hunkMatch.group(2)!.isEmpty ? 1 : int.parse(hunkMatch.group(2)!);
        final hunkNewStart = int.parse(hunkMatch.group(3)!);
        final hunkNewLines = hunkMatch.group(4)!.isEmpty ? 1 : int.parse(hunkMatch.group(4)!);

        oldLineNum = hunkOldStart;
        newLineNum = hunkNewStart;

        final hunkLines = <DiffLine>[];
        i++;

        // Parse lines in this hunk
        while (i < lines.length) {
          final diffLine = lines[i];

          // Check for end of hunk (next hunk header or file header or end)
          if (diffLine.isEmpty ||
              diffLine.startsWith('@@') ||
              _fileHeaderRegex.hasMatch(diffLine) ||
              _modeRegex.hasMatch(diffLine) ||
              _similarityRegex.hasMatch(diffLine)) {
            break;
          }

          if (diffLine.startsWith('+') && !diffLine.startsWith('+++')) {
            hunkLines.add(DiffLine(
              type: DiffLineType.add,
              content: diffLine.substring(1),
              newLineNumber: newLineNum++,
            ));
            additions++;
          } else if (diffLine.startsWith('-') && !diffLine.startsWith('---')) {
            hunkLines.add(DiffLine(
              type: DiffLineType.remove,
              content: diffLine.substring(1),
              oldLineNumber: oldLineNum++,
            ));
            deletions++;
          } else if (diffLine.startsWith(' ') || diffLine.isEmpty) {
            // Context line
            final content = diffLine.startsWith(' ') ? diffLine.substring(1) : diffLine;
            hunkLines.add(DiffLine(
              type: DiffLineType.normal,
              content: content,
              oldLineNumber: oldLineNum++,
              newLineNumber: newLineNum++,
            ));
          } else if (diffLine.startsWith('\\')) {
            // No newline at end of file - skip
          }

          i++;
        }

        if (hunkLines.isNotEmpty) {
          hunks.add(DiffHunk(
            oldStart: hunkOldStart,
            oldLines: hunkOldLines,
            newStart: hunkNewStart,
            newLines: hunkNewLines,
            lines: hunkLines,
          ));
        }
      } else {
        i++;
      }
    }

    return DiffResult(
      hunks: hunks,
      stats: DiffStats(
        additions: additions,
        deletions: deletions,
      ),
    );
  }

  /// Parse git diff for two strings.
  ///
  /// [oldText] - Original text
  /// [newText] - New text to compare against
  /// [contextLines] - Number of context lines around changes (default 3)
  /// Returns a [DiffResult] containing hunks and statistics
  static DiffResult compareStrings(
    String oldText,
    String newText, {
    int contextLines = 3,
  }) {
    // Use word-level diff algorithm for inline highlighting
    final oldLines = oldText.split('\n');
    final newLines = newText.split('\n');

    return _calculateUnifiedDiff(oldLines, newLines, contextLines);
  }

  /// Calculate unified diff with inline highlighting between two lists of lines.
  static DiffResult _calculateUnifiedDiff(
    List<String> oldLines,
    List<String> newLines,
    int contextLines,
  ) {
    final allLines = <DiffLine>[];
    int oldLineNum = 1;
    int newLineNum = 1;
    int additions = 0;
    int deletions = 0;

    // Find matching and non-matching lines
    final pendingRemovals = <_LineMatch>[];
    final changes = <_Change>[];

    for (int i = 0; i < oldLines.length; i++) {
      changes.add(_Change(line: oldLines[i], oldIndex: i, isRemoval: true));
    }
    for (int i = 0; i < newLines.length; i++) {
      changes.add(_Change(line: newLines[i], newIndex: i, isRemoval: false));
    }

    // Simple line-by-line comparison with context
    int oldIdx = 0;
    int newIdx = 0;

    while (oldIdx < oldLines.length || newIdx < newLines.length) {
      final oldLine = oldIdx < oldLines.length ? oldLines[oldIdx] : null;
      final newLine = newIdx < newLines.length ? newLines[newIdx] : null;

      if (oldLine == null) {
        // Only new lines remain
        allLines.add(DiffLine(
          type: DiffLineType.add,
          content: newLine!,
          newLineNumber: newLineNum++,
        ));
        additions++;
        newIdx++;
      } else if (newLine == null) {
        // Only old lines remain
        allLines.add(DiffLine(
          type: DiffLineType.remove,
          content: oldLine,
          oldLineNumber: oldLineNum++,
        ));
        deletions++;
        oldIdx++;
      } else if (oldLine == newLine) {
        // Same line in both
        allLines.add(DiffLine(
          type: DiffLineType.normal,
          content: oldLine,
          oldLineNumber: oldLineNum++,
          newLineNumber: newLineNum++,
        ));
        oldIdx++;
        newIdx++;
      } else {
        // Lines differ - try to find matching lines nearby
        final bestOldMatch = _findBestMatch(newLine, oldLines, oldIdx);
        final bestNewMatch = _findBestMatch(oldLine, newLines, newIdx);

        if (bestOldMatch != -1 && (bestNewMatch == -1 || (bestOldMatch - oldIdx) <= (newIdx - bestNewMatch))) {
          // Found a better match in old lines
          // Add context lines before the change
          for (int j = math.max(0, oldIdx - contextLines); j < oldIdx; j++) {
            allLines.add(DiffLine(
              type: DiffLineType.normal,
              content: oldLines[j],
              oldLineNumber: oldLineNum++,
              newLineNumber: newLineNum++,
            ));
          }

          // Add removed lines
          for (int j = oldIdx; j <= bestOldMatch; j++) {
            final tokens = _calculateInlineDiff(oldLines[j], newLines[newIdx]);
            allLines.add(DiffLine(
              type: DiffLineType.remove,
              content: oldLines[j],
              oldLineNumber: oldLineNum++,
              tokens: tokens.where((t) => !t.added).toList(),
            ));
            deletions++;
          }

          // Add added lines
          for (int j = newIdx; j <= bestNewMatch; j++) {
            final tokens = _calculateInlineDiff(oldLines[bestOldMatch], newLines[j]);
            allLines.add(DiffLine(
              type: DiffLineType.add,
              content: newLines[j],
              newLineNumber: newLineNum++,
              tokens: tokens.where((t) => !t.removed).toList(),
            ));
            additions++;
          }

          oldIdx = bestOldMatch + 1;
          newIdx = bestNewMatch + 1;
        } else {
          // No good match - simple replace
          final tokens = _calculateInlineDiff(oldLine, newLine);
          allLines.add(DiffLine(
            type: DiffLineType.remove,
            content: oldLine,
            oldLineNumber: oldLineNum++,
            tokens: tokens.where((t) => !t.added).toList(),
          ));
          deletions++;

          allLines.add(DiffLine(
            type: DiffLineType.add,
            content: newLine,
            newLineNumber: newLineNum++,
            tokens: tokens.where((t) => !t.removed).toList(),
          ));
          additions++;

          oldIdx++;
          newIdx++;
        }
      }
    }

    // Create hunks with context
    final hunks = _createHunks(allLines, contextLines);

    return DiffResult(
      hunks: hunks,
      stats: DiffStats(
        additions: additions,
        deletions: deletions,
      ),
    );
  }

  /// Find best matching line from candidates.
  static int _findBestMatch(
    String target,
    List<String> candidates,
    int startIndex,
  ) {
    if (startIndex >= candidates.length) return -1;

    int bestIndex = -1;
    double bestScore = 0;
    const threshold = 0.5;

    for (int i = startIndex; i < candidates.length; i++) {
      final score = _calculateSimilarity(target, candidates[i]);
      if (score > bestScore && score > threshold) {
        bestScore = score;
        bestIndex = i;
      }
    }

    return bestIndex;
  }

  /// Calculate similarity between two strings (0-1).
  static double _calculateSimilarity(String str1, String str2) {
    if (str1 == str2) return 1.0;
    if (str1.isEmpty || str2.isEmpty) return 0.0;

    final chars1 = str1.split('');
    final chars2 = str2.split('');
    final maxLen = math.max(chars1.length, chars2.length);

    if (maxLen == 0) return 1.0;

    int matches = 0;
    final minLen = math.min(chars1.length, chars2.length);

    for (int i = 0; i < minLen; i++) {
      if (chars1[i] == chars2[i]) matches++;
    }

    return matches / maxLen;
  }

  /// Calculate inline diff tokens between two lines.
  static List<DiffToken> _calculateInlineDiff(String oldLine, String newLine) {
    final oldWords = _splitIntoWords(oldLine);
    final newWords = _splitIntoWords(newLine);

    return _wordDiff(oldWords, newWords);
  }

  /// Split a string into words while preserving spaces.
  static List<String> _splitIntoWords(String text) {
    final words = <String>[];
    final buffer = StringBuffer();
    var inWhitespace = true;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final isWhitespace = char == ' ' || char == '\t';

      if (isWhitespace && !inWhitespace) {
        words.add(buffer.toString());
        buffer.clear();
        inWhitespace = true;
      }

      if (!isWhitespace || buffer.isNotEmpty) {
        buffer.write(char);
      }

      if (!isWhitespace) {
        inWhitespace = false;
      }
    }

    if (buffer.isNotEmpty) {
      words.add(buffer.toString());
    }

    return words;
  }

  /// Perform word-level diff.
  static List<DiffToken> _wordDiff(List<String> oldWords, List<String> newWords) {
    final tokens = <DiffToken>[];

    // Simple LCS-based diff
    final lcs = _computeLCS(oldWords, newWords);

    int oldIdx = 0;
    int newIdx = 0;
    int lcsIdx = 0;

    while (oldIdx < oldWords.length || newIdx < newWords.length) {
      if (lcsIdx < lcs.length && oldIdx < oldWords.length && newIdx < newWords.length) {
        // Check if we're at a common subsequence element
        final lcsElement = lcs[lcsIdx];
        final oldLcsIdx = oldWords.indexOf(lcsElement, oldIdx);
        final newLcsIdx = newWords.indexOf(lcsElement, newIdx);

        if (oldLcsIdx == newLcsIdx && oldLcsIdx != -1 && newLcsIdx != -1) {
          // Add removed words
          for (int i = oldIdx; i < oldLcsIdx; i++) {
            tokens.add(DiffToken(value: oldWords[i], removed: true));
          }
          // Add added words
          for (int i = newIdx; i < newLcsIdx; i++) {
            tokens.add(DiffToken(value: newWords[i], added: true));
          }
          // Add common word
          tokens.add(DiffToken(value: lcsElement));
          oldIdx = oldLcsIdx + 1;
          newIdx = newLcsIdx + 1;
          lcsIdx++;
        } else if (oldLcsIdx != -1 && (newLcsIdx == -1 || oldLcsIdx <= newLcsIdx)) {
          // Add removed words up to LCS match
          for (int i = oldIdx; i < oldLcsIdx; i++) {
            tokens.add(DiffToken(value: oldWords[i], removed: true));
          }
          oldIdx = oldLcsIdx;
        } else if (newLcsIdx != -1) {
          // Add added words up to LCS match
          for (int i = newIdx; i < newLcsIdx; i++) {
            tokens.add(DiffToken(value: newWords[i], added: true));
          }
          newIdx = newLcsIdx;
        } else {
          break;
        }
      } else {
        // Add remaining words
        for (int i = oldIdx; i < oldWords.length; i++) {
          tokens.add(DiffToken(value: oldWords[i], removed: true));
        }
        for (int i = newIdx; i < newWords.length; i++) {
          tokens.add(DiffToken(value: newWords[i], added: true));
        }
        break;
      }
    }

    // Merge consecutive tokens of the same type
    final merged = <DiffToken>[];
    String? currentBuffer;
    bool? currentAdded;
    bool? currentRemoved;

    for (final token in tokens) {
      if (currentBuffer == null) {
        currentBuffer = token.value;
        currentAdded = token.added;
        currentRemoved = token.removed;
      } else if (token.added == currentAdded && token.removed == currentRemoved) {
        currentBuffer += token.value;
      } else {
        merged.add(DiffToken(
          value: currentBuffer!,
          added: currentAdded ?? false,
          removed: currentRemoved ?? false,
        ));
        currentBuffer = token.value;
        currentAdded = token.added;
        currentRemoved = token.removed;
      }
    }

    if (currentBuffer != null) {
      merged.add(DiffToken(
        value: currentBuffer,
        added: currentAdded ?? false,
        removed: currentRemoved ?? false,
      ));
    }

    return merged;
  }

  /// Compute Longest Common Subsequence.
  static List<String> _computeLCS(List<String> a, List<String> b) {
    final m = a.length;
    final n = b.length;

    // Create DP table
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = math.max(dp[i - 1][j], dp[i][j - 1]);
        }
      }
    }

    // Backtrack to find LCS
    final lcs = <String>[];
    int i = m;
    int j = n;

    while (i > 0 && j > 0) {
      if (a[i - 1] == b[j - 1]) {
        lcs.insert(0, a[i - 1]);
        i--;
        j--;
      } else if (dp[i - 1][j] > dp[i][j - 1]) {
        i--;
      } else {
        j--;
      }
    }

    return lcs;
  }

  /// Create hunks with context lines from all diff lines.
  static List<DiffHunk> _createHunks(List<DiffLine> lines, int contextLines) {
    final hunks = <DiffHunk>[];

    // Find all changed lines (additions and removals)
    final changes = lines
        .asMap()
        .entries
        .where((e) => e.value.type != DiffLineType.normal)
        .map((e) => MapEntry(e.key, e.value))
        .toList();

    if (changes.isEmpty) {
      // No changes, return single hunk with all lines if they exist
      if (lines.isNotEmpty) {
        hunks.add(DiffHunk(
          oldStart: 1,
          oldLines: lines.where((l) => l.oldLineNumber != null).length,
          newStart: 1,
          newLines: lines.where((l) => l.newLineNumber != null).length,
          lines: lines,
        ));
      }
      return hunks;
    }

    // Group changes into hunks with context
    List<DiffLine> currentHunk = [];
    int lastIncludedIndex = -1;

    for (int i = 0; i < changes.length; i++) {
      final changeIndex = changes[i].key;

      final startContext = math.max(0, changeIndex - contextLines);
      final endContext = math.min(lines.length - 1, changeIndex + contextLines);

      // Add lines from last included index to current hunk
      for (int j = math.max(lastIncludedIndex + 1, startContext);
          j <= endContext;
          j++) {
        currentHunk.add(lines[j]);
      }
      lastIncludedIndex = endContext;

      // Check if we should start a new hunk
      final nextChange = i < changes.length - 1 ? changes[i + 1].key : null;
      if (nextChange != null && nextChange - endContext > contextLines * 2) {
        // Finish current hunk
        if (currentHunk.isNotEmpty) {
          final firstLine = currentHunk.first;
          hunks.add(DiffHunk(
            oldStart: firstLine.oldLineNumber ?? 1,
            oldLines: currentHunk.where((l) => l.oldLineNumber != null).length,
            newStart: firstLine.newLineNumber ?? 1,
            newLines: currentHunk.where((l) => l.newLineNumber != null).length,
            lines: currentHunk,
          ));
        }
        currentHunk = [];
      }
    }

    // Add remaining lines to last hunk
    if (currentHunk.isNotEmpty) {
      final firstLine = currentHunk.first;
      hunks.add(DiffHunk(
        oldStart: firstLine.oldLineNumber ?? 1,
        oldLines: currentHunk.where((l) => l.oldLineNumber != null).length,
        newStart: firstLine.newLineNumber ?? 1,
        newLines: currentHunk.where((l) => l.newLineNumber != null).length,
        lines: currentHunk,
      ));
    }

    return hunks;
  }
}

/// Internal class for tracking line matches.
class _LineMatch {
  final String line;
  final int lineNum;
  final int index;

  _LineMatch({required this.line, required this.lineNum, required this.index});
}

/// Internal class for tracking changes.
class _Change {
  final String line;
  final int? oldIndex;
  final int? newIndex;
  final bool isRemoval;

  _Change({
    required this.line,
    this.oldIndex,
    this.newIndex,
    required this.isRemoval,
  });
}
