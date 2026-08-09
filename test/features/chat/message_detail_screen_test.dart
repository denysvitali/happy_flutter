import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/message_detail_screen.dart';
import 'package:happy_flutter/features/chat/tools/json_viewer.dart';

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

String _longOutput() =>
    List<int>.generate(300, (i) => i).map((i) => 'output line $i').join('\n');

ScrollableState _verticalScrollableIn(WidgetTester tester, Finder finder) {
  final states = tester
      .stateList<ScrollableState>(
        find.descendant(of: finder, matching: find.byType(Scrollable)),
      )
      .where(
        (state) =>
            state.position.axis == Axis.vertical &&
            state.position.maxScrollExtent > 0,
      )
      .toList(growable: false);
  expect(states, isNotEmpty);
  return states.first;
}

Future<void> _dragUpInside(WidgetTester tester, Finder finder) async {
  final gesture = await tester.startGesture(tester.getCenter(finder));
  for (var i = 0; i < 10; i++) {
    await gesture.moveBy(const Offset(0, -24));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MessageDetailScreen', () {
    testWidgets('keeps large tool output collapsed during route build', (
      tester,
    ) async {
      final output = List<String>.filled(2500, 'large-output-line').join('\n');

      await tester.pumpWidget(
        _wrap(
          MessageDetailScreen(
            sessionId: 's1',
            messageId: 'm-large',
            messageData: <String, dynamic>{
              'kind': 'tool-call',
              'name': 'CodexBash',
              'state': 'completed',
              'input': const <String, dynamic>{'command': 'generate output'},
              'result': <String, dynamic>{'exitCode': 0, 'stdout': output},
            },
          ),
        ),
      );

      expect(
        find.text('Large output kept collapsed for smooth opening'),
        findsOneWidget,
      );
      expect(_renderedText(tester), isNot(contains('large-output-line')));

      await tester.tap(
        find.text('Large output kept collapsed for smooth opening'),
      );
      await tester.pump();

      expect(_renderedText(tester), contains('large-output-line'));
      expect(find.text('1 / 4'), findsOneWidget);
    });

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

    testWidgets('renders command input maps as text in tool details', (
      tester,
    ) async {
      const command =
          '/bin/bash -lc "find opt/odin/odin_bundle/odin_bundle/networks '
          '-type f -name \'*.py\' -print0 | xargs -0 rg -l -- '
          r'\"odin-notoken-servicemode|odin-notoken-repair-and-maintenance|'
          r'odin-notoken-qtcar\" | wc -l"';

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
                'command': <String>[command],
                'parsed_cmd': <Map<String, dynamic>>[
                  <String, dynamic>{'cmd': command},
                ],
              },
              'result': <String, dynamic>{'exitCode': 0, 'stdout': '12\n'},
            },
          ),
        ),
      );

      final renderedText = _renderedText(tester);
      expect(
        renderedText,
        contains('find opt/odin/odin_bundle/odin_bundle/networks'),
      );
      expect(renderedText, contains('odin-notoken-servicemode'));
      expect(renderedText, isNot(contains('"parsed_cmd"')));
      expect(renderedText, isNot(contains('"command"')));
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

    testWidgets('output panel scrolls inside tool details', (tester) async {
      final output = _longOutput();

      await tester.pumpWidget(
        _wrap(
          MessageDetailScreen(
            sessionId: 's1',
            messageId: 'm1',
            messageData: <String, dynamic>{
              'kind': 'tool-call',
              'name': 'functions.exec_command',
              'state': 'completed',
              'input': <String, dynamic>{'cmd': 'long-output'},
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
      await tester.pumpAndSettle();

      final outputFrame = find.byType(ToolOutputScrollFrame).last;
      final pane = _verticalScrollableIn(tester, outputFrame);
      final before = pane.position.pixels;

      await _dragUpInside(tester, outputFrame);

      expect(pane.position.pixels, greaterThan(before));
    });

    testWidgets('output panel scrolls inside child tool detail sheet', (
      tester,
    ) async {
      final output = _longOutput();

      await tester.pumpWidget(
        _wrap(
          MessageDetailScreen(
            sessionId: 's1',
            messageId: 'm1',
            messageData: <String, dynamic>{
              'kind': 'tool-call',
              'name': 'Task',
              'state': 'completed',
              'input': <String, dynamic>{'description': 'inspect output'},
              'messages': <Map<String, dynamic>>[
                <String, dynamic>{
                  'kind': 'tool-call',
                  'name': 'functions.exec_command',
                  'state': 'completed',
                  'input': <String, dynamic>{'cmd': 'long-output'},
                  'result': <String, dynamic>{
                    'exitCode': 0,
                    'output': output,
                    'status': 'completed',
                    'stdout': output,
                  },
                },
              ],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Terminal', findRichText: true));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView).last, const Offset(0, -260));
      await tester.pumpAndSettle();

      final outputFrame = find.byType(ToolOutputScrollFrame).last;
      final pane = _verticalScrollableIn(tester, outputFrame);
      final before = pane.position.pixels;

      await _dragUpInside(tester, outputFrame);

      expect(pane.position.pixels, greaterThan(before));
    });
  });

  group('MessageDetailScreen — Codex MCP', () {
    const codexMessage = <String, dynamic>{
      'kind': 'tool-call',
      'name': 'mcp__codex__codex',
      'state': 'completed',
      'input': <String, dynamic>{
        'approval-policy': 'never',
        'cwd': '/repo/happy_flutter',
        'model': 'gpt-5.3-codex-spark',
        'sandbox': 'read-only',
        'prompt': 'Review the core files.\n\nRETURN: numbered findings.',
      },
      'result': <String, dynamic>{
        'content': <Map<String, dynamic>>[
          <String, dynamic>{'type': 'text', 'text': 'Verdict: looks good.'},
        ],
      },
    };

    testWidgets('renders pretty prompt + response instead of raw JSON', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const MessageDetailScreen(
            sessionId: 's1',
            messageId: 'm1',
            messageData: codexMessage,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header shows the friendly title.
      expect(find.text('Codex'), findsOneWidget);

      // Pretty body: config chips, cwd, full prompt, response.
      expect(find.text('gpt-5.3-codex-spark'), findsOneWidget);
      expect(find.text('read-only'), findsOneWidget);
      expect(find.text('never'), findsOneWidget);
      expect(find.text('/repo/happy_flutter'), findsOneWidget);
      expect(find.text('PROMPT'), findsOneWidget);
      expect(find.textContaining('Review the core files.'), findsOne);
      expect(find.textContaining('RETURN: numbered findings.'), findsOne);
      expect(find.text('RESPONSE'), findsOneWidget);
      expect(find.text('Verdict: looks good.'), findsOneWidget);

      // Raw JSON is collapsed: no JSON keys visible before expanding.
      expect(_renderedText(tester), isNot(contains('"prompt"')));
    });

    testWidgets('raw JSON disclosure reveals the wire payload', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MessageDetailScreen(
            sessionId: 's1',
            messageId: 'm1',
            messageData: codexMessage,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Raw JSON'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Raw JSON'));
      await tester.pumpAndSettle();

      final rendered = _renderedText(tester);
      expect(rendered, contains('"prompt"'));
      expect(rendered, contains('gpt-5.3-codex-spark'));
    });
  });
}
