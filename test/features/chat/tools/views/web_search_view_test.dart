import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/chat/tools/tool_view.dart';
import 'package:happy_flutter/features/chat/tools/views/web_search_view.dart';

class _DebugSettingsNotifier extends SettingsNotifier {
  @override
  Settings build() => Settings().copyWith(toolCallDebugEnabled: true);
}

class _SettingsNotifier extends SettingsNotifier {
  @override
  Settings build() => Settings();
}

Widget _wrap(Widget child, {bool debug = true}) {
  // The expanded ToolView with both INPUT and OUTPUT sections is taller than
  // the default 800x600 test viewport, so wrap the body in a scroll view to
  // avoid RenderFlex overflow assertions in tests.
  return ProviderScope(
    overrides: [
      settingsNotifierProvider.overrideWith(
        debug ? _DebugSettingsNotifier.new : _SettingsNotifier.new,
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

Widget _wrapBody(Widget child) {
  // WebSearchView reads context.l10n (AppLocalizations.of(context)!), so the
  // harness must register the localization delegates — without them the body
  // build throws a null-check TypeError and every finder returns nothing.
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('WebSearch renders its query as a compact summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ToolView(
          tool: {
            'name': 'WebSearch',
            'state': 'completed',
            'toolUseId': 'ws-direct',
            'input': {'query': ''},
            'result': {
              'action': {'query': 'Dart 3.11 release notes'},
              'result': {
                'sources': [
                  {
                    'title': 'Dart SDK changelog',
                    'url': 'https://dart.dev/guides/whats-new',
                  },
                ],
              },
            },
          },
        ),
        debug: false,
      ),
    );

    expect(
      find.textContaining('Dart 3.11 release notes', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Dart SDK changelog'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsNothing);
  });

  testWidgets('web_search renders as a compact first-class tool', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ToolView(
          tool: {
            'name': 'web_search',
            'state': 'completed',
            'toolUseId': 'ws1',
            'input': {'query': 'flutter release notes'},
            'result': {
              'action': {
                'type': 'search',
                'queries': ['flutter release notes'],
                'sources': [
                  {
                    'title': 'Flutter docs',
                    'url': 'https://docs.flutter.dev/release',
                    'snippet': 'Stable release notes.',
                  },
                ],
              },
            },
          },
        ),
      ),
    );

    expect(
      find.textContaining('Web Search', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('flutter release notes', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('web_search'), findsNothing);
    expect(find.text('INPUT'), findsNothing);
    expect(find.text('OUTPUT'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsNothing);
  });

  testWidgets('web_search_preview renders query and running state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ToolView(
          tool: {
            'name': 'web_search_preview',
            'state': 'running',
            'toolUseId': 'ws2',
            'input': {'query': 'weather today'},
          },
        ),
      ),
    );

    expect(
      find.textContaining('Web Search', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('weather today', findRichText: true),
      findsOneWidget,
    );
    // Running state stays understandable without colour or motion alone.
    expect(find.byIcon(Icons.autorenew_rounded), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('web_search_preview'), findsNothing);
    expect(find.text('INPUT'), findsNothing);
  });

  // ── WebSearchView body (rendered in the detail screen) ────────────────

  testWidgets('WebSearchView body shows expanded queries list', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapBody(
        WebSearchView(
          tool: {
            'name': 'WebSearch',
            'state': 'completed',
            'toolUseId': 'ws-queries',
            'input': {
              'query': 'CVE-2026-12015 chromium autofill',
              'action': {
                'type': 'search',
                'query': null,
                'queries': [
                  'CVE-2026-12015',
                  'chromium autofill use-after-free',
                  'CVE-2026-12015 patch',
                ],
              },
            },
          },
        ),
      ),
    );

    // Main query row.
    expect(
      find.textContaining(
        'CVE-2026-12015 chromium autofill',
        findRichText: true,
      ),
      findsOneWidget,
    );
    // Queries label + each expanded query.
    expect(find.text('Queries'), findsOneWidget);
    expect(find.text('CVE-2026-12015'), findsOneWidget);
    expect(
      find.text('chromium autofill use-after-free'),
      findsOneWidget,
    );
    expect(find.text('CVE-2026-12015 patch'), findsOneWidget);
  });

  testWidgets(
    'WebSearchView body shows no-results note when result envelope is empty',
    (tester) async {
      await tester.pumpWidget(
        _wrapBody(
          WebSearchView(
            tool: {
              'name': 'WebSearch',
              'state': 'completed',
              'toolUseId': 'ws-empty',
              'input': {
                'query': 'CVE-2026-12015',
                'action': {
                  'type': 'search',
                  'queries': ['CVE-2026-12015'],
                },
              },
              // Daemon emits {} for web_search items with no result pages
              // on the wire.
              'result': <String, dynamic>{},
            },
          ),
        ),
      );

      expect(
        find.textContaining(
          'result pages are not included in the transcript',
          findRichText: true,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('WebSearchView body hides no-results note while running', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapBody(
        WebSearchView(
          tool: {
            'name': 'WebSearch',
            'state': 'running',
            'toolUseId': 'ws-running',
            'input': {'query': 'weather today'},
          },
        ),
      ),
    );

    expect(
      find.textContaining(
        'result pages are not included in the transcript',
        findRichText: true,
      ),
      findsNothing,
    );
  });

  testWidgets('WebSearchView body renders source tiles when present', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapBody(
        WebSearchView(
          tool: {
            'name': 'WebSearch',
            'state': 'completed',
            'toolUseId': 'ws-sources',
            'input': {'query': 'flutter'},
            'result': {
              'sources': [
                {
                  'title': 'Flutter docs',
                  'url': 'https://docs.flutter.dev',
                  'snippet': 'Build apps from a single codebase.',
                },
              ],
            },
          },
        ),
      ),
    );

    expect(find.text('Flutter docs'), findsOneWidget);
    // The tile shows the host, not the full URL — the raw link read as
    // noise next to the title.
    expect(find.text('docs.flutter.dev'), findsOneWidget);
    expect(
      find.text('Build apps from a single codebase.'),
      findsOneWidget,
    );
    // No "not in transcript" note when sources are present.
    expect(
      find.textContaining(
        'result pages are not included in the transcript',
        findRichText: true,
      ),
      findsNothing,
    );
  });

  // ── Search MCP servers (JSON payload in MCP text content blocks) ──────

  /// The wire shape of an MCP tool result: the server's JSON response
  /// arrives as a string inside text content blocks.
  Map<String, dynamic> mcpResult(Object payload) => {
    'content': [
      {'type': 'text', 'text': jsonEncode(payload)},
    ],
  };

  final searchPayload = {
    'provider': 'all',
    'query': 'best React UI component library 2026',
    'results': [
      {
        'title': 'Best React Component Libraries (2026): 12 Options Ranked',
        'url': 'https://designrevision.com/blog/best-react-component-libraries',
        'description': 'A ranked comparison of the 12 best libraries.',
        'source': 'duckduckgo,marginalia,yahoo',
      },
      {
        'title': 'Best React UI Component Libraries in 2026: Complete Guide',
        'url': 'https://blocks.serp.co/blog/best-react-ui-libraries-2026',
        'description': 'A comprehensive comparison.',
        'source': 'duckduckgo,yahoo',
        'published': '2026-06-09',
      },
    ],
  };

  testWidgets('search MCP results render as source tiles, not raw JSON', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapBody(
        WebSearchView(
          tool: {
            'name': 'mcp__web-search__search',
            'state': 'completed',
            'toolUseId': 'mcp-1',
            'input': {'query': 'best React UI component library 2026'},
            'result': mcpResult(searchPayload),
          },
        ),
      ),
    );

    expect(
      find.text('Best React Component Libraries (2026): 12 Options Ranked'),
      findsOneWidget,
    );
    // Host + providers + date land in the muted meta row.
    expect(
      find.textContaining('designrevision.com', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('2026-06-09', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('A ranked comparison of the 12 best libraries.'),
        findsOneWidget);
  });

  testWidgets('batched search renders one group per query', (tester) async {
    await tester.pumpWidget(
      _wrapBody(
        WebSearchView(
          tool: {
            'name': 'mcp__web-search__search_batch',
            'state': 'completed',
            'toolUseId': 'mcp-batch',
            'result': mcpResult({
              'responses': [
                {
                  'query': 'riverpod 3 migration',
                  'results': [
                    {'title': 'Riverpod 3 guide', 'url': 'https://riverpod.dev'},
                  ],
                },
                {
                  'query': 'flutter 3.41 release notes',
                  'results': [
                    {'title': 'Flutter 3.41', 'url': 'https://docs.flutter.dev'},
                  ],
                },
              ],
            }),
          },
        ),
      ),
    );

    expect(find.text('riverpod 3 migration'), findsOneWidget);
    expect(find.text('flutter 3.41 release notes'), findsOneWidget);
    expect(find.text('Riverpod 3 guide'), findsOneWidget);
    expect(find.text('Flutter 3.41'), findsOneWidget);
  });

  test('canRenderMcpResult only claims search-shaped payloads', () {
    expect(WebSearchView.canRenderMcpResult(mcpResult(searchPayload)), isTrue);
    // A results list without URLs belongs to some other MCP tool.
    expect(
      WebSearchView.canRenderMcpResult(
        mcpResult({
          'results': [1, 2, 3],
        }),
      ),
      isFalse,
    );
    expect(
      WebSearchView.canRenderMcpResult(mcpResult({'status': 'ok'})),
      isFalse,
    );
    expect(WebSearchView.canRenderMcpResult('plain text output'), isFalse);
    expect(WebSearchView.canRenderMcpResult(null), isFalse);
  });

  testWidgets('ToolView routes a search MCP card to the source list', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ToolView(
          tool: {
            'name': 'mcp__web-search__search',
            'state': 'completed',
            'toolUseId': 'mcp-toolview',
            'input': {'query': 'best React UI component library 2026'},
            'result': mcpResult(searchPayload),
          },
        ),
        debug: false,
      ),
    );

    // Header summarizes the payload; body is behind a tap.
    expect(
      find.textContaining('15 results', findRichText: true),
      findsNothing,
    );
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(
      find.text('Best React Component Libraries (2026): 12 Options Ranked'),
      findsOneWidget,
    );
    // The raw JSON viewer no longer takes over the body.
    expect(find.textContaining('"provider"', findRichText: true), findsNothing);
  });
}
