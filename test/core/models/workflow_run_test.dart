import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/workflow_run.dart';

void main() {
  group('WorkflowRun parsing', () {
    test('parses a minimal snapshot', () {
      final run = WorkflowRun.tryFromJson(const <String, dynamic>{
        'runId': 'wf_abc',
        'workflowName': 'inspect',
        'status': 'running',
      });
      expect(run, isNotNull);
      expect(run!.runId, 'wf_abc');
      expect(run.workflowName, 'inspect');
      expect(run.status, 'running');
      expect(run.phases, isEmpty);
      expect(run.workflowProgress, isEmpty);
    });

    test('parses a full snapshot and round-trips through JSON', () {
      final json = <String, dynamic>{
        'runId': 'wf_123',
        'taskId': 'task-1',
        'workflowName': 'probe',
        'summary': 'a short summary',
        'status': 'completed',
        'script': 'export const meta = {...}',
        'scriptPath': '/tmp/probe.js',
        'args': {'n': 3},
        'phases': [
          {'title': 'Scan', 'detail': 'scanning'},
        ],
        'defaultModel': 'claude-sonnet-4-6',
        'startTime': 1000,
        'durationMs': 5000,
        'agentCount': 2,
        'totalTokens': 1234,
        'totalToolCalls': 5,
        'error': null,
        'result': 'done',
        'logs': null,
        'workflowProgress': [
          {
            'type': 'workflow_phase',
            'index': 0,
            'title': 'Scan',
            'kind': 'start',
          },
          {
            'type': 'workflow_agent',
            'agentId': 'a1',
            'label': 'scanner',
            'phaseIndex': 0,
            'phaseTitle': 'Scan',
            'model': 'claude-sonnet-4-6',
            'state': 'done',
            'tokens': 100,
            'toolCalls': 2,
            'durationMs': 2000,
          },
          {
            'type': 'workflow_log',
            'message': 'starting scan',
          },
        ],
      };
      final run = WorkflowRun.tryFromJson(json);
      expect(run, isNotNull);
      final roundTripped = WorkflowRun.tryFromJson(run!.toJson());
      expect(roundTripped, run);
    });

    test('parses the snake_case workflow_progress container', () {
      // The streamed task events carry the progress array under
      // `workflow_progress`; on-disk snapshots use `workflowProgress`.
      // Both must parse into the same typed progress list.
      final run = WorkflowRun.tryFromJson(const <String, dynamic>{
        'runId': 'wf_snake',
        'workflowName': 'sweep',
        'status': 'running',
        'workflow_progress': [
          <String, dynamic>{
            'type': 'workflow_phase',
            'index': 1,
            'title': 'Scan',
          },
          <String, dynamic>{
            'type': 'workflow_agent',
            'agentId': 'a1',
            'label': 'scanner',
            'phaseIndex': 1,
            'phaseTitle': 'Scan',
            'model': 'm',
            'state': 'running',
          },
        ],
      });
      expect(run, isNotNull);
      expect(run!.workflowProgress, hasLength(2));
      expect(run.phases, isEmpty);
    });

    test('rawWorkflowProgress prefers camelCase, falls back to snake', () {
      expect(
        WorkflowRun.rawWorkflowProgress(const <String, dynamic>{
          'workflowProgress': [1],
          'workflow_progress': [2],
        }),
        [1],
      );
      expect(
        WorkflowRun.rawWorkflowProgress(
          const <String, dynamic>{'workflow_progress': [2]},
        ),
        [2],
      );
      expect(
        WorkflowRun.rawWorkflowProgress(const <String, dynamic>{}),
        isNull,
      );
    });

    test('returns null when required fields are missing', () {
      expect(
        WorkflowRun.tryFromJson(const <String, dynamic>{
          'workflowName': 'probe',
          'status': 'running',
        }),
        isNull,
      );
      expect(
        WorkflowRun.tryFromJson(const <String, dynamic>{
          'runId': 'wf_123',
          'status': 'running',
        }),
        isNull,
      );
      expect(
        WorkflowRun.tryFromJson(const <String, dynamic>{
          'runId': 'wf_123',
          'workflowName': 'probe',
        }),
        isNull,
      );
    });

    test('skips malformed progress events', () {
      final run = WorkflowRun.tryFromJson(const <String, dynamic>{
        'runId': 'wf_x',
        'workflowName': 'x',
        'status': 'running',
        'workflowProgress': [
          {'type': 'workflow_agent'}, // missing required fields
          {'type': 'unknown_event'},
        ],
      });
      expect(run, isNotNull);
      expect(run!.workflowProgress, isEmpty);
    });
  });

  group('WorkflowRun.enrichFromMessages', () {
    WorkflowRun skeleton(String runId) => WorkflowRun(
          runId: runId,
          workflowName: runId,
          status: 'completed',
        );

    List<Map<String, dynamic>> groupedMessages({
      required String runId,
      required int phaseBase,
    }) =>
        <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'wf-tool',
            'kind': 'tool-call',
            'name': 'Workflow',
            'children': <Map<String, dynamic>>[
              <String, dynamic>{
                'kind': 'agent-event',
                'workflowRunId': runId,
                'workflowProgress': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'type': 'workflow_phase',
                    'index': phaseBase,
                    'title': 'Read',
                  },
                  <String, dynamic>{
                    'type': 'workflow_phase',
                    'index': phaseBase + 1,
                    'title': 'Report',
                  },
                  <String, dynamic>{
                    'type': 'workflow_agent',
                    'agentId': 'a1',
                    'label': 'read-go-mod',
                    'phaseIndex': phaseBase,
                    'phaseTitle': 'Read',
                    'model': 'm',
                    'state': 'done',
                    'tokens': 10,
                    'toolCalls': 3,
                  },
                  <String, dynamic>{
                    'type': 'workflow_log',
                    'message': 'finished',
                  },
                ],
              },
            ],
          },
        ];

    test('returns the run unchanged when there are no messages', () {
      final run = skeleton('wf_1');
      final enriched =
          WorkflowRun.enrichFromMessages(run, const <Map<String, dynamic>>[]);
      expect(identical(enriched, run), isTrue);
      expect(enriched.workflowProgress, isEmpty);
    });

    test('fills progress, phases, and counts from a grouped run', () {
      final enriched = WorkflowRun.enrichFromMessages(
        skeleton('wf_1'),
        groupedMessages(runId: 'wf_1', phaseBase: 1),
      );
      expect(enriched.workflowProgress, hasLength(4));
      expect(enriched.phases, hasLength(2));
      expect(enriched.phases[0].title, 'Read');
      expect(enriched.phases[1].title, 'Report');
      expect(enriched.agentCount, 1);
      expect(enriched.totalTokens, 10);
      expect(enriched.totalToolCalls, 3);
    });

    test('disambiguates two runs by workflowRunId tag', () {
      final messages = <Map<String, dynamic>>[
        ...groupedMessages(runId: 'wf_1', phaseBase: 0),
        ...groupedMessages(runId: 'wf_2', phaseBase: 0),
      ];
      final enriched =
          WorkflowRun.enrichFromMessages(skeleton('wf_2'), messages);
      final agents =
          enriched.workflowProgress.whereType<WorkflowAgent>().toList();
      expect(agents, hasLength(1));
      // Exactly one owner matched: the wf_2 snapshot, never wf_1's.
      expect(enriched.phases, hasLength(2));
    });

    test('falls back to a tagged top-level message when ungrouped', () {
      final messages = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'tn',
          'taskEvent': true,
          'isSidechain': true,
          'workflowRunId': 'wf_1',
          'workflowProgress': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'workflow_phase',
              'index': 0,
              'title': 'Only',
            },
          ],
        },
      ];
      final enriched =
          WorkflowRun.enrichFromMessages(skeleton('wf_1'), messages);
      expect(enriched.phases, hasLength(1));
      expect(enriched.phases.single.title, 'Only');
    });

    test('keeps a rich daemon snapshot when messages carry nothing', () {
      final run = skeleton('wf_1').copyWith(
        phases: const <WorkflowPhase>[WorkflowPhase(title: 'Daemon')],
        agentCount: 4,
      );
      final enriched = WorkflowRun.enrichFromMessages(
        run,
        <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'wf-tool',
            'kind': 'tool-call',
            'name': 'Workflow',
            'children': <Map<String, dynamic>>[],
          },
        ],
      );
      expect(enriched.phases.single.title, 'Daemon');
      expect(enriched.agentCount, 4);
    });
  });

  group('WorkflowRun.latestProgressFromChildren', () {
    test('returns the last non-empty snapshot', () {
      final progress = WorkflowRun.latestProgressFromChildren(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'workflowProgress': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'workflow_phase',
                'index': 0,
                'title': 'Stale',
              },
            ],
          },
          <String, dynamic>{
            'workflowProgress': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'workflow_phase',
                'index': 0,
                'title': 'Current',
              },
            ],
          },
        ],
      );
      expect(progress, hasLength(1));
      expect((progress.single as WorkflowPhaseEvent).title, 'Current');
    });

    test('skips children without progress', () {
      final progress = WorkflowRun.latestProgressFromChildren(
        <Map<String, dynamic>>[
          <String, dynamic>{'kind': 'agent-event'},
          <String, dynamic>{'workflowProgress': 'not-a-list'},
        ],
      );
      expect(progress, isEmpty);
    });
  });

  group('WorkflowStatus', () {
    test('isLive covers every in-flight state', () {
      expect(WorkflowStatus.isLive(WorkflowStatus.running), isTrue);
      expect(WorkflowStatus.isLive(WorkflowStatus.asyncLaunched), isTrue);
      expect(WorkflowStatus.isLive(WorkflowStatus.queued), isTrue);
      expect(WorkflowStatus.isLive(WorkflowStatus.pending), isTrue);
      expect(WorkflowStatus.isLive(WorkflowStatus.paused), isTrue);
      expect(WorkflowStatus.isLive(WorkflowStatus.completed), isFalse);
      expect(WorkflowStatus.isLive(WorkflowStatus.failed), isFalse);
      expect(WorkflowStatus.isLive(WorkflowStatus.killed), isFalse);
      expect(WorkflowStatus.isLive(WorkflowStatus.cancelled), isFalse);
    });

    test('exposes the daemon async_launched status', () {
      expect(WorkflowStatus.values, contains('async_launched'));
    });
  });
}
