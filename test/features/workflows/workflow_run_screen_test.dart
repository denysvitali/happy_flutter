import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
              <String, dynamic>{
                'type': 'workflow_log',
                'message': 'all done',
              },
            ],
          },
        ],
      },
    ];

Widget _harness() => ProviderScope(
      child: MaterialApp(
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

  testWidgets(
    'renders phases, agents, and logs reconstructed from messages',
    (tester) async {
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

      // Unmount so the screen cancels its poll timer + stream sub.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('shows only the status header when messages are empty',
      (tester) async {
    Sync().testSetSessionMessages(_sessionId, const <Map<String, dynamic>>[]);

    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(find.text('Read'), findsNothing);
    expect(find.text('reporter'), findsNothing);
    expect(find.text('all done'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
