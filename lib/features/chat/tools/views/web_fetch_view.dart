import 'package:flutter/material.dart';
import '../tool_section_view.dart';

/// View for displaying WebFetch tool results.
class WebFetchView extends StatefulWidget {

  const WebFetchView({required this.tool, super.key, this.metadata});
  /// The tool data map containing input, result, and state.
  final Map<String, dynamic> tool;

  /// Optional metadata associated with this tool invocation.
  final Map<String, dynamic>? metadata;

  @override
  State<WebFetchView> createState() => _WebFetchViewState();
}

class _WebFetchViewState extends State<WebFetchView> {
  void _showFullContent(BuildContext context, String content) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.language,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fetched Content',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  content,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final input =
        widget.tool['input'] as Map<String, dynamic>? ?? {};
    final result = widget.tool['result'];
    final state = widget.tool['state'] as String? ?? '';

    final url = input['url'] as String? ?? '';
    final prompt = input['prompt'] as String?;

    final theme = Theme.of(context);

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status + URL row
          _UrlChip(url: url, state: state),

          // Prompt if available
          if (prompt != null && prompt.isNotEmpty)
            _PromptBadge(prompt: prompt),

          // Result section
          if (result != null)
            _ResultSection(
              state: state,
              result: result,
              onViewFull: (content) =>
                  _showFullContent(context, content),
            ),

          // Loading indicator
          if (state == 'running')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Fetching page...',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Styled chip showing the URL and a globe icon.
class _UrlChip extends StatelessWidget {

  const _UrlChip({required this.url, required this.state});
  final String url;
  final String state;

  Color _stateColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (state) {
      case 'completed':
        return const Color(0xFF16A34A); // green-600
      case 'error':
      case 'failed':
        return cs.error;
      default:
        return cs.primary;
    }
  }

  IconData _stateIcon() {
    switch (state) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'error':
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.language;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stateColor = _stateColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          // Globe indicator badge
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: stateColor.withAlpha(26),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _stateIcon(),
              size: 14,
              color: stateColor,
            ),
          ),
          const SizedBox(width: 8),
          // URL text
          Expanded(
            child: Text(
              url,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: theme.colorScheme.primary.withAlpha(128),
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.open_in_new,
            size: 12,
            color: theme.colorScheme.onSurfaceVariant.withAlpha(153),
          ),
        ],
      ),
    );
  }
}

/// Displays the optional user prompt.
class _PromptBadge extends StatelessWidget {

  const _PromptBadge({required this.prompt});
  final String prompt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer.withAlpha(128),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.format_quote,
              size: 14,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                prompt,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays the fetched content with a preview and "View full" button.
class _ResultSection extends StatelessWidget {

  const _ResultSection({
    required this.state,
    required this.result,
    required this.onViewFull,
  });
  final String state;
  final dynamic result;
  final void Function(String content) onViewFull;

  String _extractContent() {
    if (result is String) return result as String;
    if (result is Map<String, dynamic>) {
      final map = result as Map<String, dynamic>;
      return map['content'] as String? ??
          map['text'] as String? ??
          map['body'] as String? ??
          map.toString();
    }
    return result.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (state == 'error' || state == 'failed') {
      return _ErrorBanner(message: _extractContent());
    }
    if (state != 'completed') return const SizedBox.shrink();

    final content = _extractContent();
    if (content.isEmpty) return const SizedBox.shrink();

    final preview = content.length > 200
        ? '${content.substring(0, 200)}...'
        : content;
    final hasMore = content.length > 200;

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withAlpha(20),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.article_outlined,
                    size: 13,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Content preview',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF16A34A).withAlpha(204),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${content.length} chars',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant
                          .withAlpha(153),
                    ),
                  ),
                ],
              ),
            ),
            // Preview text
            Padding(
              padding: const EdgeInsets.all(10),
              child: SelectableText(
                preview,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            // View full button
            if (hasMore)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => onViewFull(content),
                    icon: const Icon(Icons.open_in_full, size: 14),
                    label: const Text('View full content'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Error state banner.
class _ErrorBanner extends StatelessWidget {

  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withAlpha(128),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.error.withAlpha(77),
            width: 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              size: 14,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message.isNotEmpty ? message : 'Failed to fetch content.',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
