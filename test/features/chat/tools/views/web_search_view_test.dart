import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

Widget _wrapBody(Widget child) {
  return ProviderScope(
    child: MaterialApp(
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
    // Running state is a quiet spinner, not a text pill.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Running'), findsNothing);
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
    expect(find.text('https://docs.flutter.dev'), findsOneWidget);
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
}
