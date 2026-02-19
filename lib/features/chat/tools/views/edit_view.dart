import 'dart:math';
import 'package:flutter/material.dart';

/// View for displaying Edit tool diffs.
///
/// Shows a compact unified diff, collapsed by default for large diffs.
class EditView extends StatefulWidget {
  /// The tool call data.
  final Map<String, dynamic> tool;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  const EditView({super.key, required this.tool, this.metadata});

  @override
  State<EditView> createState() => _EditViewState();
}

class _EditViewState extends State<EditView> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final input = widget.tool['input'] as Map<String, dynamic>? ?? {};
    final oldString = input['old_string'] as String? ?? '';
    final newString = input['new_string'] as String? ?? '';

    final diffLines = _computeUnifiedDiff(oldString, newString);
    // Auto-expand if diff is short
    final isShort = diffLines.length <= 8;
    final show = isShort || _expanded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isShort)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Row(
                  children: [
                    Icon(
                      _expanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _expanded
                          ? 'Hide diff'
                          : 'Show diff (${diffLines.length} lines)',
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary,
                              ),
                    ),
                  ],
                ),
              ),
            ),
          if (show)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: diffLines.map((line) => _buildDiffLine(line)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDiffLine(_DiffLine line) {
    Color bgColor;
    Color textColor;
    String prefix;
    switch (line.type) {
      case _DiffType.removal:
        bgColor = const Color(0xFF3D1E20);
        textColor = const Color(0xFFFF9B9B);
        prefix = '- ';
        break;
      case _DiffType.addition:
        bgColor = const Color(0xFF1E3D20);
        textColor = const Color(0xFF9BFFAB);
        prefix = '+ ';
        break;
      case _DiffType.context:
        bgColor = Colors.transparent;
        textColor = const Color(0xFF808080);
        prefix = '  ';
        break;
    }

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Text(
        '$prefix${line.text}',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          height: 1.4,
          color: textColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  List<_DiffLine> _computeUnifiedDiff(String oldStr, String newStr) {
    final oldLines = oldStr.split('\n');
    final newLines = newStr.split('\n');
    final result = <_DiffLine>[];

    // Simple LCS-based diff
    final lcs = _lcs(oldLines, newLines);
    int oi = 0, ni = 0, li = 0;

    while (oi < oldLines.length || ni < newLines.length) {
      if (li < lcs.length &&
          oi < oldLines.length &&
          ni < newLines.length &&
          oldLines[oi] == lcs[li] &&
          newLines[ni] == lcs[li]) {
        result.add(_DiffLine(_DiffType.context, oldLines[oi]));
        oi++;
        ni++;
        li++;
      } else if (oi < oldLines.length &&
          (li >= lcs.length || oldLines[oi] != lcs[li])) {
        result.add(_DiffLine(_DiffType.removal, oldLines[oi]));
        oi++;
      } else if (ni < newLines.length &&
          (li >= lcs.length || newLines[ni] != lcs[li])) {
        result.add(_DiffLine(_DiffType.addition, newLines[ni]));
        ni++;
      }
    }

    return result;
  }

  /// Compute LCS of two string lists.
  List<String> _lcs(List<String> a, List<String> b) {
    final m = a.length;
    final n = b.length;
    // For very large inputs, skip LCS and just show before/after
    if (m * n > 50000) {
      return [];
    }
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = max(dp[i - 1][j], dp[i][j - 1]);
        }
      }
    }

    final result = <String>[];
    int i = m, j = n;
    while (i > 0 && j > 0) {
      if (a[i - 1] == b[j - 1]) {
        result.add(a[i - 1]);
        i--;
        j--;
      } else if (dp[i - 1][j] > dp[i][j - 1]) {
        i--;
      } else {
        j--;
      }
    }
    return result.reversed.toList();
  }
}

enum _DiffType { removal, addition, context }

class _DiffLine {
  final _DiffType type;
  final String text;
  _DiffLine(this.type, this.text);
}

/// Simple diff view (re-exported for other uses).
class DiffView extends StatelessWidget {
  /// Old text content.
  final String oldText;

  /// New text content.
  final String newText;

  /// Whether to show line numbers.
  final bool showLineNumbers;

  /// Whether to show +/- prefix.
  final bool showPlusMinus;

  const DiffView({
    super.key,
    required this.oldText,
    required this.newText,
    this.showLineNumbers = true,
    this.showPlusMinus = true,
  });

  @override
  Widget build(BuildContext context) {
    return EditView(
      tool: {
        'input': {
          'old_string': oldText,
          'new_string': newText,
        },
      },
    );
  }
}
