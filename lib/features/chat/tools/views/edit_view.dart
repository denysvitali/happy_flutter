import 'package:flutter/material.dart';
import '../tool_section_view.dart';

/// View for displaying Edit tool diffs.
class EditView extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  const EditView({super.key, required this.tool, this.metadata});

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final oldString = input['old_string'] as String? ?? '';
    final newString = input['new_string'] as String? ?? '';

    return ToolSectionView(
      child: DiffView(
        oldText: _trimIndent(oldString),
        newText: _trimIndent(newString),
        showLineNumbers: false,
        showPlusMinus: false,
      ),
    );
  }

  String _trimIndent(String text) {
    if (text.isEmpty) return '';
    final lines = text.split('\n');
    if (lines.length == 1) return text.trim();

    // Find minimum indentation of non-empty lines
    int minIndent = lines
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.length - line.trimLeft().length)
        .reduce((a, b) => a < b ? a : b);

    // Remove minimum indentation from all lines
    return lines
        .map((line) {
          if (line.trim().isEmpty) return line;
          return line.length > minIndent ? line.substring(minIndent) : line;
        })
        .join('\n');
  }
}

/// Simple diff view showing old and new text with color coding.
class DiffView extends StatelessWidget {
  final String oldText;
  final String newText;
  final bool showLineNumbers;
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
    final theme = Theme.of(context);
    final oldLines = oldText.split('\n');
    final newLines = newText.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Old text (with deletions)
        if (oldText.isNotEmpty)
          _buildDiffSection(
            theme,
            'Before',
            oldLines,
            const Color(0xFFFFEBEB),
            Icons.remove,
            true,
          ),
        // New text (with additions)
        if (newText.isNotEmpty)
          _buildDiffSection(
            theme,
            'After',
            newLines,
            const Color(0xFFE6FFEC),
            Icons.add,
            false,
          ),
      ],
    );
  }

  Widget _buildDiffSection(
    ThemeData theme,
    String label,
    List<String> lines,
    Color backgroundColor,
    IconData icon,
    bool isRemoval,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isRemoval
                      ? const Color(0xFFCF2222)
                      : const Color(0xFF1A7F37),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Code content
          Padding(
            padding: const EdgeInsets.all(8),
            child: SelectableText(
              lines.join('\n'),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
