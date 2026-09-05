import 'package:flutter/material.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/services/logger_service.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/wire/wire_parsers.dart';
import 'package:url_launcher/url_launcher.dart';

import '../tool_section_view.dart';
import '../tool_view_helpers.dart'
    show mcpToolTextResult, tryDecodeJsonCollection;

/// One query's worth of search results.
///
/// A plain `search` call produces a single group; a batched call
/// (`{responses: [...]}`) produces one per query.
class SearchResultGroup {
  const SearchResultGroup({required this.query, required this.results});

  final String query;
  final List<Map<String, dynamic>> results;
}

/// Displays the query and sources returned by web-search tools.
///
/// Covers both Claude's built-in `WebSearch` (structured map result) and
/// search MCP servers, whose results arrive as a JSON string inside MCP
/// text content blocks — those used to render as a raw JSON blob.
class WebSearchView extends StatelessWidget {
  const WebSearchView({required this.tool, super.key});

  final Map<String, dynamic> tool;

  /// Whether [result] is an MCP payload this view can render as a source
  /// list rather than raw JSON.
  static bool canRenderMcpResult(dynamic result) =>
      mcpSearchGroups(result).isNotEmpty;

  /// Extracts the search-result groups from an MCP text-block payload.
  ///
  /// Returns an empty list for anything that isn't shaped like a search
  /// response, so unrelated MCP tools keep their JSON rendering.
  static List<SearchResultGroup> mcpSearchGroups(dynamic result) {
    final text = mcpToolTextResult(result);
    if (text == null) return const [];
    final payload = WireParsers.asMap(tryDecodeJsonCollection(text));
    if (payload == null) return const [];

    // Batched search: `{responses: [{query, results}, ...]}`.
    final responses = WireParsers.asList(payload['responses']);
    if (responses != null) {
      final groups = <SearchResultGroup>[];
      for (final response in responses) {
        final map = WireParsers.asMap(response);
        if (map == null) continue;
        final results = _resultList(map);
        if (results.isEmpty) continue;
        groups.add(
          SearchResultGroup(
            query: map['query'] as String? ?? '',
            results: results,
          ),
        );
      }
      return groups;
    }

    final results = _resultList(payload);
    if (results.isEmpty) return const [];
    return [
      SearchResultGroup(
        query: payload['query'] as String? ?? '',
        results: results,
      ),
    ];
  }

  /// Result entries of [map] that actually look like search hits — a URL
  /// is the minimum bar, so `{results: [1, 2, 3]}` from some unrelated
  /// tool is not mistaken for a search response.
  static List<Map<String, dynamic>> _resultList(Map<String, dynamic> map) {
    final raw =
        WireParsers.asList(map['results']) ??
        WireParsers.asList(map['sources']);
    if (raw == null) return const [];
    return raw
        .map(WireParsers.asMap)
        .whereType<Map<String, dynamic>>()
        .where((r) => (r['url'] ?? r['link'] ?? r['href']) != null)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final mcpGroups = mcpSearchGroups(tool['result']);
    if (mcpGroups.isNotEmpty) {
      return _buildMcpGroups(context, mcpGroups);
    }
    return _buildClaudeWebSearch(context);
  }

  Widget _buildMcpGroups(BuildContext context, List<SearchResultGroup> groups) {
    final theme = Theme.of(context);
    final inputQuery = WireParsers.asMap(tool['input'])?['query'] as String?;

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final group in groups) ...[
            Row(
              children: [
                Icon(Icons.search, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    group.query.isNotEmpty
                        ? group.query
                        : (inputQuery ?? 'Web search'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${group.results.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            for (final result in group.results)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: _SourceTile(source: result),
              ),
            if (group != groups.last) const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }

  Widget _buildClaudeWebSearch(BuildContext context) {
    final l10n = context.l10n;
    final input = WireParsers.asMap(tool['input']);
    final result = WireParsers.asMap(tool['result']);
    final query = _query(input, result);
    final queries = _queries(input, result);
    final sources = _sources(result);
    final state = tool['state'] as String? ?? '';
    final isCompleted = state == 'completed';
    final isOtherActivity = _actionType(input, result) == 'other';
    final hasSources = sources.isNotEmpty;
    final hasExtraQueries =
        queries.length > 1 || (queries.length == 1 && queries.first != query);

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  query.isNotEmpty
                      ? query
                      : isCompleted && isOtherActivity
                      ? l10n.webSearchActivityCompleted
                      : 'Searching the web',
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: _SourceTile(source: source),
              ),
          ] else if (isCompleted) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              isOtherActivity
                  ? l10n.webSearchNoActivityDetailsNote
                  : l10n.webSearchNoResultsNote,
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

  String? _actionType(
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
      final type = candidate?['type'];
      if (type is String && type.isNotEmpty) return type;
    }
    return null;
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
    final theme = Theme.of(context);
    final url = source['url'] ?? source['link'] ?? source['href'];
    final uri = _webUri(url);
    final title = source['title'] ?? source['name'] ?? url ?? 'Result';
    final snippet =
        source['snippet'] ?? source['description'] ?? source['summary'];
    // Providers that returned this hit, plus its publication date when the
    // backend knows one — the raw JSON carried both and they read as noise
    // in a URL line, so they get their own muted meta row.
    final meta = <String>[
      if (source['published'] is String &&
          (source['published'] as String).isNotEmpty)
        source['published'] as String,
      if (source['source'] is String && (source['source'] as String).isNotEmpty)
        (source['source'] as String).replaceAll(',', ' · '),
    ];

    return Semantics(
      link: uri != null,
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: uri == null ? null : () => _openPage(context, uri),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title.toString(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: uri == null
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    if (uri != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ],
                ),
                if (url != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _host(url.toString()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (snippet != null && snippet.toString().trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      snippet.toString(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (meta.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      meta.join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Uri? _webUri(dynamic value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }
    return uri;
  }

  Future<void> _openPage(BuildContext context, Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (error, stackTrace) {
      logger.warning('Failed to open search result', error, stackTrace);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.webSearchOpenPageFailed)),
    );
  }

  /// Host of [url] without the `www.` prefix; falls back to the raw string
  /// when it isn't parseable.
  static String _host(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.isEmpty) return url;
    return host.startsWith('www.') ? host.substring(4) : host;
  }
}
