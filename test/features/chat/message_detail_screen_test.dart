import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/message_detail_screen.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

String _renderedText(WidgetTester tester) {
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

  group('MessageDetailScreen', () {
    testWidgets('renders command result maps as text in tool details', (
      tester,
    ) async {
      const output =
          ' D ../__pycache__/harness.cpython-312.pyc\n'
          ' M ../chrome/run_headless_chromium.sh\n'
          '?? bin/\n'
          '?? work/service-shell-command.strings\n';

      await tester.pumpWidget(
        _wrap(
          const MessageDetailScreen(
            sessionId: 's1',
            messageId: 'm1',
            messageData: <String, dynamic>{
              'kind': 'tool-call',
              'name': 'CodexBash',
              'state': 'completed',
              'input': <String, dynamic>{
                'command': <String>['git status --short'],
              },
              'result': <String, dynamic>{
                'exitCode': 0,
                'output': output,
                'status': 'completed',
                'stdout': output,
              },
            },
          ),
        ),
      );

      final renderedText = _renderedText(tester);
      expect(renderedText, contains('D ../__pycache__'));
      expect(renderedText, contains('?? work/service-shell-command.strings'));
      expect(renderedText, isNot(contains('"stdout"')));
      expect(renderedText, isNot(contains('"exitCode"')));
    });

    testWidgets('renders ANSI in command result details', (tester) async {
      const output =
          '\x1B[36mINFO\x1B[0m[0000] conditions\r\n'
          '\x1B[31mFATA\x1B[0m[0000] missing file\r\n';

      await tester.pumpWidget(
        _wrap(
          const MessageDetailScreen(
            sessionId: 's1',
            messageId: 'm1',
            messageData: <String, dynamic>{
              'kind': 'tool-call',
              'name': 'functions.exec_command',
              'state': 'completed',
              'input': <String, dynamic>{'cmd': 'service-shell-command'},
              'result': <String, dynamic>{
                'exitCode': 1,
                'output': output,
                'status': 'failed',
                'stdout': output,
              },
            },
          ),
        ),
      );

      final renderedText = _renderedText(tester);
      expect(renderedText, contains('INFO'));
      expect(renderedText, contains('FATA'));
      expect(renderedText, isNot(contains('\x1B[')));
    });
  });
}
