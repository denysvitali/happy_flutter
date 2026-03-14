import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import '../tool_section_view.dart';

/// Search result item model.
class SearchResult {

  /// Creates a [SearchResult].
  SearchResult({required this.title, required this.url, this.snippet});
  /// The title of the search result.
  final String title;

  /// The URL of the search result.
  final String url;

  /// An optional short description / snippet.
  final String? snippet;
}

/// View for displaying WebSearch tool results.
class WebSearchView extends StatefulWidget {

  const WebSearchView({required this.tool, super.key, this.metadata});
  /// The tool data map containing input, result, and state.
  final Map<String, dynamic> tool;

  /// Optional metadata associated with this tool invocation.
  final Map<String, dynamic>? metadata;

  @override
  State<WebSearchView> createState() => _WebSearchViewState();
}

class _WebSearchViewState extends State<WebSearchView> {
  bool _showAll = false;

  static const int _maxInline = 5;

  List<SearchResult> _parseResults(dynamic result) {
    final results = <SearchResult>[];

    if (result is List) {
      for (final item in result) {
        if (item is Map<String, dynamic>) {
          results.add(_itemToResult(item));
        }
      }
      return results;
    }

    if (result is Map<String, dynamic>) {
      final source =
          result['results'] as List? ??
          result['hits'] as List? ??
          result['items'] as List? ??
          result['organic_results'] as List? ??
          [];
      for (final item in source) {
        if (item is Map<String, dynamic>) {
          results.add(_itemToResult(item));
        }
      }
    }

    return results;
  }

  SearchResult _itemToResult(Map<String, dynamic> item) {
    return SearchResult(
      title: item['title'] as String? ?? 'No title',
      url: item['url'] as String? ??
          item['link'] as String? ??
          item['href'] as String? ??
          '',
      snippet: item['snippet'] as String? ??
          item['description'] as String? ??
          item['summary'] as String?,
    );
  }

  @override
  Widget build(BuildContext context) {
    final input =
        widget.tool['input'] as Map<String, dynamic>? ?? {};
    final result = widget.tool['result'];
    final state = widget.tool['state'] as String? ?? '';

    final query = input['query'] as String? ?? '';

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search bar
          _SearchBar(query: query, state: state),

          // Loading
          if (state == 'running') const _LoadingIndicator(),

          // Results
          if (state == 'completed' && result != null)
            _buildResultsSection(context, result),

          // Error
          if (state == 'error' || state == 'failed')
            _ErrorBanner(
              message: result is String ? result : null,
            ),
        ],
      ),
    );
  }

  Widget _buildResultsSection(BuildContext context, dynamic result) {
    final results = _parseResults(result);

    if (results.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final visible = _showAll ? results : results.take(_maxInline).toList();
    final remaining = results.length - _maxInline;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.smd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Results header
          Row(
            children: [
              const _GoogleDotsIcon(),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${results.length} result${results.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Result cards
          ...visible.map(
            (r) => _ResultCard(searchResult: r),
          ),
          // Show more / less toggle
          if (results.length > _maxInline)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: () => setState(() => _showAll = !_showAll),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xsm,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showAll
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        _showAll
                            ? 'Show fewer'
                            : '+ $remaining more result'
                                '${remaining == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: AppFontSize.sm,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Styled search bar showing the query.
class _SearchBar extends StatelessWidget {

  const _SearchBar({required this.query, required this.state});
  final String query;
  final String state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = state == 'completed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(
          color: isDone
              ? theme.colorScheme.outlineVariant
              : theme.colorScheme.primary.withAlpha(77),
          width: isDone ? AppBorder.hairline : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              query,
              style: TextStyle(
                fontSize: AppFontSize.md,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isDone)
            Icon(
              Icons.check_circle,
              size: 14,
              color: AppColors.success,
            ),
        ],
      ),
    );
  }
}

/// Google-style coloured dots icon indicating a web search.
class _GoogleDotsIcon extends StatelessWidget {
  const _GoogleDotsIcon();

  @override
  Widget build(BuildContext context) {
    const size = 7.0;
    const gap = 2.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Dot(size: size, color: Color(0xFF4285F4)),
        SizedBox(width: gap),
        const _Dot(size: size, color: Color(0xFFEA4335)),
        SizedBox(width: gap),
        const _Dot(size: size, color: Color(0xFFFBBC05)),
        SizedBox(width: gap),
        const _Dot(size: size, color: Color(0xFF34A853)),
      ],
    );
  }
}

class _Dot extends StatelessWidget {

  const _Dot({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// A single search result card with title, URL chip, and snippet.
class _ResultCard extends StatelessWidget {

  const _ResultCard({required this.searchResult});
  final SearchResult searchResult;

  /// Returns the domain portion of a URL for compact display.
  String _domain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.isNotEmpty ? uri.host : url;
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            width: AppBorder.hairline,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withAlpha(10),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.smd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Domain chip
              if (searchResult.url.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.link,
                        size: 10,
                        color: theme.colorScheme.onSurfaceVariant
                            .withAlpha(153),
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          _domain(searchResult.url),
                          style: TextStyle(
                            fontSize: AppFontSize.xxs,
                            color: theme.colorScheme.onSurfaceVariant,
                            overflow: TextOverflow.ellipsis,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 5),
              // Title
              Text(
                searchResult.title,
                style: TextStyle(
                  fontSize: AppFontSize.md,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // Snippet
              if (searchResult.snippet != null &&
                  searchResult.snippet!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    searchResult.snippet!,
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated loading indicator while search is running.
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.smd),
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
            'Searching the web...',
            style: TextStyle(
              fontSize: AppFontSize.sm,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Error state banner.
class _ErrorBanner extends StatelessWidget {

  const _ErrorBanner({this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.smd),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withAlpha(128),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: theme.colorScheme.error.withAlpha(77),
            width: AppBorder.hairline,
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
                message?.isNotEmpty ?? false
                    ? message!
                    : 'Search failed. Please try again.',
                style: TextStyle(
                  fontSize: AppFontSize.sm,
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
