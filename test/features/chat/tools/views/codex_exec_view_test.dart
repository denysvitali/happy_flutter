import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/tool_view_buttons.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/markdown/markdown_view.dart';
import 'package:happy_flutter/features/chat/tools/codex_exec_result.dart';
import 'package:happy_flutter/features/chat/tools/views/codex_exec_view.dart';

const _answer =
    '## Build plan\n\n'
    '[build-brief.md](/var/tmp/spx-codex/build-brief.md) contains **the plan**.';

Map<String, dynamic> _tool({String answer = _answer, int exitCode = 0}) => {
  'name': 'mcp__codex__codex_exec',
  'state': 'completed',
  'input': {
    'arguments': {
      'prompt': 'Create a build brief.',
      'model': 'gpt-6.1-sol',
      'cwd': '/var/tmp/spx-codex',
      'sandbox': 'workspace-write',
      'approval_policy': 'never',
    },
  },
  'result': {
    'final_message': answer,
    'elapsed_ms': 54661,
    'exit_code': exitCode,
    'raw_event_count': 23,
    'thread_id': 'codex-thread',
    'usage': {
      'cached_input_tokens': 351744,
      'input_tokens': 409557,
      'output_tokens': 4146,
    },
  },
};

Widget _wrap(Widget child, {double textScale = 1}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

String _renderedText(WidgetTester tester) => [
  ...tester
      .widgetList<RichText>(find.byType(RichText))
      .map((widget) => widget.text.toPlainText()),
  ...tester
      .widgetList<SelectableText>(find.byType(SelectableText))
      .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? ''),
].join('\n');

void main() {
  testWidgets('attributes the answer and renders Markdown without metadata', (
    tester,
  ) async {
    final result = CodexExecResult.tryParse(_tool()['result'])!;
    await tester.pumpWidget(_wrap(CodexExecAnswerView(result: result)));
    expect(find.text('Codex'), findsOneWidget);
    expect(find.byType(SimpleMarkdownView), findsOneWidget);
    final body = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(body.data, _answer);
    expect(body.onTapLink, isNotNull);
    final text = _renderedText(tester);
    expect(text, contains('Build plan'));
    expect(text, contains('build-brief.md'));
    expect(text, isNot(contains('##')));
    expect(text, isNot(contains('**')));
    expect(text, isNot(contains('final_message')));
    expect(text, isNot(contains('54661')));
    expect(text, isNot(contains('codex-thread')));
  });

  testWidgets('Copy receives the Markdown answer alone', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      _wrap(
        CodexExecAnswerView(
          result: CodexExecResult.tryParse(_tool()['result'])!,
        ),
      ),
    );
    expect(
      tester.widget<ToolViewCopyButton>(find.byType(ToolViewCopyButton)).text,
      _answer,
    );
    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();
    expect(copied, _answer);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('details show prompt, config and execution metadata', (
    tester,
  ) async {
    final tool = _tool();
    final before = jsonEncode(tool);
    await tester.pumpWidget(_wrap(CodexExecView(tool: tool)));
    final text = _renderedText(tester);
    for (final value in [
      'Create a build brief.',
      'gpt-6.1-sol',
      '/var/tmp/spx-codex',
      'workspace-write',
      'never',
      'Exit 0',
      'Elapsed 54.7 s',
      '23 events',
      'codex-thread',
      '409557',
      '351744',
      '4146',
    ]) {
      expect(text, contains(value));
    }
    expect(find.byType(SimpleMarkdownView), findsOneWidget);
    expect(jsonEncode(tool), before);
  });

  testWidgets('details can exclude the independently visible answer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(CodexExecView(tool: _tool(), showAnswer: false)),
    );
    expect(find.byType(CodexExecAnswerView), findsNothing);
    expect(find.byType(SimpleMarkdownView), findsNothing);
    expect(_renderedText(tester), contains('Input tokens'));
  });

  testWidgets('empty answers do not create an answer label or Copy action', (
    tester,
  ) async {
    for (final answer in ['', ' \n ']) {
      await tester.pumpWidget(
        _wrap(
          CodexExecAnswerView(
            result: CodexExecResult(finalMessage: answer, exitCode: 0),
          ),
        ),
      );
      expect(find.text('Codex'), findsNothing);
      expect(find.byType(SimpleMarkdownView), findsNothing);
      expect(find.byType(ToolViewCopyButton), findsNothing);
    }
    await tester.pumpWidget(_wrap(CodexExecView(tool: _tool(answer: ''))));
    expect(
      find.text('Codex completed without a final answer.'),
      findsOneWidget,
    );
    expect(find.byType(SimpleMarkdownView), findsNothing);
    expect(find.text('Exit 0'), findsOneWidget);
  });

  testWidgets('failed execution keeps a reported answer and failure status', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(CodexExecView(tool: _tool(exitCode: 2))));
    expect(find.text('Codex execution failed (exit 2).'), findsOneWidget);
    expect(find.text('Exit 2'), findsOneWidget);
    expect(find.byType(SimpleMarkdownView), findsOneWidget);
  });

  testWidgets('transport failure shows its text without inventing an answer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        CodexExecView(
          tool: {
            'state': 'error',
            'result': {
              'content': [
                {'type': 'text', 'text': 'Could not start Codex.'},
              ],
            },
          },
        ),
      ),
    );
    expect(find.text('Codex execution failed.'), findsOneWidget);
    expect(_renderedText(tester), contains('Could not start Codex.'));
    expect(find.byType(SimpleMarkdownView), findsNothing);
  });

  testWidgets('running and malformed results have explicit status', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const CodexExecView(tool: {'state': 'running'})),
    );
    expect(find.text('Codex is working…'), findsOneWidget);
    await tester.pumpWidget(
      _wrap(
        const CodexExecView(
          tool: {'state': 'completed', 'result': '{malformed json'},
        ),
      ),
    );
    expect(
      find.text('No readable Codex answer. See Tool Details for the result.'),
      findsOneWidget,
    );
    expect(find.byType(SimpleMarkdownView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wraps long configuration at narrow width and larger text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final tool = _tool();
    final input =
        (tool['input'] as Map<String, dynamic>)['arguments']
            as Map<String, dynamic>;
    input['cwd'] = '/very/long/path/${'directory/' * 20}';
    input['model'] = 'a-model-name-${'long-' * 25}';
    await tester.pumpWidget(_wrap(CodexExecView(tool: tool), textScale: 1.8));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(SimpleMarkdownView), findsOneWidget);
    expect(find.text('Working directory'), findsOneWidget);
  });

  testWidgets('bounds prompt and error display while Copy keeps full prompt', (
    tester,
  ) async {
    final prompt = '${'👨‍👩‍👧‍👦' * 4100}prompt-tail';
    await tester.pumpWidget(
      _wrap(
        CodexExecView(
          tool: {
            'state': 'error',
            'input': {'prompt': prompt},
            'result': '${'error ' * 2000}error-tail',
          },
        ),
      ),
    );
    expect(
      find.text('Full prompt available via Copy or Raw JSON.'),
      findsOneWidget,
    );
    expect(find.text('Full error available in Raw JSON.'), findsOneWidget);
    expect(
      tester.widget<ToolViewCopyButton>(find.byType(ToolViewCopyButton)).text,
      prompt,
    );
    final displayed = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((widget) => widget.data ?? '')
        .toList();
    expect(displayed, contains('${'👨‍👩‍👧‍👦' * 4000}…'));
    expect(displayed.join(), isNot(contains('prompt-tail')));
    expect(displayed.join(), isNot(contains('error-tail')));
    expect(tester.takeException(), isNull);
  });
}
