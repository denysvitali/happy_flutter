import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/wire_parsers.dart';

import '../tool_section_view.dart';

/// Displays the query and sources returned by Claude's WebSearch tool.
class WebSearchView extends StatelessWidget {
  const WebSearchView({required this.tool, super.key});

  final Map<String, dynamic> tool;

  @override
  Widget build(BuildContext context) {
    final result = WireParsers.asMap(tool['result']);
    final query = _query(WireParsers.asMap(tool['input']), result);
    final sources = _sources(result);
    final state = tool['state'] as String? ?? '';

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
              if (state == 'completed')
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
          if (sources.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final source in sources)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: _SourceTile(source: source),
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
      final queries = WireParsers.asList(candidate['queries']);
      if (queries != null && queries.isNotEmpty) {
        return queries.map((item) => item.toString()).join(', ');
      }
    }
    return '';
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
