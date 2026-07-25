import 'package:flutter/material.dart';
import 'package:happy_flutter/core/wire/wire_parsers.dart';

import '../tool_section_view.dart';
import 'file_diff_view.dart';

/// View for displaying CodexDiff tool with proper unified diff rendering.
class CodexDiffView extends StatelessWidget {
  /// Creates a [CodexDiffView].
  const CodexDiffView({required this.tool, super.key, this.metadata});

  /// The tool data map containing input and result.
  final Map<String, dynamic> tool;

  /// Optional metadata for path resolution.
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final input = WireParsers.asMap(tool['input']) ?? {};
    final unifiedDiff = input['unified_diff'] as String?;

    if (unifiedDiff == null || unifiedDiff.isEmpty) {
      return const SizedBox.shrink();
    }

    final parsed = _parseUnifiedDiff(unifiedDiff);

    return ToolSectionView(
      child: FileDiffView(
        oldText: parsed.oldText,
        newText: parsed.newText,
        filePath: parsed.fileName,
        rawCopyText: parsed.rawDiff,
        icon: Icons.difference_outlined,
        collapseThreshold: 60,
      ),
    );
  }

  _ParsedDiff _parseUnifiedDiff(String unifiedDiff) {
    final lines = unifiedDiff.split('\n');
    final oldLines = <String>[];
    final newLines = <String>[];
    String? fileName;
    var inHunk = false;

    for (final line in lines) {
      if (line.startsWith('+++ b/') || line.startsWith('+++ ')) {
        fileName = line.replaceFirst(RegExp(r'^\+\+\+ (b/)?'), '');
        continue;
      }
      if (line.startsWith('diff --git') ||
          line.startsWith('index ') ||
          line.startsWith('---') ||
          line.startsWith('new file mode') ||
          line.startsWith('deleted file mode')) {
        continue;
      }
      if (line.startsWith('@@')) {
        inHunk = true;
        continue;
      }
      if (inHunk) {
        if (line.startsWith('+')) {
          newLines.add(line.substring(1));
        } else if (line.startsWith('-')) {
          oldLines.add(line.substring(1));
        } else if (line.startsWith(' ')) {
          final content = line.substring(1);
          oldLines.add(content);
          newLines.add(content);
        } else if (line == r'\ No newline at end of file') {
          continue;
        } else if (line.isEmpty) {
          oldLines.add('');
          newLines.add('');
        }
      }
    }

    return _ParsedDiff(
      oldText: oldLines.join('\n'),
      newText: newLines.join('\n'),
      fileName: fileName,
      rawDiff: unifiedDiff,
    );
  }
}

class _ParsedDiff {
  const _ParsedDiff({
    required this.oldText,
    required this.newText,
    required this.rawDiff,
    this.fileName,
  });

  final String oldText;
  final String newText;
  final String? fileName;
  final String rawDiff;
}
