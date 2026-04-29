import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/tools/tool_view.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('web_search uses the dedicated web search view', (tester) async {
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

    expect(find.text('Web Search'), findsOneWidget);
    await tester.tap(find.text('Web Search'));
    await tester.pumpAndSettle();

    expect(find.text('flutter release notes'), findsWidgets);
    expect(find.text('Flutter docs'), findsOneWidget);
    expect(find.text('INPUT'), findsNothing);
    expect(find.text('OUTPUT'), findsNothing);
  });

  testWidgets('web_search_preview alias uses web search view', (tester) async {
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

    expect(find.text('Web Search'), findsOneWidget);
    expect(find.text('weather today'), findsWidgets);
    expect(find.text('Searching the web...'), findsOneWidget);
    expect(find.text('INPUT'), findsNothing);
  });
}
