import 'package:flutter/material.dart';
import '../tool_section_view.dart';

/// View for displaying WebFetch tool results.
class WebFetchView extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  const WebFetchView({super.key, required this.tool, this.metadata});

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final result = tool['result'];
    final state = tool['state'] as String? ?? '';

    final url = input['url'] as String? ?? '';
    final prompt = input['prompt'] as String?;

    // Try to extract hostname for display
    String displayHost = 'URL';
    if (url.isNotEmpty) {
      try {
        final uri = Uri.parse(url);
        displayHost = uri.host;
      } catch (_) {
        displayHost = url;
      }
    }

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // URL display
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.public,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    url,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Prompt if available
          if (prompt != null && prompt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Prompt',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(prompt, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
          // Result if available
          if (state == 'completed' && result != null)
            _buildResultSection(context, result),
        ],
      ),
    );
  }

  Widget _buildResultSection(BuildContext context, dynamic result) {
    final theme = Theme.of(context);
    String content = '';

    if (result is String) {
      content = result;
    } else if (result is Map<String, dynamic>) {
      // Try to extract content from common fields
      content =
          result['content'] as String? ??
          result['text'] as String? ??
          result['body'] as String? ??
          result.toString();
    }

    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    // Truncate if too long
    final displayContent = content.length > 500
        ? '${content.substring(0, 500)}...'
        : content;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Content',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              displayContent,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
