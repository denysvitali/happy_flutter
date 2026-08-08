import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/features/workflows/workflow_run_screen.dart';

import '../../helpers/test_helpers.dart';

const _sessionId = 's1';
const _runId = 'wf_1';

Map<String, dynamic> _skeleton() => <String, dynamic>{
  'runId': _runId,
  'workflowName': 'audit',
  'status': 'completed',
};

/// A grouped message list: a `Workflow` tool-call whose sidechain child
/// carries the full progress snapshot (1-based phase indices, the agent
/// lives on phase index 2 only).
List<Map<String, dynamic>> _messagesWithProgress() => <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 'wf-tool',
    'kind': 'tool-call',
    'name': 'Workflow',
    'children': <Map<String, dynamic>>[
      <String, dynamic>{
        'kind': 'agent-event',
        'workflowRunId': _runId,
        'workflowProgress': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'workflow_phase',
            'index': 1,
            'title': 'Read',
          },
          <String, dynamic>{
            'type': 'workflow_phase',
            'index': 2,
            'title': 'Report',
          },
          <String, dynamic>{
            'type': 'workflow_agent',
            'agentId': 'a2',
            'label': 'reporter',
            'phaseIndex': 2,
            'phaseTitle': 'Report',
            'model': 'm',
            'state': 'done',
          },
          <String, dynamic>{'type': 'workflow_log', 'message': 'all done'},
        ],
      },
    ],
  },
];

Widget _harness() => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: WorkflowRunScreen(
      sessionId: _sessionId,
      runId: _runId,
      taskData: _skeleton(),
    ),
  ),
);

