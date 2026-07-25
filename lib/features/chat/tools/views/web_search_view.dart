import 'package:flutter/material.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/wire/wire_parsers.dart';

import '../tool_section_view.dart';

/// Displays the query and sources returned by Claude's WebSearch tool.
class WebSearchView extends StatelessWidget {
  const WebSearchView({required this.tool, super.key});

  final Map<String, dynamic> tool;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final input = WireParsers.asMap(tool['input']);
    final result = WireParsers.asMap(tool['result']);
    final query = _query(input, result);
    final queries = _queries(input, result);
    final sources = _sources(result);
    final state = tool['state'] as String? ?? '';
    final isCompleted = state == 'completed';
    final hasSources = sources.isNotEmpty;
    final hasExtraQueries =
        queries.length > 1 || (queries.length == 1 && queries.first != query);

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  query.isEmpty ? 'Searching the web' : query,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCompleted)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
          if (hasExtraQueries) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.webSearchQueriesLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final q in queries)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 6,
                        right: AppSpacing.xs,
                      ),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        q,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (hasSources) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final source in sources)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: _SourceTile(source: source),
              ),
          ] else if (isCompleted) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.webSearchNoResultsNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _query(Map<String, dynamic>? input, Map<String, dynamic>? result) {
    for (final candidate in [
      input,
      WireParsers.asMap(result?['action']),
      WireParsers.asMap(WireParsers.asMap(result?['result'])?['action']),
      result,
    ]) {
      if (candidate == null) continue;
      final query = candidate['query'] ?? candidate['search_query'];
      if (query is String && query.isNotEmpty) return query;
    }
    // Fall back to the first expanded query if no top-level query.
    final queries = _queries(input, result);
    if (queries.isNotEmpty) return queries.first;
    return '';
  }

  /// Expanded search queries (the model's actual search terms), which may
  /// differ from the top-level [query]. Returns an empty list when only the
  /// top-level query is known.
  List<String> _queries(
    Map<String, dynamic>? input,
    Map<String, dynamic>? result,
  ) {
    for (final candidate in [
      WireParsers.asMap(input?['action']),
      WireParsers.asMap(result?['action']),
      WireParsers.asMap(WireParsers.asMap(result?['result'])?['action']),
      input,
      result,
    ]) {
      if (candidate == null) continue;
      final list = WireParsers.asList(candidate['queries']);
      if (list == null || list.isEmpty) continue;
      return list
          .map((item) => item.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }

  List<Map<String, dynamic>> _sources(Map<String, dynamic>? result) {
    if (result == null) return const [];
    final nested = WireParsers.asMap(result['result']);
    final candidates = [
      result['sources'],
      result['results'],
      WireParsers.asMap(result['action'])?['sources'],
      nested?['sources'],
      nested?['results'],
      WireParsers.asMap(nested?['action'])?['sources'],
    ];
    for (final candidate in candidates) {
      final items = WireParsers.asList(candidate);
      if (items == null) continue;
      return items
          .map(WireParsers.asMap)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    }
    return const [];
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source});

  final Map<String, dynamic> source;

  @override
  Widget build(BuildContext context) {
    final title =
        source['title'] ?? source['name'] ?? source['url'] ?? 'Result';
    final url = source['url'] ?? source['link'] ?? source['href'];
    final snippet =
        source['snippet'] ?? source['description'] ?? source['summary'];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title.toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (url != null)
            Text(
              url.toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          if (snippet != null)
            Text(
              snippet.toString(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
