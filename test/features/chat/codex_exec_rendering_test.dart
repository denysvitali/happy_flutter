import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/markdown/markdown_view.dart';
import 'package:happy_flutter/features/chat/message_detail_screen.dart';
import 'package:happy_flutter/features/chat/message_widget.dart';
import 'package:happy_flutter/features/chat/tools/json_viewer.dart';
import 'package:happy_flutter/features/chat/tools/known_tools.dart';
import 'package:happy_flutter/features/chat/tools/tool_status_indicator.dart';
import 'package:happy_flutter/features/chat/tools/tool_view_widgets.dart';
import 'package:happy_flutter/features/chat/tools/views/codex_exec_view.dart';
import 'package:happy_flutter/features/chat/tools/views/mcp_exec_view.dart';

const _answer =
    '**Build brief**: [build-brief.md](/var/tmp/spx-codex/build-brief.md)\n\n'
    '1. Review the numbered procedure.\n'
    '2. Resolve the missing make target before execution.';

Map<String, dynamic> _tool({String state = 'completed'}) => {
  'id': 'codex-call',
  'toolUseId': 'codex-call',
  'kind': 'tool-call',
  'name': 'mcp__codex__codex_exec',
  'state': state,
  'input': {
    'prompt': 'Research the build procedure',
    'cwd': '/var/tmp/spx-codex/typec-class',
    'model': 'gpt-6-luna',
  },
  if (state != 'running')
    'result': {
      'content': [
        {
          'type': 'text',
          'text': jsonEncode({
            'elapsed_ms': 54661,
            'exit_code': 0,
            'final_message': _answer,
            'raw_event_count': 23,
            'thread_id': 'thread-123',
            'usage': {
              'cached_input_tokens': 351744,
              'input_tokens': 409557,
              'output_tokens': 4146,
            },
          }),
        },
      ],
    },
};

Widget _app(Widget child) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);

Widget _wrap(Widget child) =>
    _app(Scaffold(body: SingleChildScrollView(child: child)));

Widget _message(Map<String, dynamic> tool) => _wrap(
  MessageWidget(messageData: tool, isFromCurrentUser: false, animate: false),
);

void main() {
  test('Codex header reads wrapped prompts without splitting emoji', () {
    final prompt = '${'a' * 79}🛠️more';
    final tool = {
      'input': {
        'arguments': {'prompt': prompt},
      },
    };
    final subtitle = KnownTools.get('mcp__codex__codex_exec')!.extractSubtitle!(
      tool,
      null,
    );
    expect(subtitle, '${'a' * 79}🛠️…');
  });

  testWidgets('chat shows attributed Markdown before opening tool config', (
    tester,
  ) async {
    final tool = _tool();
    final original = jsonEncode(tool);
    await tester.pumpWidget(_message(tool));

    expect(find.byType(CodexExecAnswerView), findsOneWidget);
    expect(find.text('Codex'), findsOneWidget);
    expect(
      tester
          .widget<SimpleMarkdownView>(find.byType(SimpleMarkdownView))
          .markdown,
      _answer,
    );
    expect(find.byType(CodexExecView), findsNothing);
    expect(find.byType(McpExecView), findsNothing);
    expect(find.text('No output'), findsNothing);
    expect(find.text('Research the build procedure'), findsNothing);

    await tester.tap(find.byType(ToolHeader));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CodexExecView), findsOneWidget);
    expect(find.byType(CodexExecAnswerView), findsOneWidget);
    expect(find.byType(SimpleMarkdownView), findsOneWidget);
    expect(find.text('Research the build procedure'), findsOneWidget);
    expect(jsonEncode(tool), original);

    await tester.tap(find.byType(ToolHeader));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.byType(CodexExecView), findsNothing);
    expect(find.byType(CodexExecAnswerView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('arriving completion adds the answer to an existing chat row', (
    tester,
  ) async {
    await tester.pumpWidget(_message(_tool(state: 'running')));
    expect(find.byType(CodexExecAnswerView), findsNothing);

    await tester.pumpWidget(_message(_tool()));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byType(CodexExecAnswerView), findsOneWidget);
    expect(find.byType(SimpleMarkdownView), findsOneWidget);
    expect(find.byType(CodexExecView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nonzero execution exit keeps its answer and failed status', (
    tester,
  ) async {
    final tool = _tool();
    tool['result'] = {'final_message': _answer, 'exit_code': 2};
    await tester.pumpWidget(_message(tool));
    expect(
      tester.widget<ToolHeader>(find.byType(ToolHeader)).state,
      ToolState.error,
    );
    expect(find.byType(CodexExecAnswerView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tool Details renders the answer and retains raw JSON', (
    tester,
  ) async {
    final tool = _tool();
    final original = jsonEncode(tool);
    await tester.pumpWidget(
      _app(
        MessageDetailScreen(
          messageData: tool,
          messageId: 'codex-call',
          sessionId: 'session-1',
        ),
      ),
    );
    expect(find.byType(CodexExecView), findsOneWidget);
    expect(find.byType(CodexExecAnswerView), findsOneWidget);
    expect(find.byType(McpExecView), findsNothing);
    expect(find.byType(JsonTreeViewer), findsNothing);

    final raw = find.text('Raw JSON');
    await tester.scrollUntilVisible(
      raw,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(raw);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(JsonTreeViewer), findsWidgets);
    expect(jsonEncode(tool), original);
    expect(tester.takeException(), isNull);
  });
}
