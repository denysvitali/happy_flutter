import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/services/tts_service.dart';
import 'package:happy_flutter/features/chat/agent_conversation_screen.dart';
import 'package:happy_flutter/features/chat/tools/tool_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ttsChannel = MethodChannel('flutter_tts');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async => 1);
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
    await TtsService().dispose();
  });

  tearDown(() async {
    sync.testSetSessionMessages('session_1', const []);
    await TtsService().dispose();
  });

  testWidgets('renders streamed subagent children after session update', (
    tester,
  ) async {
    const sessionId = 'session_1';
    const taskId = 'task_1';

    final initialTask = <String, dynamic>{
      'id': taskId,
      'kind': 'tool-call',
      'name': 'Task',
      'state': 'completed',
      'input': <String, dynamic>{
        'description': 'Investigate issue',
        'subagent_type': 'explore',
      },
    };

    sync.testSetSessionMessages(sessionId, [initialTask]);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AgentConversationScreen(
            sessionId: sessionId,
            messageId: taskId,
            taskData: initialTask,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No messages yet'), findsOneWidget);

    sync.testSetSessionMessages(sessionId, [
      {
        ...initialTask,
        'children': [
          {'id': 'child_text_1', 'kind': 'text', 'content': 'Subagent reply'},
          {
            'id': 'child_tool_1',
            'kind': 'tool-call',
            'name': 'Read',
            'toolUseId': 'read_tool_1',
            'state': 'completed',
            'input': <String, dynamic>{'file_path': '/tmp/test.txt'},
            'result': 'file contents',
          },
        ],
      },
    ]);
    sync.testNotifySessionMessagesChanged(sessionId);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('No messages yet'), findsNothing);
    expect(find.text('Subagent reply'), findsOneWidget);
    // ToolView is now used instead of compact rows
    expect(find.byType(ToolView), findsOneWidget);
  });

  // Regression: a completed async/background agent never streams its inner
  // tool calls across the wire, so its sidechain carries ONLY task_progress
  // chips (kind: agent-event). The session list counts those as "N steps",
  // but the detail screen used to drop every chip once the agent finished
  // and fall through to the async-launch receipt — so the user tapped
  // "8 steps" and saw nothing. The chips are the steps; keep them.
  testWidgets(
    'shows progress chips as steps for a chips-only completed agent',
    (tester) async {
      const sessionId = 'session_1';
      const taskId = 'task_async';
      const launchReceipt =
          'Async agent launched successfully. (This tool result is '
          'internal metadata — never quote or paste any part of it';

      final task = <String, dynamic>{
        'id': taskId,
        'kind': 'tool-call',
        'name': 'Agent',
        'state': 'completed',
        'input': <String, dynamic>{
          'description': 'Hunt rebuild storms',
          'subagent_type': 'Explore',
        },
        // The async-launch stub — NOT a useful outcome; must not be what
        // the user sees when the activity feed would otherwise be empty.
        'result': launchReceipt,
        'children': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'te_1',
            'kind': 'agent-event',
            'taskEvent': true,
            'subAgentLastTool': 'Read',
            'event': <String, dynamic>{
              'type': 'message',
              'message': 'Read · lib/main.dart',
            },
          },
          <String, dynamic>{
            'id': 'te_2',
            'kind': 'agent-event',
            'taskEvent': true,
            'subAgentLastTool': 'Bash',
            'event': <String, dynamic>{
              'type': 'message',
              'message': 'Bash · grep render',
            },
          },
        ],
      };

      sync.testSetSessionMessages(sessionId, [task]);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AgentConversationScreen(
              sessionId: sessionId,
              messageId: taskId,
              taskData: task,
            ),
          ),
        ),
      );
      await tester.pump();

      // The steps (progress chips) are visible...
      expect(find.text('Read · lib/main.dart'), findsOneWidget);
      expect(find.text('Bash · grep render'), findsOneWidget);
      // ...instead of the empty-state or the useless launch receipt.
      expect(find.text('No messages yet'), findsNothing);
      expect(find.textContaining('Async agent launched'), findsNothing);
    },
  );

  testWidgets('finds parent message by toolUseId and renders children', (
    tester,
  ) async {
    const sessionId = 'session_1';
    const taskId = 'task_1';
    const toolUseId = 'toolu_task_1';

    final initialTask = <String, dynamic>{
      'id': taskId,
      'toolUseId': toolUseId,
      'kind': 'tool-call',
      'name': 'Task',
      'state': 'completed',
      'input': <String, dynamic>{
        'description': 'Investigate issue',
        'subagent_type': 'explore',
      },
      'children': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'child_text_1',
          'kind': 'text',
          'content': 'Found via toolUseId',
        },
      ],
    };

    sync.testSetSessionMessages(sessionId, [initialTask]);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AgentConversationScreen(
            sessionId: sessionId,
            messageId: toolUseId,
            taskData: initialTask,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('No messages yet'), findsNothing);
    expect(find.text('Found via toolUseId'), findsOneWidget);
  });

  testWidgets('hides the async launch receipt and shows a background note', (
    tester,
  ) async {
    const sessionId = 'session_1';
    const taskId = 'task_async_bg';
    // The exact internal-metadata receipt shape the SDK emits for a
    // background Task — the body the app must never render verbatim.
    const launchReceipt =
        'Async agent launched successfully. (This tool '
        'result is internal metadata — never quote or paste any part of it, '
        'including the agentId below, into a user-facing reply.) agentId: '
        'aea4b51f119897464 ... output_file: /tmp/claude-1000/x.output Do NOT '
        'Read or tail this file via the shell tool.';

    final task = <String, dynamic>{
      'id': taskId,
      'kind': 'tool-call',
      'name': 'Task',
      'state': 'completed',
      'input': <String, dynamic>{
        'description': 'Binary audit OnHttp3Datagram CFI',
        'subagent_type': 'general-purpose',
        'run_in_background': true,
      },
      'result': launchReceipt,
    };

    sync.testSetSessionMessages(sessionId, [task]);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AgentConversationScreen(
            sessionId: sessionId,
            messageId: taskId,
            taskData: task,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // The internal-metadata receipt must never be the body.
    expect(find.textContaining('Async agent launched'), findsNothing);
    expect(find.textContaining('internal metadata'), findsNothing);
    // A completed background agent with no streamed steps gets the honest
    // note, not a misleading "no messages yet".
    expect(find.text('Background agent'), findsOneWidget);
    expect(find.text('No messages yet'), findsNothing);
  });
}