void main() {
  setUp(() {
    createTestSync().testClearSessionMessageState(_sessionId);
  });

  testWidgets('renders phases, agents, and logs reconstructed from messages', (
    tester,
  ) async {
    Sync().testSetSessionMessages(_sessionId, _messagesWithProgress());

    await tester.pumpWidget(_harness());
    await tester.pump();

    // Phase headers.
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
    // Agent on 1-based phase index 2 — the old position-matching code
    // dropped this agent entirely, leaving the screen blank.
    expect(find.text('reporter'), findsOneWidget);
    // Logs section.
    expect(find.text('all done'), findsOneWidget);

    // 'Read' reported no agents but the run moved past it, so it reads as
    // finished rather than as a phase that is still waiting its turn.
    //
    // Two widgets say 'Completed': the run-level WorkflowStatusBadge in the
    // header (success-coloured chip) and the phase placeholder for 'Read'
    // (italic bodySmall). Both are correct here, so assert the count rather
    // than pinning one and breaking whenever the other appears.
    expect(find.text('Completed'), findsNWidgets(2));
    expect(find.text('Pending'), findsNothing);

    // Unmount so the screen cancels its poll timer + stream sub.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows only the status header when messages are empty', (
    tester,
  ) async {
    Sync().testSetSessionMessages(_sessionId, const <Map<String, dynamic>>[]);

    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(find.text('Read'), findsNothing);
    expect(find.text('reporter'), findsNothing);
    expect(find.text('all done'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('does not render raw daemon failure detail', (tester) async {
    Sync().testSetSessionMessages(_sessionId, const <Map<String, dynamic>>[]);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WorkflowRunScreen(
            sessionId: _sessionId,
            runId: _runId,
            taskData: const <String, dynamic>{
              'runId': _runId,
              'workflowName': 'audit',
              'status': 'failed',
              'error': 'rpc: secret-host.internal refused bearer abc123',
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('secret-host.internal'), findsNothing);
    expect(find.text('This workflow run failed unexpectedly.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('running agents show a play icon, never an hourglass', (
    tester,
  ) async {
    Sync().testSetSessionMessages(_sessionId, <Map<String, dynamic>>[
      _progressOwner(<Map<String, dynamic>>[
        _phase(1, 'Analyze'),
        _agent('a1', 1, state: 'running'),
      ]),
    ]);

    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_empty_rounded), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dedupes phase start+done events into one section', (
    tester,
  ) async {
    Sync().testSetSessionMessages(_sessionId, <Map<String, dynamic>>[
      _progressOwner(<Map<String, dynamic>>[
        _phase(1, 'Scan'),
        _phase(1, 'Scan', kind: 'done'),
        _agent('a1', 1),
      ]),
    ]);

    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(find.text('Scan'), findsOneWidget);
    // Done phase with all agents done shows no pending placeholder.
    expect(find.text('Pending'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('replaces an opaque wf_* name with a friendly title', (
    tester,
  ) async {
    Sync().testSetSessionMessages(_sessionId, const <Map<String, dynamic>>[]);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: WorkflowRunScreen(
            sessionId: _sessionId,
            runId: 'wf_a6c2cfba-460',
            taskData: const <String, dynamic>{
              'runId': 'wf_a6c2cfba-460',
              'workflowName': 'wf_a6c2cfba-460',
              'status': 'running',
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Workflow run'), findsOneWidget);
    expect(find.text('wf_a6c2cfba-460'), findsOneWidget); // subtitle

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('formats token counts compactly and dedupes a shared model', (
    tester,
  ) async {
    Sync().testSetSessionMessages(_sessionId, <Map<String, dynamic>>[
      _progressOwner(<Map<String, dynamic>>[
        _phase(1, 'Analyze'),
        _agent('a1', 1, state: 'running', tokens: 19698, toolCalls: 4),
        _agent('a2', 1, state: 'running', tokens: 100),
      ]),
    ]);

    await tester.pumpWidget(_harness());
    await tester.pump();

    // Agent subtitle and run stat row both compact the count.
    expect(find.text('19.7k tokens · 4 tools'), findsOneWidget);
    expect(find.text('19.8k tokens'), findsOneWidget); // 19698 + 100
    // Both agents share model 'm': once in the stat row, not per row.
    expect(find.text('m'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('renders raw step chips when no progress snapshot exists', (
    tester,
  ) async {
    // A completed run whose daemon snapshot is sparse and whose streamed
    // task_* chips carry no aggregate `workflowProgress` — the exact shape
    // that used to render as a blank detail page. The step timeline fallback
    // must surface every chip so the user sees the agents' work.
    Sync().testSetSessionMessages(_sessionId, <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'wf-tool',
        'kind': 'tool-call',
        'name': 'Workflow',
        'result': 'Launched. Run ID: $_runId',
        'children': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'c1',
            'kind': 'agent-event',
            'taskEvent': true,
            'taskStatus': 'running',
            'event': <String, dynamic>{
              'type': 'message',
              'message': 'Binary CFI audit agent',
            },
          },
          <String, dynamic>{
            'id': 'c2',
            'kind': 'agent-event',
            'taskEvent': true,
            'taskStatus': 'completed',
            'event': <String, dynamic>{
              'type': 'message',
              'message': 'Path-mining workflow',
            },
          },
        ],
      },
    ]);

    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(find.text('Binary CFI audit agent'), findsOneWidget);
    expect(find.text('Path-mining workflow'), findsOneWidget);
    // No structured snapshot → no phase sections, but never a blank page.
    expect(find.text('No progress details'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Map<String, dynamic> _phase(int index, String title, {String kind = 'start'}) =>
    <String, dynamic>{
      'type': 'workflow_phase',
      'index': index,
      'title': title,
      'kind': kind,
    };

Map<String, dynamic> _agent(
  String agentId,
  int phaseIndex, {
  String state = 'done',
  int? tokens,
  int? toolCalls,
}) => <String, dynamic>{
  'type': 'workflow_agent',
  'agentId': agentId,
  'label': 'agent-$agentId',
  'phaseIndex': phaseIndex,
  'phaseTitle': 'phase',
  'model': 'm',
  'state': state,
  if (tokens != null) 'tokens': tokens,
  if (toolCalls != null) 'toolCalls': toolCalls,
};

Map<String, dynamic> _progressOwner(List<Map<String, dynamic>> progress) =>
    <String, dynamic>{
      'id': 'wf-tool',
      'kind': 'tool-call',
      'name': 'Workflow',
      'children': <Map<String, dynamic>>[
        <String, dynamic>{
          'kind': 'agent-event',
          'workflowRunId': _runId,
          'workflowProgress': progress,
        },
      ],
    };
