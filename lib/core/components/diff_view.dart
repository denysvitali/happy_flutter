/// Backward-compatible diff model + parser surface.
///
/// The canonical diff types and algorithm now live in `core/ui/diff`. This
/// file re-exports them and keeps a thin [DiffParser] / [DiffResultExtension]
/// shim so legacy `core/components` importers continue to compile.
library;

export 'package:happy_flutter/core/ui/diff/calculate_diff.dart'
    show calculateUnifiedDiff;
export 'package:happy_flutter/core/ui/diff/diff_types.dart'
    show DiffHunk, DiffLine, DiffLineType, DiffResult, DiffStats, DiffToken;

import 'package:happy_flutter/core/ui/diff/calculate_diff.dart';
import 'package:happy_flutter/core/ui/diff/diff_types.dart';

/// Legacy parser facade over the canonical [calculateUnifiedDiff] algorithm.
class DiffParser {
  /// Parse git diff for two strings into a [DiffResult].
  static DiffResult compareStrings(
    String oldText,
    String newText, {
    int contextLines = 3,
  }) {
    return calculateUnifiedDiff(
      oldText,
      newText,
      contextLines: contextLines,
    );
  }
}

/// Convenience accessors over [DiffResult].
extension DiffResultExtension on DiffResult {
  /// Total number of changed lines.
  int get totalChanges => stats.additions + stats.deletions;

  /// Added lines across all hunks.
  List<DiffLine> get addedLines => hunks
      .expand((h) => h.lines)
      .where((l) => l.type == DiffLineType.add)
      .toList();

  /// Removed lines across all hunks.
  List<DiffLine> get removedLines => hunks
      .expand((h) => h.lines)
      .where((l) => l.type == DiffLineType.remove)
      .toList();

  /// Context (unchanged) lines across all hunks.
  List<DiffLine> get contextLines => hunks
      .expand((h) => h.lines)
      .where((l) => l.type == DiffLineType.normal)
      .toList();
}
