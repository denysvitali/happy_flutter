import 'diff_types.dart';

/// Calculate unified diff between two texts
DiffResult calculateUnifiedDiff(
  String oldText,
  String newText, {
  int contextLines = 3,
}) {
  // Split texts into lines
  final oldLines = oldText.split('\n');
  final newLines = newText.split('\n');

  // Get line-level changes
  final lineChanges = _diffLines(oldLines, newLines);

  // Convert to internal format
  final allLines = <DiffLine>[];
  var oldLineNum = 1;
  var newLineNum = 1;
  var additions = 0;
  var deletions = 0;

  // First pass: identify all lines and track pending removals
  final pendingRemovals = <_PendingRemoval>[];

  for (final change in lineChanges) {
    final lines = change.lines;

    for (final line in lines) {
      if (change.removed) {
        pendingRemovals.add(_PendingRemoval(
          line: line,
          lineNum: oldLineNum,
          index: allLines.length,
        ));
        allLines.add(DiffLine(
          type: DiffLineType.remove,
          content: line,
          oldLineNumber: oldLineNum++,
        ));
        deletions++;
      } else if (change.added) {
        var paired = false;

        if (pendingRemovals.isNotEmpty) {
          // Find best matching removal
          final removalIndex = _findBestMatch(line, pendingRemovals.map((r) => r.line).toList());
          if (removalIndex != -1) {
            final removal = pendingRemovals[removalIndex];
            pendingRemovals.removeAt(removalIndex);

            // Calculate inline diff
            final tokens = _calculateInlineDiff(removal.line, line);

            // Update the removal line with tokens (removed parts)
            allLines[removal.index] = DiffLine(
              type: DiffLineType.remove,
              content: removal.line,
              oldLineNumber: removal.lineNum,
              tokens: tokens.where((t) => !t.added).toList(),
            );

            // Add the addition line with tokens (added parts)
            allLines.add(DiffLine(
              type: DiffLineType.add,
              content: line,
              newLineNumber: newLineNum++,
              tokens: tokens.where((t) => !t.removed).toList(),
            ));

            paired = true;
          }
        }

        if (!paired) {
          allLines.add(DiffLine(
            type: DiffLineType.add,
            content: line,
            newLineNumber: newLineNum++,
          ));
        }
        additions++;
      } else {
        // Context line
        allLines.add(DiffLine(
          type: DiffLineType.normal,
          content: line,
          oldLineNumber: oldLineNum++,
          newLineNumber: newLineNum++,
        ));
      }
    }
  }

  // Create hunks with context
  final hunks = _createHunks(allLines, contextLines);

  return DiffResult(
    hunks: hunks,
    stats: DiffStats(additions: additions, deletions: deletions),
  );
}

/// Internal class to track pending removals
class _PendingRemoval {
  final String line;
  final int lineNum;
  final int index;

  _PendingRemoval({
    required this.line,
    required this.lineNum,
    required this.index,
  });
}

/// Simple line-level diff result
class _LineChange {
  final List<String> lines;
  final bool added;
  final bool removed;

  _LineChange({
    required this.lines,
    required this.added,
    required this.removed,
  });
}

/// Calculate line-level differences (simplified algorithm)
List<_LineChange> _diffLines(List<String> oldLines, List<String> newLines) {
  final changes = <_LineChange>[];
  var i = 0;
  var j = 0;

  while (i < oldLines.length || j < newLines.length) {
    if (i >= oldLines.length) {
      // Remaining lines are additions
      changes.add(_LineChange(
        lines: newLines.sublist(j),
        added: true,
        removed: false,
      ));
      break;
    }

    if (j >= newLines.length) {
      // Remaining lines are removals
      changes.add(_LineChange(
        lines: oldLines.sublist(i),
        added: false,
        removed: true,
      ));
      break;
    }

    if (oldLines[i] == newLines[j]) {
      // Unchanged line
      changes.add(_LineChange(
        lines: [oldLines[i]],
        added: false,
        removed: false,
      ));
      i++;
      j++;
    } else {
      // Find best match
      final matchForward = _findBestMatchForward(newLines, j, oldLines[i]);
      final matchBackward = _findBestMatchBackward(oldLines, i, newLines[j]);

      if (matchForward != -1 && (matchBackward == -1 || matchForward <= matchBackward)) {
        // Lines were added
        changes.add(_LineChange(
          lines: newLines.sublist(j, matchForward),
          added: true,
          removed: false,
        ));
        j = matchForward;
      } else if (matchBackward != -1) {
        // Lines were removed
        changes.add(_LineChange(
          lines: oldLines.sublist(i, matchBackward),
          added: false,
          removed: true,
        ));
        i = matchBackward;
      } else {
        // Modified line
        changes.add(_LineChange(
          lines: [oldLines[i]],
          added: false,
          removed: true,
        ));
        changes.add(_LineChange(
          lines: [newLines[j]],
          added: true,
          removed: false,
        ));
        i++;
        j++;
      }
    }
  }

  return changes;
}

