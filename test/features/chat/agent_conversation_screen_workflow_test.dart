import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/models/workflow_run.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/services/tts_service.dart';
import 'package:happy_flutter/features/chat/agent_conversation_screen.dart';

// Regression coverage for the empty-Workflow-agent bug: a `Workflow` tool
// call's inner transcript never reaches the session message stream (the
// daemon keeps it in wf_<runId>.json), so the grouped `children` only carry
// transient task_* events. The screen must resolve the run from the sync
// cache and embed the workflow-run body instead of showing "No messages yet".

const _sessionId = 'sess_wf';
const _taskId = 'toolu_wf';
const _runId = 'wf_test';

class _StorageFreeSettingsNotifier extends SettingsNotifier {
  @override
  Future<void> updateSetting<T>(String key, T value) async {
    final json = state.toJson();
    json[key] = value;
    state = Settings.fromJson(json);
  }
}

Widget _buildApp({required Map<String, dynamic> taskData}) => ProviderScope(
  overrides: [
    settingsNotifierProvider.overrideWith(() => _StorageFreeSettingsNotifier()),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: AgentConversationScreen(
      sessionId: _sessionId,
      messageId: _taskId,
      taskData: taskData,
    ),
  ),
);

// A Workflow tool-call message with NO transcript children (the real wire
// shape: only transient task_* events, which the screen drops when finished).
Map<String, dynamic> _workflowTaskData({String state = 'completed'}) =>
    <String, dynamic>{
      'id': _taskId,
      'kind': 'tool-call',
      'name': 'Workflow',
      'state': state,
      'workflowRunId': _runId,
      'model': 'qwen3.8-max-preview',
      'input': <String, dynamic>{'script': 'export const meta = {}'},
    };

WorkflowRun _runWithAgent() => WorkflowRun(
  runId: _runId,
  workflowName: 'finalize',
  status: 'completed',
  workflowProgress: <WorkflowProgressEvent>[
    WorkflowPhaseEvent(index: 1, title: 'Recon', kind: 'done'),
    WorkflowAgent(
      agentId: 'a1',
      label: 'recon:offsets',
      phaseIndex: 1,
      phaseTitle: 'Recon',
      model: 'm',
      state: 'done',
      resultPreview: 'pinned offsets',
    ),
  ],
);

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
    sync
      ..testSetSessionMessages(_sessionId, const <Map<String, dynamic>>[])
      ..testSetWorkflows(_sessionId, const <WorkflowRun>[]);
    await TtsService().dispose();
  });

  testWidgets(
    'embeds the workflow run (agents) instead of "No messages yet"',
    (tester) async {
      sync.testSetWorkflows(_sessionId, <WorkflowRun>[_runWithAgent()]);
      final taskData = _workflowTaskData();
      sync.testSetSessionMessages(_sessionId, <Map<String, dynamic>>[taskData]);

      await tester.pumpWidget(_buildApp(taskData: taskData));
      await tester.pump();

      // The agent from the resolved run renders...
      expect(find.text('recon:offsets'), findsOneWidget);
      // ...and the dead-end empty state is gone.
      expect(find.text('No messages yet'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'parses the run id from the launch receipt when no tag is present',
    (tester) async {
      // The real wire shape that produced the "useless receipt" screen: the
      // Workflow tool message carries no `workflowRunId` tag (the task_*
      // sidechain events never grouped under it), but its tool result echoes
      // `Run ID: wf_…`. The screen must parse that id and embed the run.
      const liveRunId = 'wf_6551c046-249';
      sync.testSetWorkflows(
        _sessionId,
        <WorkflowRun>[
          WorkflowRun(
            runId: liveRunId,
            workflowName: 'finalize-mp-browser-rce',
            status: 'completed',
            workflowProgress: <WorkflowProgressEvent>[
              WorkflowAgent(
                agentId: 'a1',
                label: 'recon:offsets',
                phaseIndex: 0,
                phaseTitle: '',
                model: 'm',
                state: 'done',
              ),
            ],
          ),
        ],
      );
      final taskData = <String, dynamic>{
        'id': _taskId,
        'kind': 'tool-call',
        'name': 'Workflow',
        'state': 'completed',
        'model': 'qwen3.8-max-preview',
        'result': 'Workflow launched in background. Task ID: wzycqw34i '
            'Run ID: $liveRunId To resume after editing the script…',
      };
      sync.testSetSessionMessages(_sessionId, <Map<String, dynamic>>[taskData]);

      await tester.pumpWidget(_buildApp(taskData: taskData));
      await tester.pump();

      expect(find.text('recon:offsets'), findsOneWidget);
      // The useless raw receipt must be gone.
      expect(
        find.textContaining('Workflow launched in background'),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('falls back to the tool result when there is no run', (
    tester,
  ) async {
    // No run cached/fetchable and no transcript children: a classic container
    // tool that finished with a result should show that result, not nothing.
    final taskData = <String, dynamic>{
      'id': 'toolu_agent',
      'kind': 'tool-call',
      'name': 'Agent',
      'state': 'completed',
      'result': 'Final answer from the sub-agent.',
    };
    sync.testSetSessionMessages(_sessionId, <Map<String, dynamic>>[taskData]);

    await tester.pumpWidget(_buildApp(taskData: taskData));
    await tester.pump();

    expect(find.text('Final answer from the sub-agent.'), findsOneWidget);
    expect(find.text('No messages yet'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('still shows the empty note for a result-less Task', (
    tester,
  ) async {
    // Guards the fallback: a non-workflow container with neither transcript
    // children nor a result keeps the original empty state.
    final taskData = <String, dynamic>{
      'id': 'toolu_empty',
      'kind': 'tool-call',
      'name': 'Task',
      'state': 'completed',
    };
    sync.testSetSessionMessages(_sessionId, <Map<String, dynamic>>[taskData]);

    await tester.pumpWidget(_buildApp(taskData: taskData));
    await tester.pump();

    expect(find.text('No messages yet'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
