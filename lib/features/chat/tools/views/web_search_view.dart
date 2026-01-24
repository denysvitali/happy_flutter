import 'package:flutter/material.dart';
import '../tool_section_view.dart';

/// Search result item model.
class SearchResult {
  final String title;
  final String url;
  final String? snippet;

  SearchResult({required this.title, required this.url, this.snippet});
}

/// View for displaying WebSearch tool results.
class WebSearchView extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  const WebSearchView({super.key, required this.tool, this.metadata});

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final result = tool['result'];
    final state = tool['state'] as String? ?? '';

    final query = input['query'] as String? ?? '';

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Query display
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Search: "$query"',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ],
            ),
          ),
          // Results if available
          if (state == 'completed' && result != null)
            _buildResultsSection(context, result),
        ],
      ),
    );
  }

  Widget _buildResultsSection(BuildContext context, dynamic result) {
    final theme = Theme.of(context);

    List<SearchResult> results = [];

    if (result is List) {
      // Result is already a list of results
      for (final item in result) {
        if (item is Map<String, dynamic>) {
          results.add(
            SearchResult(
              title: item['title'] as String? ?? 'No title',
              url: item['url'] as String? ?? '',
              snippet: item['snippet'] as String?,
            ),
          );
        }
      }
    } else if (result is Map<String, dynamic>) {
      // Try common formats
      final resultsList = result['results'] as List?;
      final hits = result['hits'] as List?;
      final items = result['items'] as List?;

      final source = resultsList ?? hits ?? items ?? [];
      for (final item in source) {
        if (item is Map<String, dynamic>) {
          results.add(
            SearchResult(
              title: item['title'] as String? ?? 'No title',
              url: item['url'] as String? ?? item['link'] as String? ?? '',
              snippet:
                  item['snippet'] as String? ?? item['description'] as String?,
            ),
          );
        }
      }
    }

    if (results.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Results',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ...results.take(5).map((result) => _buildResultItem(context, result)),
          if (results.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${results.length - 5} more results',
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

  Widget _buildResultItem(BuildContext context, SearchResult result) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
              result.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              result.url,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
            if (result.snippet != null && result.snippet!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  result.snippet!,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