/// Find best matching line forward in newLines
int _findBestMatchForward(
  List<String> newLines,
  int start,
  String target,
) {
  for (var i = start; i < newLines.length; i++) {
    if (_calculateSimilarity(target, newLines[i]) > 0.3) {
      return i;
    }
  }
  return -1;
}

/// Find best matching line backward in oldLines
int _findBestMatchBackward(
  List<String> oldLines,
  int start,
  String target,
) {
  for (var i = start; i < oldLines.length; i++) {
    if (_calculateSimilarity(target, oldLines[i]) > 0.3) {
      return i;
    }
  }
  return -1;
}

/// Calculate inline diff between two lines
List<DiffToken> _calculateInlineDiff(String oldLine, String newLine) {
  // Simple word-level diff
  final oldWords = oldLine.split(RegExp(r'(\s+)'));
  final newWords = newLine.split(RegExp(r'(\s+)'));

  final result = <DiffToken>[];

  _diffWords(oldWords, newWords, (type, word) {
    switch (type) {
      case 'same':
        result.add(DiffToken(value: word));
        break;
      case 'remove':
        result.add(DiffToken(value: word, removed: true));
        break;
      case 'add':
        result.add(DiffToken(value: word, added: true));
        break;
    }
  });

  return result;
}

/// Word-level diff (simplified)
void _diffWords(
  List<String> oldWords,
  List<String> newWords,
  void Function(String type, String word) callback,
) {
  var i = 0;
  var j = 0;

  while (i < oldWords.length || j < newWords.length) {
    if (i >= oldWords.length) {
      callback('add', newWords[j++]);
      continue;
    }

    if (j >= newWords.length) {
      callback('remove', oldWords[i++]);
      continue;
    }

    if (oldWords[i] == newWords[j]) {
      callback('same', oldWords[i]);
      i++;
      j++;
    } else if (oldWords[i].trim().isEmpty && newWords[j].trim().isEmpty) {
      // Both are whitespace
      callback('same', newWords[j]);
      i++;
      j++;
    } else {
      // Try to find matches
      var foundI = -1;
      var foundJ = -1;

      for (var k = 1; k < 5; k++) {
        if (foundI == -1 && i + k < oldWords.length &&
            newWords.any((w) => _calculateSimilarity(oldWords[i + k], w) > 0.5)) {
          foundI = i + k;
        }
        if (foundJ == -1 && j + k < newWords.length &&
            oldWords.any((w) => _calculateSimilarity(newWords[j + k], w) > 0.5)) {
          foundJ = j + k;
        }
      }

      if (foundI != -1 && (foundJ == -1 || foundI - i <= foundJ - j)) {
        // Remove words
        while (i < foundI) {
          callback('remove', oldWords[i++]);
        }
      } else if (foundJ != -1) {
        // Add words
        while (j < foundJ) {
          callback('add', newWords[j++]);
        }
      } else {
        // Just replace
        callback('remove', oldWords[i]);
        callback('add', newWords[j]);
        i++;
        j++;
      }
    }
  }
}

