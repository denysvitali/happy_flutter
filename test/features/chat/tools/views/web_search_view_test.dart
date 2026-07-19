import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/chat/tools/tool_view.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('WebSearch renders its query and nested sources', (tester) async {
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

    expect(find.text('Dart 3.11 release notes'), findsOneWidget);
    expect(find.text('Dart SDK changelog'), findsOneWidget);
  });

  testWidgets('web_search renders as raw tool call (no special case)', (
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

    // Codex web_search no longer has a special "Web Search" title —
    // the header shows the raw tool name.
    expect(find.text('Web Search'), findsNothing);
    expect(find.text('web_search'), findsOneWidget);
    await tester.tap(find.text('web_search'));
    await tester.pumpAndSettle();

    // Input/output payloads are rendered through JsonTreeViewer, which
    // joins each key, colon, and primitive value into a single RichText
    // (e.g. `"title": "Flutter docs"`). `find.text` matches the whole
    // plain text of a RichText, so use `find.textContaining` to assert
    // the value substring is present somewhere in the rendered tree.
    expect(
      find.textContaining('"flutter release notes"', findRichText: true),
      findsWidgets,
    );
    expect(
      find.textContaining('"Flutter docs"', findRichText: true),
      findsWidgets,
    );
    expect(find.text('INPUT'), findsOneWidget);
    expect(find.text('OUTPUT'), findsOneWidget);
  });

  testWidgets('web_search_preview renders as raw tool call', (tester) async {
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

    // Tap the header to expand — running tools no longer auto-expand.
    await tester.tap(find.text('web_search_preview'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Web Search'), findsNothing);
    expect(find.text('web_search_preview'), findsOneWidget);
    expect(
      find.textContaining('"weather today"', findRichText: true),
      findsWidgets,
    );
    expect(find.text('INPUT'), findsOneWidget);
  });
}
