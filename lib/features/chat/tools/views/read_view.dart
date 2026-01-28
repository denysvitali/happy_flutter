import 'package:flutter/material.dart';
import '../tool_section_view.dart';
import 'package:happy_flutter/core/utils/path_utils.dart';

/// View for displaying Read tool file content preview.
class ReadView extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  const ReadView({super.key, required this.tool, this.metadata});

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final result = tool['result'];
    final state = tool['state'] as String? ?? '';

    // Handle both file_path and locations (Gemini format)
    String? filePath;
    if (input['file_path'] != null) {
      filePath = input['file_path'] as String?;
    } else if (input['locations'] != null && input['locations'] is List && (input['locations'] as List).isNotEmpty) {
      filePath = input['locations'][0]['path'] as String?;
    }

    final resolvedPath = filePath != null ? resolvePath(filePath, metadata) : 'Unknown';
    final limit = input['limit'] as int?;
    final offset = input['offset'] as int?;

    // Parse result content
    String? content;
    int? totalLines;
    if (result != null) {
      if (result is String) {
        content = result;
        totalLines = content.split('\n').length;
      } else if (result is Map<String, dynamic>) {
        content = result['content'] as String? ??
            result['text'] as String? ??
            result['body'] as String?;
        totalLines = result['totalLines'] as int? ??
            result['numLines'] as int ??
            (content?.split('\n').length ?? 0);
      }
    }

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
                  Icons.description,
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
          // Metadata row
          if (offset != null || limit != null || totalLines != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  if (offset != null)
                    _buildMetaChip(context, 'Line $offset'),
                  if (limit != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _buildMetaChip(context, 'Limit: $limit'),
                    ),
                  if (totalLines != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _buildMetaChip(context, '$totalLines lines'),
                    ),
                ],
              ),
            ),
          // Content preview
          if (state == 'completed' && content != null && content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildContentPreview(context, content, limit),
            ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(BuildContext context, String label) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: theme.colorScheme.onSurfaceVariant,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildContentPreview(BuildContext context, String content, int? limit) {
    final theme = Theme.of(context);

    // Apply limit if specified
    final lines = content.split('\n');
    final displayLines = limit != null && limit > 0 ? lines.take(limit).toList() : lines;
    final displayContent = displayLines.join('\n');
    final hasMore = limit != null && lines.length > limit;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            displayContent,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFFD4D4D4),
              height: 1.4,
            ),
          ),
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '... and ${lines.length - limit} more lines',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
