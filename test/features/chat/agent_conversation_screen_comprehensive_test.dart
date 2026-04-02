import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/services/tts_service.dart';
import 'package:happy_flutter/features/chat/agent_conversation_screen.dart';
import 'package:happy_flutter/features/chat/tools/tool_status_indicator.dart';
import 'package:happy_flutter/features/chat/tools/tool_view.dart';

class _StorageFreeSettingsNotifier extends SettingsNotifier {
  @override
  Future<void> updateSetting<T>(String key, T value) async {
    final json = state.toJson();
    json[key] = value;
    state = Settings.fromJson(json);
  }
}

Widget _buildApp({
  required String sessionId,
  required String messageId,
  Map<String, dynamic>? taskData,
}) {
  return ProviderScope(
    overrides: [
      settingsNotifierProvider.overrideWith(
        () => _StorageFreeSettingsNotifier(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AgentConversationScreen(
        sessionId: sessionId,
        messageId: messageId,
        taskData: taskData,
      ),
    ),
  );
}

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
    sync.testSetSessionMessages('sess_1', const []);
    await TtsService().dispose();
  });

  group('AgentConversationScreen - initial state', () {
    testWidgets('shows "No messages yet" when task has no children', (
      tester,
    ) async {
      const sessionId = 'sess_1';
      const taskId = 'task_1';

      final taskData = <String, dynamic>{
        'id': taskId,
        'kind': 'tool-call',
        'name': 'Task',
        'state': 'completed',
        'input': <String, dynamic>{
          'description': 'Investigate issue',
        },
      };

      sync.testSetSessionMessages(sessionId, [taskData]);

      await tester.pumpWidget(
        _buildApp(
          sessionId: sessionId,
          messageId: taskId,
          taskData: taskData,
        ),
      );
      await tester.pump();

      expect(find.text('No messages yet'), findsOneWidget);
    });

    testWidgets('shows loading indicator when task is running with no children',
        (tester) async {
      const sessionId = 'sess_1';
      const taskId = 'task_2';

      final taskData = <String, dynamic>{
        'id': taskId,
        'kind': 'tool-call',
        'name': 'Task',
        'state': 'running',
        'input': <String, dynamic>{
          'description': 'Running task',
        },
      };

      sync.testSetSessionMessages(sessionId, [taskData]);

      await tester.pumpWidget(
        _buildApp(
          sessionId: sessionId,
          messageId: taskId,
          taskData: taskData,
        ),
      );
      await tester.pump();

      // Running task with no children shows progress indicators
      // (one in body, potentially one in app bar)
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows task description in app bar', (tester) async {
      const sessionId = 'sess_1';
      const taskId = 'task_3';

      final taskData = <String, dynamic>{
        'id': taskId,
        'kind': 'tool-call',
        'name': 'Task',
        'state': 'completed',
        'input': <String, dynamic>{
          'description': 'My task description',
        },
      };

      sync.testSetSessionMessages(sessionId, [taskData]);

      await tester.pumpWidget(
        _buildApp(
          sessionId: sessionId,
          messageId: taskId,
          taskData: taskData,
        ),
      );
      await tester.pump();

      expect(find.text('My task description'), findsOneWidget);
    });

    testWidgets('shows subagent type in app bar subtitle', (tester) async {
      const sessionId = 'sess_1';
      const taskId = 'task_4';

      final taskData = <String, dynamic>{
        'id': taskId,
        'kind': 'tool-call',
        'name': 'Task',
        'state': 'completed',
        'input': <String, dynamic>{
          'description': 'Explore codebase',
          'subagent_type': 'explore',
        },
      };

      sync.testSetSessionMessages(sessionId, [taskData]);

      await tester.pumpWidget(
        _buildApp(
          sessionId: sessionId,
          messageId: taskId,
          taskData: taskData,
        ),
      );
      await tester.pump();

      expect(find.text('Explore codebase'), findsOneWidget);
      expect(find.text('explore'), findsOneWidget);
    });

    testWidgets('falls back to prompt when description is missing',
        (tester) async {
      const sessionId = 'sess_1';
      const taskId = 'task_5';

      final taskData = <String, dynamic>{
        'id': taskId,
        'kind': 'tool-call',
        'name': 'Task',
        'state': 'completed',
        'input': <String, dynamic>{
          'prompt': 'Fallback prompt text',
        },
      };

      sync.testSetSessionMessages(sessionId, [taskData]);

      await tester.pumpWidget(
        _buildApp(
          sessionId: sessionId,
          messageId: taskId,
          taskData: taskData,
        ),
      );
      await tester.pump();

      expect(find.text('Fallback prompt text'), findsOneWidget);
    });
  });

  group('AgentConversationScreen - children rendering', () {
    testWidgets('renders text children messages', (tester) async {
      const sessionId = 'sess_1';
      const taskId = 'task_6';

      final taskData = <String, dynamic>{
        'id': taskId,
        'kind': 'tool-call',
        'name': 'Task',
        'state': 'completed',
        'input': <String, dynamic>{'description': 'Task'},
        'children': [
          {
            'id': 'child_1',
            'kind': 'text',
            'content': 'First subagent reply',
          },
          {
            'id': 'child_2',
            'kind': 'text',
            'content': 'Second subagent reply',
          },
        ],
      };

      sync.testSetSessionMessages(sessionId, [taskData]);

      await tester.pumpWidget(
        _buildApp(
          sessionId: sessionId,
          messageId: taskId,
          taskData: taskData,
        ),
      );
      await tester.pump();

      expect(find.text('First subagent reply'), findsOneWidget);
      expect(find.text('Second subagent reply'), findsOneWidget);
      expect(find.text('No messages yet'), findsNothing);
    });

    testWidgets('renders tool-call children', (tester) async {
      const sessionId = 'sess_1';
      const taskId = 'task_7';

      final taskData = <String, dynamic>{
        'id': taskId,
        'kind': 'tool-call',
        'name': 'Task',
        'state': 'completed',
        'input': <String, dynamic>{'description': 'Task'},
        'children': [
          {
            'id': 'child_tool_1',
            'kind': 'tool-call',
            'name': 'Read',
            'toolUseId': 'read_1',
            'state': 'completed',
            'input': <String, dynamic>{'file_path': '/tmp/test.txt'},
            'result': 'file contents',
          },
        ],
      };

      sync.testSetSessionMessages(sessionId, [taskData]);

      await tester.pumpWidget(
        _buildApp(
          sessionId: sessionId,
          messageId: taskId,
          taskData: taskData,
        ),
      );
      await tester.pump();

      // ToolView is now used for tool calls
      expect(find.byType(ToolView), findsOneWidget);
    });

    testWidgets('renders error children', (tester) async {
      const sessionId = 'sess_1';
      const taskId = 'task_8';

      final taskData = <String, dynamic>{
        'id': taskId,
        'kind': 'tool-call',
        'name': 'Task',
        'state': 'error',
        'input': <String, dynamic>{'description': 'Task'},
        'children': [
          {
            'id': 'child_err_1',
            'kind': 'error',
            'errorType': 'timeout',
            'errorMessage': 'Request timed out',
          },
        ],
      };

      sync.testSetSessionMessages(sessionId, [taskData]);

      await tester.pumpWidget(
        _buildApp(
          sessionId: sessionId,
          messageId: taskId,
          taskData: taskData,
        ),
      );
      await tester.pump();

      expect(find.text('timeout: Request timed out'), findsOneWidget);
    });

    testWidgets('renders thinking text children', (tester) async {
      const sessionId = 'sess_1';
      const taskId = 'task_9';

      final taskData = <String, dynamic>{
        'id': taskId,
        'kind': 'tool-call',
        'name': 'Task',
        'state': 'running',
        'input': <String, dynamic>{'description': 'Task'},
        'children': [
          {
            'id': 'child_think_1',
            'kind': 'text',
            'content': 'Processing...',
            'isThinking': true,
          },
        ],
      };

      sync.testSetSessionMessages(sessionId, [taskData]);

      await tester.pumpWidget(
        _buildApp(
          sessionId: sessionId,
          messageId: taskId,
          taskData: taskData,
        ),
      );
      await tester.pump();

      expect(find.text('Claude is thinking...'), findsOneWidget);
    });

    testWidgets('skips empty text content', (tester) async {
      const sessionId = 'sess_1';
      const taskId = 'task_10';

      final taskData = <String, dynamic>{
        'id': taskId,
        'kind': 'tool-call',
        'name': 'Task',
        'state': 'completed',
        'input': <String, dynamic>{'description': 'Task'},
        'children': [
          {
            'id': 'child_empty',
            'kind': 'text',
            'content': '',
          },
          {
            'id': 'child_valid',
            'kind': 'text',
            'content': 'Valid message',
          },
        ],
      };

      sync.testSetSessionMessages(sessionId, [taskData]);

      await tester.pumpWidget(
        _buildApp(
          sessionId: sessionId,
          messageId: taskId,
          taskData: taskData,
        ),
      );
      await tester.pump();

      expect(find.text('Valid message'), findsOneWidget);
    });

    testWidgets('renders mixed children types', (tester) async {
      const sessionId = 'sess_1';
      const taskId = 'task_11';

      final taskData = <String, dynamic>{
        'id': taskId,
        'kind': 'tool-call',
        'name': 'Task',
        'state': 'completed',
        'input': <String, dynamic>{'description': 'Mixed task'},
        'children': [
          {
            'id': 'c1',
            'kind': 'text',
            'content': 'Starting work',
          },
          {
            'id': 'c2',
            'kind': 'tool-call',
            'name': 'Bash',
            'toolUseId': 'bash_1',
            'state': 'completed',
            'input': <String, dynamic>{'command': 'ls'},
          },
          {
            'id': 'c3',
            'kind': 'text',
            'content': 'Done!',
          },
        ],
      };

      sync.testSetSessionMessages(sessionId, [taskData]);

      await tester.pumpWidget(
        _buildApp(
          sessionId: sessionId,
          messageId: taskId,
          taskData: taskData,
        ),
      );
      await tester.pump();

      expect(find.text('Starting work'), findsOneWidget);
      expect(find.text('Done!'), findsOneWidget);
    });
  });

  group('AgentConversationScreen - live updates', () {
    testWidgets('updates when new children stream in', (tester) async {
      const sessionId = 'sess_1';
      const taskId = 'task_12';

      final initialTask = <String, dynamic>{
        'id': taskId,
        'kind': 'tool-call',
        'name': 'Task',
        'state': 'running',
        'input': <String, dynamic>{'description': 'Live task'},
      };

      sync.testSetSessionMessages(sessionId, [initialTask]);

      await tester.pumpWidget(
        _buildApp(
          sessionId: sessionId,
          messageId: taskId,
          taskData: initialTask,
        ),
      );
      await tester.pump();

      // Running task with no children shows a loading indicator
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Simulate new children arriving
      sync.testSetSessionMessages(sessionId, [
        {
          ...initialTask,
          'children': [
            {
              'id': 'live_child_1',
              'kind': 'text',
              'content': 'Streaming response...',
            },
          ],
        },
      ]);
      sync.testNotifySessionMessagesChanged(sessionId);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('No messages yet'), findsNothing);
      expect(find.text('Streaming response...'), findsOneWidget);
    });

    testWidgets('shows progress indicator in app bar when running', (
      tester,
    ) async {
      const sessionId = 'sess_1';
      const taskId = 'task_13';

      final taskData = <String, dynamic>{
        'id': taskId,
        'kind': 'tool-call',
        'name': 'Task',
        'state': 'running',
        'input': <String, dynamic>{'description': 'Running task'},
      };

      sync.testSetSessionMessages(sessionId, [taskData]);

      await tester.pumpWidget(
        _buildApp(
          sessionId: sessionId,
          messageId: taskId,
          taskData: taskData,
        ),
      );
      await tester.pump();

      // Running state shows a CircularProgressIndicator in the app bar
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });

  group('AgentConversationScreen - tool states', () {
    testWidgets('shows running tool state indicator', (tester) async {
      const sessionId = 'sess_1';
      const taskId = 'task_14';

      final taskData = <String, dynamic>{
        'id': taskId,
        'kind': 'tool-call',
        'name': 'Task',
        'state': 'running',
        'input': <String, dynamic>{'description': 'Task'},
        'children': [
          {
            'id': 'tool_running',
            'kind': 'tool-call',
            'name': 'Bash',
            'toolUseId': 'bash_r',
            'state': 'running',
            'input': <String, dynamic>{'command': 'sleep 5'},
          },
        ],
      };

      sync.testSetSessionMessages(sessionId, [taskData]);

      await tester.pumpWidget(
        _buildApp(
          sessionId: sessionId,
          messageId: taskId,
          taskData: taskData,
        ),
      );
      await tester.pump();

      // ToolView is now used for tool calls
      expect(find.byType(ToolView), findsOneWidget);
    });

    testWidgets('shows error tool state indicator', (tester) async {
      const sessionId = 'sess_1';
      const taskId = 'task_15';

      final taskData = <String, dynamic>{
        'id': taskId,
        'kind': 'tool-call',
        'name': 'Task',
        'state': 'error',
        'input': <String, dynamic>{'description': 'Task'},
        'children': [
          {
            'id': 'tool_error',
            'kind': 'tool-call',
            'name': 'Bash',
            'toolUseId': 'bash_e',
            'state': 'error',
            'input': <String, dynamic>{'command': 'fail'},
          },
        ],
      };

      sync.testSetSessionMessages(sessionId, [taskData]);

      await tester.pumpWidget(
        _buildApp(
          sessionId: sessionId,
          messageId: taskId,
          taskData: taskData,
        ),
      );
      await tester.pump();

      // ToolView is now used for tool calls
      expect(find.byType(ToolView), findsOneWidget);
    });

    testWidgets('shows pending tool state indicator', (tester) async {
      const sessionId = 'sess_1';
      const taskId = 'task_16';

      final taskData = <String, dynamic>{
        'id': taskId,
        'kind': 'tool-call',
        'name': 'Task',
        'state': 'pending',
        'input': <String, dynamic>{'description': 'Task'},
        'children': [
          {
            'id': 'tool_pending',
            'kind': 'tool-call',
            'name': 'Write',
            'toolUseId': 'write_p',
            'state': 'pending',
            'input': <String, dynamic>{
              'file_path': '/tmp/out.txt',
              'content': 'data',
            },
          },
        ],
      };

      sync.testSetSessionMessages(sessionId, [taskData]);

      await tester.pumpWidget(
        _buildApp(
          sessionId: sessionId,
          messageId: taskId,
          taskData: taskData,
        ),
      );
      await tester.pump();

      // ToolView is now used for tool calls
      expect(find.byType(ToolView), findsOneWidget);
    });
  });

  group('TaskView - text message preview', () {
    testWidgets('shows most recent text message from children', (
      tester,
    ) async {
      final taskData = <String, dynamic>{
        'id': 'task_tv_1',
        'kind': 'tool-call',
        'name': 'Task',
        'state': 'completed',
        'input': <String, dynamic>{
          'description': 'Explore codebase',
          'subagent_type': 'explore',
        },
        'children': [
          {
            'id': 'c1',
            'kind': 'text',
            'content': 'First message from agent',
          },
          {
            'id': 'c2',
            'kind': 'tool-call',
            'name': 'Read',
            'toolUseId': 'read_1',
            'state': 'completed',
            'input': <String, dynamic>{'file_path': '/tmp/test.txt'},
          },
          {
            'id': 'c3',
            'kind': 'text',
            'content': 'Second message from agent',
          },
        ],
      };

      await tester.pumpWidget(
        _buildApp(
          sessionId: 'sess_tv',
          messageId: 'task_tv_1',
          taskData: taskData,
        ),
      );
      await tester.pump();

      // TaskView is rendered inside the agent conversation
      // screen's initial state
      expect(find.text('Second message from agent'), findsOneWidget);
    });
  });
}
