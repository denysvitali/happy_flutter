import 'package:flutter/material.dart';
import '../tool_section_view.dart';
import 'edit_view.dart';

/// View for displaying MultiEdit tool with multiple diffs.
class MultiEditView extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  const MultiEditView({super.key, required this.tool, this.metadata});

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final edits = input['edits'] as List?;

    if (edits == null || edits.isEmpty) {
      return const SizedBox.shrink();
    }

    final parsedEdits = edits
        .map((e) {
          if (e is! Map<String, dynamic>) return null;
          return {
            'old_string': e['old_string'] as String? ?? '',
            'new_string': e['new_string'] as String? ?? '',
            'replace_all': e['replace_all'] as bool? ?? false,
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    if (parsedEdits.isEmpty) {
      return const SizedBox.shrink();
    }

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: parsedEdits.asMap().entries.map((entry) {
          final index = entry.key;
          final edit = entry.value;
          final isLast = index == parsedEdits.length - 1;

          return Column(
            key: Key('edit_$index'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DiffView(
                oldText: _trimIndent(edit['old_string'] as String? ?? ''),
                newText: _trimIndent(edit['new_string'] as String? ?? ''),
                showLineNumbers: false,
                showPlusMinus: false,
              ),
              if (!isLast) const SizedBox(height: 8),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _trimIndent(String text) {
    if (text.isEmpty) return '';
    final lines = text.split('\n');
    if (lines.length == 1) return text.trim();

    int minIndent = lines
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.length - line.trimLeft().length)
        .reduce((a, b) => a < b ? a : b);

    return lines
        .map((line) {
          if (line.trim().isEmpty) return line;
          return line.length > minIndent ? line.substring(minIndent) : line;
        })
        .join('\n');
  }
}