/// Find best matching line from candidates
int _findBestMatch(String target, List<String> candidates) {
  if (candidates.isEmpty) return -1;

  var bestIndex = -1;
  var bestScore = 0.0;

  for (var i = 0; i < candidates.length; i++) {
    final score = _calculateSimilarity(target, candidates[i]);
    if (score > bestScore && score > 0.3) {
      bestScore = score;
      bestIndex = i;
    }
  }

  return bestIndex;
}

/// Calculate similarity between two strings (0-1)
double _calculateSimilarity(String str1, String str2) {
  if (str1 == str2) return 1.0;
  if (str1.isEmpty || str2.isEmpty) return 0.0;

  final chars1 = str1.split('');
  final chars2 = str2.split('');
  final maxLen = chars1.length > chars2.length ? chars1.length : chars2.length;

  if (maxLen == 0) return 1.0;

  var matches = 0;
  final minLen = chars1.length < chars2.length ? chars1.length : chars2.length;

  for (var i = 0; i < minLen; i++) {
    if (chars1[i] == chars2[i]) matches++;
  }

  // Check for common substrings
  final commonSubstrings = _findCommonSubstrings(str1, str2);
  final substringBonus = commonSubstrings.isNotEmpty
      ? commonSubstrings.map((s) => s.length).reduce((a, b) => a + b) / maxLen
      : 0.0;

  return ((matches / maxLen) + substringBonus) / 2;
}

/// Find common substrings between two strings
List<String> _findCommonSubstrings(String str1, String str2) {
  final minLength = 3;
  final substrings = <String>[];

  for (var len = str1.length < str2.length ? str1.length : str2.length;
      len >= minLength;
      len--) {
    for (var i = 0; i <= str1.length - len; i++) {
      final sub = str1.substring(i, i + len);
      if (str2.contains(sub) && !substrings.any((s) => s.contains(sub))) {
        substrings.add(sub);
      }
    }
  }

  return substrings;
}

/// Create hunks with context lines
List<DiffHunk> _createHunks(List<DiffLine> lines, int contextLines) {
  final hunks = <DiffHunk>[];
  final changes = lines
      .asMap()
      .entries
      .where((e) => e.value.type != DiffLineType.normal)
      .map((e) => DiffLineWithIndex(
            line: e.value,
            index: e.key,
          ))
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
  var currentHunk = <DiffLine>[];
  var lastIncludedIndex = -1;

  for (var i = 0; i < changes.length; i++) {
    final change = changes[i];
    final startContext = (change.index - contextLines).clamp(0, lines.length - 1);
    final endContext =
        (change.index + contextLines).clamp(0, lines.length - 1);

    // Add lines from last included index to current hunk
    for (var j = (lastIncludedIndex + 1).clamp(0, startContext);
        j <= endContext;
        j++) {
      currentHunk.add(lines[j]);
    }
    lastIncludedIndex = endContext;

    // Check if we should start a new hunk
    final nextChange = i + 1 < changes.length ? changes[i + 1] : null;
    if (nextChange != null && nextChange.index - endContext > contextLines * 2) {
      if (currentHunk.isNotEmpty) {
        hunks.add(_buildHunk(currentHunk));
        currentHunk = [];
      }
    }
  }

  // Add remaining lines to last hunk
  if (currentHunk.isNotEmpty) {
    hunks.add(_buildHunk(currentHunk));
  }

  return hunks;
}

/// Diff line with index
class DiffLineWithIndex {
  final DiffLine line;
  final int index;

  DiffLineWithIndex({
    required this.line,
    required this.index,
  });
}

/// Build a hunk from current lines
DiffHunk _buildHunk(List<DiffLine> lines) {
  final firstLine = lines.first;
  final oldLines = lines.where((l) => l.oldLineNumber != null).length;
  final newLines = lines.where((l) => l.newLineNumber != null).length;

  return DiffHunk(
    oldStart: firstLine.oldLineNumber ?? 1,
    oldLines: oldLines,
    newStart: firstLine.newLineNumber ?? 1,
    newLines: newLines,
    lines: lines,
  );
}

/// Get diff statistics without full diff
DiffStats getDiffStats(String oldText, String newText) {
  return calculateUnifiedDiff(oldText, newText).stats;
}
