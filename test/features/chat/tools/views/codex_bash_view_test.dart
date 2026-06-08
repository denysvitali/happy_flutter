import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/views/codex_bash_view.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

String _richTextContent(WidgetTester tester) {
  return tester
      .widgetList<RichText>(find.byType(RichText))
      .map((widget) => widget.text.toPlainText())
      .join('\n');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CodexBashView', () {
    testWidgets('renders stdout and toggles raw JSON', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CodexBashView(
            tool: {
              'input': {
                'command': [
                  '/bin/bash -lc '
                      "'devenv shell -- flutter test test/foo_test.dart'",
                ],
                'parsed_cmd': [
                  {
                    'cmd':
                        '/bin/bash -lc '
                        "'devenv shell -- flutter test test/foo_test.dart'",
                  },
                ],
              },
              'state': 'completed',
              'result': {
                'exitCode': 0,
                'output': '00:01 +20: All tests passed!\n',
                'status': 'completed',
                'stdout': '00:01 +20: All tests passed!\n',
              },
            },
          ),
        ),
      );

      expect(
        find.textContaining('devenv shell -- flutter test'),
        findsOneWidget,
      );
      expect(find.text('stdout'), findsOneWidget);
      expect(find.textContaining('All tests passed!'), findsOneWidget);
      expect(find.text('exit 0'), findsOneWidget);
      expect(find.text('Show JSON'), findsOneWidget);
      expect(find.textContaining('"exitCode"'), findsNothing);

      await tester.tap(find.text('Show JSON'));
      await tester.pumpAndSettle();

      expect(find.text('Hide JSON'), findsOneWidget);
      expect(_richTextContent(tester), contains('"exitCode"'));
    });
  });
}
