import 'package:flutter/material.dart';
import '../tool_section_view.dart';
import 'edit_view.dart';
import 'package:happy_flutter/core/utils/path_utils.dart';

/// View for displaying Gemini edit tool (lowercase 'edit').
class GeminiEditView extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  const GeminiEditView({super.key, required this.tool, this.metadata});

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};

    // Gemini sends data in nested structure, try multiple locations
    String? filePath;
    String? oldText;
    String? newText;

    // Check toolCall.content[0].path
    if (input['toolCall'] != null &&
        input['toolCall'] is Map<String, dynamic>) {
      final toolCall = input['toolCall'] as Map<String, dynamic>;
      if (toolCall['content'] != null &&
          toolCall['content'] is List &&
          (toolCall['content'] as List).isNotEmpty) {
        final content = toolCall['content'][0] as Map<String, dynamic>?;
        filePath = content?['path'] as String?;
      }
      // Check toolCall.title (has nice "Writing to ..." format)
      final title = toolCall['title'] as String?;
      if (title != null && filePath == null) {
        // Extract path from title like "Writing to /path/to/file"
        if (title.startsWith('Writing to ')) {
          filePath = title.replaceFirst('Writing to ', '');
        }
      }
    }
    // Check input[0].path (array format)
    if (filePath == null &&
        input['input'] != null &&
        input['input'] is List &&
        (input['input'] as List).isNotEmpty) {
      final inputItem = input['input'][0] as Map<String, dynamic>?;
      filePath = inputItem?['path'] as String?;
    }
    // Check direct path field
    if (filePath == null) {
      filePath = input['path'] as String?;
    }

    // Get edit texts
    if (input['oldText'] != null) {
      oldText = input['oldText'] as String?;
    }
    if (input['newText'] != null) {
      newText = input['newText'] as String?;
    }

    // Try toolCall structure for edit text
    if ((oldText == null || newText == null) && input['toolCall'] != null) {
      final toolCall = input['toolCall'] as Map<String, dynamic>;
      if (oldText == null) {
        oldText = toolCall['oldText'] as String? ?? toolCall['old_string'] as String?;
      }
      if (newText == null) {
        newText = toolCall['newText'] as String? ?? toolCall['new_string'] as String?;
      }
    }

    final resolvedPath =
        filePath != null ? resolvePath(filePath, metadata) : 'Unknown';

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // File path header
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.edit,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    resolvedPath,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Diff view if we have old/new text
          if ((oldText != null && oldText.isNotEmpty) ||
              (newText != null && newText.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: DiffView(
                oldText: _trimIndent(oldText ?? ''),
                newText: _trimIndent(newText ?? ''),
                showLineNumbers: false,
                showPlusMinus: false,
              ),
            ),
        ],
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
