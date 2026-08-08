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
  final richText = tester
      .widgetList<RichText>(find.byType(RichText))
      .map((widget) => widget.text.toPlainText())
      .join('\n');
  final selectableText = tester
      .widgetList<SelectableText>(find.byType(SelectableText))
      .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
      .join('\n');
  return '$richText\n$selectableText';
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
                  '/bin/sh -lc '
                      "'mise exec -- flutter test test/foo_test.dart'",
                ],
                'parsed_cmd': [
                  {
                    'cmd':
                        '/bin/sh -lc '
                        "'mise exec -- flutter test test/foo_test.dart'",
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

      expect(find.textContaining('mise exec -- flutter test'), findsOneWidget);
      expect(find.textContaining('/bin/sh -lc'), findsNothing);
      expect(find.text('stdout'), findsOneWidget);
      expect(find.textContaining('All tests passed!'), findsOneWidget);
      expect(find.text('exit 0'), findsOneWidget);
      // Raw JSON toggle removed; only the text sections are rendered.
      expect(find.text('Show JSON'), findsNothing);
      expect(find.text('Hide JSON'), findsNothing);
      expect(_richTextContent(tester), isNot(contains('"exitCode"')));
    });

    testWidgets('renders ANSI escape sequences as styled text', (tester) async {
      const output =
          '\x1B[36mINFO\x1B[0m[0000] conditions '
          '\x1B[36mdelivered\x1B[0m=false '
          '\x1B[36mfactory-gated\x1B[0m=false '
          '\x1B[36mfused\x1B[0m=false\r\n'
          '\x1B[31mFATA\x1B[0m[0000] open '
          '/etc/service-shell/principals.d/tcp: '
          'no such file or directory \r\n';

      await tester.pumpWidget(
        _wrap(
          CodexBashView(
            tool: {
              'input': {
                'command': ['service-shell-command'],
                'parsed_cmd': [
                  {'cmd': 'service-shell-command'},
                ],
              },
              'state': 'completed',
              'result': {
                'exitCode': 1,
                'output': output,
                'status': 'failed',
                'stdout': output,
              },
            },
          ),
        ),
      );

      final renderedText = _richTextContent(tester);
      expect(renderedText, contains('INFO'));
      expect(renderedText, contains('FATA'));
      expect(renderedText, contains('/etc/service-shell/principals.d/tcp'));
      expect(renderedText, isNot(contains('\x1B[')));
      expect(find.text('exit 1'), findsOneWidget);
    });
  });
}
