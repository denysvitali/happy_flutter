import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/services/tts_service.dart';
import 'package:happy_flutter/features/chat/agent_conversation_screen.dart';
import 'package:happy_flutter/features/chat/tools/tool_status_indicator.dart';

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
          {
            'id': 'child_text_1',
            'kind': 'text',
            'content': 'Subagent reply',
          },
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
    expect(find.text('Read File'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ToolStatusIndicator &&
            widget.state == ToolState.completed,
      ),
      findsWidgets,
    );
  });
}
