import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/tools/tool_view.dart';

Widget _wrap(Widget child) {
  // The expanded ToolView with both INPUT and OUTPUT sections is taller than
  // the default 800x600 test viewport, so wrap the body in a scroll view to
  // avoid RenderFlex overflow assertions in tests.
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('web_search uses normal tool call sections', (tester) async {
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

  testWidgets('web_search_preview alias uses normal tool call sections', (
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

    expect(find.text('Web Search'), findsOneWidget);
    expect(
      find.textContaining('"weather today"', findRichText: true),
      findsWidgets,
    );
    expect(find.text('INPUT'), findsOneWidget);
  });
}
