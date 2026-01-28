import 'package:flutter/material.dart';
import '../tool_section_view.dart';
import 'package:happy_flutter/core/utils/path_utils.dart';

/// Parsed unified diff result.
class ParsedDiff {
  final String oldText;
  final String newText;
  final String? fileName;

  ParsedDiff({required this.oldText, required this.newText, this.fileName});
}

/// View for displaying CodexDiff tool with unified diff parsing.
class CodexDiffView extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  const CodexDiffView({super.key, required this.tool, this.metadata});

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};

    final unifiedDiff = input['unified_diff'] as String?;

    if (unifiedDiff == null || unifiedDiff.isEmpty) {
      return const SizedBox.shrink();
    }

    final parsed = _parseUnifiedDiff(unifiedDiff);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // File header if available
        if (parsed.fileName != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.compare_arrows,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                SelectableText(
                  parsed.fileName!,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        // Diff content
        ToolSectionView(
          fullWidth: true,
          child: _DiffContentView(
            oldText: parsed.oldText,
            newText: parsed.newText,
          ),
        ),
      ],
    );
  }

  ParsedDiff _parseUnifiedDiff(String unifiedDiff) {
    final lines = unifiedDiff.split('\n');
    final oldLines = <String>[];
    final newLines = <String>[];
    String? fileName;
    var inHunk = false;

    for (final line in lines) {
      // Extract filename from diff header
      if (line.startsWith('+++ b/') || line.startsWith('+++ ')) {
        fileName = line.replaceFirst(RegExp(r'^\+\+\+ (b/)?'), '');
        continue;
      }

      // Skip other header lines
      if (line.startsWith('diff --git') ||
          line.startsWith('index ') ||
          line.startsWith('---') ||
          line.startsWith('new file mode') ||
          line.startsWith('deleted file mode')) {
        continue;
      }

      // Hunk header
      if (line.startsWith('@@')) {
        inHunk = true;
        continue;
      }

      if (inHunk) {
        if (line.startsWith('+')) {
          // Added line
          newLines.add(line.substring(1));
        } else if (line.startsWith('-')) {
          // Removed line
          oldLines.add(line.substring(1));
        } else if (line.startsWith(' ')) {
          // Context line (unchanged)
          final content = line.substring(1);
          oldLines.add(content);
          newLines.add(content);
        } else if (line == '\\ No newline at end of file') {
          continue;
        } else if (line.isEmpty) {
          oldLines.add('');
          newLines.add('');
        }
      }
    }

    return ParsedDiff(
      oldText: oldLines.join('\n'),
      newText: newLines.join('\n'),
      fileName: fileName,
    );
  }
}

/// Displays diff content with color coding.
class _DiffContentView extends StatelessWidget {
  final String oldText;
  final String newText;

  const _DiffContentView({required this.oldText, required this.newText});

  @override
  Widget build(BuildContext context) {
    final oldLines = oldText.split('\n');
    final newLines = newText.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Old text (deletions)
        if (oldText.isNotEmpty)
          _buildDiffSection(
            Theme.of(context),
            'Before',
            oldLines,
            const Color(0xFFFFEBEB),
            Icons.remove,
            true,
          ),
        // New text (additions)
        if (newText.isNotEmpty)
          _buildDiffSection(
            Theme.of(context),
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
