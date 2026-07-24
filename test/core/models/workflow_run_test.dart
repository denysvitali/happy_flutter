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
          {'type': 'workflow_log', 'message': 'starting scan'},
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
        WorkflowRun.rawWorkflowProgress(const <String, dynamic>{
          'workflow_progress': [2],
        }),
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
    WorkflowRun skeleton(String runId) =>
        WorkflowRun(runId: runId, workflowName: runId, status: 'completed');

    List<Map<String, dynamic>> groupedMessages({
      required String runId,
      required int phaseBase,
    }) => <Map<String, dynamic>>[
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
              <String, dynamic>{'type': 'workflow_log', 'message': 'finished'},
            ],
          },
        ],
      },
    ];

    test('returns the run unchanged when there are no messages', () {
      final run = skeleton('wf_1');
      final enriched = WorkflowRun.enrichFromMessages(
        run,
        const <Map<String, dynamic>>[],
      );
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
      final enriched = WorkflowRun.enrichFromMessages(
        skeleton('wf_2'),
        messages,
      );
      final agents = enriched.workflowProgress
          .whereType<WorkflowAgent>()
          .toList();
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
      final enriched = WorkflowRun.enrichFromMessages(
        skeleton('wf_1'),
        messages,
      );
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

  group('WorkflowRun.accumulateProgressFromChildren', () {
    test('a later delta wins for the same phase index', () {
      final progress = WorkflowRun.accumulateProgressFromChildren(
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
      final progress = WorkflowRun.accumulateProgressFromChildren(
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

  group('WorkflowRun.withFallbackProgress', () {
    WorkflowRun run(String status, {bool rich = false}) => WorkflowRun(
      runId: 'wf_1',
      workflowName: 'wf_1',
      status: status,
      phases: rich
          ? const <WorkflowPhase>[WorkflowPhase(title: 'P')]
          : const <WorkflowPhase>[],
    );

    test('returns next unchanged when there is no previous run', () {
      final next = run('running');
      expect(
        identical(WorkflowRun.withFallbackProgress(next, null), next),
        isTrue,
      );
    });

    test('keeps a rich next snapshot as-is', () {
      final next = run('running', rich: true);
      final prev = run('running', rich: true);
      expect(
        identical(WorkflowRun.withFallbackProgress(next, prev), next),
        isTrue,
      );
    });

    test('keeps the held overlay for a sparse live snapshot', () {
      final merged = WorkflowRun.withFallbackProgress(
        run('running'),
        run('running', rich: true),
      );
      expect(merged.phases.single.title, 'P');
    });

    test('never overlays stale progress onto a terminal snapshot', () {
      final merged = WorkflowRun.withFallbackProgress(
        run('completed'),
        run('running', rich: true),
      );
      expect(merged.phases, isEmpty);
    });
  });

  group('WorkflowRun.enrichFromMessages snake_case child key', () {
    test('reads workflow_progress off sidechain children', () {
      final run = WorkflowRun(
        runId: 'wf_1',
        workflowName: 'wf_1',
        status: 'running',
      );
      final enriched = WorkflowRun.enrichFromMessages(
        run,
        <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'wf-tool',
            'kind': 'tool-call',
            'name': 'Workflow',
            'children': <Map<String, dynamic>>[
              <String, dynamic>{
                'kind': 'agent-event',
                'workflowRunId': 'wf_1',
                'workflow_progress': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'type': 'workflow_phase',
                    'index': 1,
                    'title': 'Scan',
                  },
                ],
              },
            ],
          },
        ],
      );
      expect(enriched.phases.single.title, 'Scan');
    });
  });

  group('WorkflowRun.stepChildrenForRun (chips-only runs)', () {
    // A workflow whose daemon snapshot carries no `workflowProgress` and
    // whose streamed `task_*` chips carry no aggregate snapshot either — only
    // per-agent progress chips. This is the shape that left the Workflows
    // list/detail empty while the chat header still promised "N steps".
    List<Map<String, dynamic>> chipsOnlyMessages({
      required String runId,
      required bool nestUnderTool,
      bool withResultEcho = true,
    }) {
      final chips = <Map<String, dynamic>>[
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
          'taskStatus': 'running',
          'event': <String, dynamic>{
            'type': 'message',
            'message': 'Binary CFI audit agent',
          },
        },
        <String, dynamic>{
          'id': 'c3',
          'kind': 'agent-event',
          'taskEvent': true,
          'taskStatus': 'completed',
          'event': <String, dynamic>{
            'type': 'message',
            'message': 'Path-mining workflow',
          },
        },
      ];
      if (!nestUnderTool) {
        // Orphan chips tagged with the run id at the top level.
        for (final c in chips) {
          c['workflowRunId'] = runId;
        }
        return chips;
      }
      return <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'wf-tool',
          'kind': 'tool-call',
          'name': 'Workflow',
          if (withResultEcho) 'result': 'Launched. Run ID: $runId',
          'children': chips,
        },
      ];
    }

    test('locates nested chips via the tool-result run-id echo', () {
      final steps = WorkflowRun.stepChildrenForRun(
        'wf_3e4d1aa3-68d',
        chipsOnlyMessages(runId: 'wf_3e4d1aa3-68d', nestUnderTool: true),
      );
      expect(steps, hasLength(3));
    });

    test('falls back to the sole Workflow tool-call when no tag exists', () {
      final steps = WorkflowRun.stepChildrenForRun(
        'wf_x',
        chipsOnlyMessages(
          runId: 'wf_x',
          nestUnderTool: true,
          withResultEcho: false,
        ),
      );
      expect(steps, hasLength(3));
    });

    test('collects orphan top-level chips tagged with the run id', () {
      final steps = WorkflowRun.stepChildrenForRun(
        'wf_y',
        chipsOnlyMessages(runId: 'wf_y', nestUnderTool: false),
      );
      expect(steps, hasLength(3));
    });

    test('returns empty when the run has no steps anywhere', () {
      expect(WorkflowRun.stepChildrenForRun('wf_missing', const []), isEmpty);
    });

    test('enrich stays a no-op for chips-only (no workflowProgress)', () {
      final run = WorkflowRun(
        runId: 'wf_z',
        workflowName: 'wf_z',
        status: 'completed',
      );
      final enriched = WorkflowRun.enrichFromMessages(
        run,
        chipsOnlyMessages(runId: 'wf_z', nestUnderTool: true),
      );
      expect(enriched.workflowProgress, isEmpty);
      expect(enriched.phases, isEmpty);
    });
  });

  group('WorkflowRun.runIdFromToolResult', () {
    test('parses the Run ID label from a string result', () {
      expect(
        WorkflowRun.runIdFromToolResult('Done. Run ID: wf_abc-123'),
        'wf_abc-123',
      );
    });

    test('reads a structured result map', () {
      expect(
        WorkflowRun.runIdFromToolResult(<String, dynamic>{
          'runId': 'wf_struct',
        }),
        'wf_struct',
      );
    });

    test('returns null when no id is present', () {
      expect(WorkflowRun.runIdFromToolResult('no id here'), isNull);
      expect(WorkflowRun.runIdFromToolResult(null), isNull);
    });
  });

  group('WorkflowRun step rendering helpers', () {
    test('stepLabel reads task chip, tool-call, and text shapes', () {
      expect(
        WorkflowRun.stepLabel(<String, dynamic>{
          'taskEvent': true,
          'event': <String, dynamic>{'message': 'audit agent'},
        }),
        'audit agent',
      );
      expect(
        WorkflowRun.stepLabel(<String, dynamic>{
          'kind': 'tool-call',
          'name': 'Bash',
          'input': <String, dynamic>{'command': 'ls -la\nmore'},
        }),
        'Bash: ls -la',
      );
      expect(
        WorkflowRun.stepLabel(<String, dynamic>{
          'kind': 'text',
          'content': 'a summary',
        }),
        'a summary',
      );
    });

    test('isRenderableStep drops bridges, links, and thinking', () {
      expect(
        WorkflowRun.isRenderableStep(<String, dynamic>{'isBridge': true}),
        isFalse,
      );
      expect(
        WorkflowRun.isRenderableStep(<String, dynamic>{
          'kind': 'text',
          'isThinking': true,
          'content': 'x',
        }),
        isFalse,
      );
      expect(
        WorkflowRun.isRenderableStep(<String, dynamic>{
          'kind': 'agent-event',
          'event': <String, dynamic>{'message': 'real'},
        }),
        isTrue,
      );
    });

    test('collapseSteps dedupes consecutive identical chips', () {
      final collapsed = WorkflowRun.collapseSteps(<Map<String, dynamic>>[
        <String, dynamic>{
          'taskEvent': true,
          'taskStatus': 'running',
          'event': <String, dynamic>{'message': 'same'},
        },
        <String, dynamic>{
          'taskEvent': true,
          'taskStatus': 'running',
          'event': <String, dynamic>{'message': 'same'},
        },
        <String, dynamic>{
          'taskEvent': true,
          'taskStatus': 'completed',
          'event': <String, dynamic>{'message': 'other'},
        },
      ]);
      expect(collapsed, hasLength(2));
      expect(WorkflowRun.stepLabel(collapsed.last), 'other');
    });
  });

  group('workflow_progress delta accumulation', () {
    // Claude Code emits one event per state change, not a cumulative
    // snapshot. Reading only the newest child collapses a multi-agent run to
    // whichever agent ticked last — the defect these tests pin.
    Map<String, dynamic> delta(List<Map<String, dynamic>> events) =>
        <String, dynamic>{
          'kind': 'agent-event',
          'workflowRunId': 'wf_1',
          'workflowProgress': events,
        };

    Map<String, dynamic> agentEvent(
      String id,
      String state, {
      int phaseIndex = 1,
      String phaseTitle = 'Read',
      int? tokens,
      int? toolCalls,
      String? promptPreview,
      int? durationMs,
    }) => <String, dynamic>{
      'type': 'workflow_agent',
      'agentId': id,
      'label': id,
      'phaseIndex': phaseIndex,
      'phaseTitle': phaseTitle,
      'model': 'claude-opus-5',
      'state': state,
      if (tokens != null) 'tokens': tokens,
      if (toolCalls != null) 'toolCalls': toolCalls,
      if (promptPreview != null) 'promptPreview': promptPreview,
      if (durationMs != null) 'durationMs': durationMs,
    };

    final children = <Map<String, dynamic>>[
      delta(<Map<String, dynamic>>[
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
        agentEvent('a1', 'start', promptPreview: 'read the file'),
      ]),
      delta(<Map<String, dynamic>>[
        agentEvent('a1', 'progress', tokens: 100, toolCalls: 2),
      ]),
      delta(<Map<String, dynamic>>[
        agentEvent('a1', 'done', tokens: 120, toolCalls: 3, durationMs: 4000),
        agentEvent('a2', 'start', phaseIndex: 2, phaseTitle: 'Report'),
      ]),
      delta(<Map<String, dynamic>>[
        agentEvent(
          'a2',
          'progress',
          phaseIndex: 2,
          phaseTitle: 'Report',
          tokens: 50,
        ),
      ]),
    ];

    test('keeps every agent and every announced phase', () {
      final progress = WorkflowRun.accumulateProgressFromChildren(children);
      final agents = progress.whereType<WorkflowAgent>().toList();
      final phases = progress.whereType<WorkflowPhaseEvent>().toList();
      expect(agents.map((a) => a.agentId), <String>['a1', 'a2']);
      expect(phases.map((p) => p.title), <String>['Read', 'Report']);
    });

    test('folds the newest state without erasing retained fields', () {
      final progress = WorkflowRun.accumulateProgressFromChildren(children);
      final a1 = progress.whereType<WorkflowAgent>().firstWhere(
        (a) => a.agentId == 'a1',
      );
      expect(a1.state, 'done');
      expect(a1.tokens, 120);
      expect(a1.durationMs, 4000);
      // Only the very first delta carried the prompt.
      expect(a1.promptPreview, 'read the file');
    });

    test('never reverts a finished agent on an out-of-order delta', () {
      final progress = WorkflowRun.accumulateProgressFromChildren(
        <Map<String, dynamic>>[
          delta(<Map<String, dynamic>>[agentEvent('a1', 'done')]),
          delta(<Map<String, dynamic>>[agentEvent('a1', 'progress')]),
        ],
      );
      expect(progress.whereType<WorkflowAgent>().single.state, 'done');
    });

    test('aggregates counts across all agents, deduped by agentId', () {
      final run = WorkflowRun.enrichFromMessages(
        WorkflowRun(runId: 'wf_1', workflowName: 'probe', status: 'running'),
        <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'wf-tool',
            'kind': 'tool-call',
            'name': 'Workflow',
            'workflowRunId': 'wf_1',
            'children': children,
          },
        ],
      );
      expect(run.agentCount, 2);
      expect(run.totalTokens, 170);
      expect(run.totalToolCalls, 3);
    });

    test('keeps declared phase detail and unannounced phases', () {
      final declared = WorkflowRun(
        runId: 'wf_1',
        workflowName: 'probe',
        status: 'running',
        phases: const <WorkflowPhase>[
          WorkflowPhase(title: 'Read', detail: 'read inputs'),
          WorkflowPhase(title: 'Report', detail: 'write it up'),
          WorkflowPhase(title: 'Verify', detail: 'double check'),
        ],
      );
      final run = WorkflowRun.enrichFromMessages(
        declared,
        <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'wf-tool',
            'kind': 'tool-call',
            'name': 'Workflow',
            'workflowRunId': 'wf_1',
            'children': children,
          },
        ],
      );
      expect(run.phases.map((p) => p.title), <String>[
        'Read',
        'Report',
        'Verify',
      ]);
      expect(run.phases.first.detail, 'read inputs');
      expect(run.phases.last.detail, 'double check');
    });
  });

  group('WorkflowRun.phaseGroups', () {
    WorkflowAgent agent(
      String id,
      String state, {
      required int phaseIndex,
      required String phaseTitle,
    }) => WorkflowAgent(
      agentId: id,
      label: id,
      phaseIndex: phaseIndex,
      phaseTitle: phaseTitle,
      model: 'm',
      state: state,
    );

    test('attaches agents by 1-based wire index, not list position', () {
      final run = WorkflowRun(
        runId: 'wf_1',
        workflowName: 'probe',
        status: 'running',
        phases: const <WorkflowPhase>[
          WorkflowPhase(title: 'Read'),
          WorkflowPhase(title: 'Report'),
        ],
        workflowProgress: <WorkflowProgressEvent>[
          const WorkflowPhaseEvent(index: 1, title: 'Read', kind: 'start'),
          const WorkflowPhaseEvent(index: 2, title: 'Report', kind: 'start'),
          agent('a1', 'done', phaseIndex: 1, phaseTitle: 'Read'),
          agent('a2', 'progress', phaseIndex: 2, phaseTitle: 'Report'),
        ],
      );
      final groups = WorkflowRun.phaseGroups(run);
      expect(groups, hasLength(2));
      expect(groups[0].agents.single.agentId, 'a1');
      expect(groups[0].state, WorkflowPhaseState.done);
      expect(groups[1].agents.single.agentId, 'a2');
      expect(groups[1].state, WorkflowPhaseState.active);
    });

    test('matches by phaseTitle when no phase event has been seen', () {
      final run = WorkflowRun(
        runId: 'wf_1',
        workflowName: 'probe',
        status: 'running',
        phases: const <WorkflowPhase>[
          WorkflowPhase(title: 'Probe'),
          WorkflowPhase(title: 'Verify'),
        ],
        workflowProgress: <WorkflowProgressEvent>[
          agent('a1', 'progress', phaseIndex: 1, phaseTitle: 'Probe'),
        ],
      );
      final groups = WorkflowRun.phaseGroups(run);
      expect(groups[0].agents.single.agentId, 'a1');
      expect(groups[0].state, WorkflowPhaseState.active);
      expect(groups[1].state, WorkflowPhaseState.pending);
    });

    test('marks skipped-over phases done once a later phase has agents', () {
      final run = WorkflowRun(
        runId: 'wf_1',
        workflowName: 'probe',
        status: 'running',
        phases: const <WorkflowPhase>[
          WorkflowPhase(title: 'One'),
          WorkflowPhase(title: 'Two'),
          WorkflowPhase(title: 'Three'),
        ],
        workflowProgress: <WorkflowProgressEvent>[
          agent('a1', 'progress', phaseIndex: 3, phaseTitle: 'Three'),
        ],
      );
      final groups = WorkflowRun.phaseGroups(run);
      expect(groups[0].state, WorkflowPhaseState.done);
      expect(groups[1].state, WorkflowPhaseState.done);
      expect(groups[2].state, WorkflowPhaseState.active);
    });

    test('reports a failed phase when its agents errored', () {
      final run = WorkflowRun(
        runId: 'wf_1',
        workflowName: 'probe',
        status: 'failed',
        phases: const <WorkflowPhase>[WorkflowPhase(title: 'One')],
        workflowProgress: <WorkflowProgressEvent>[
          agent('a1', 'error', phaseIndex: 1, phaseTitle: 'One'),
        ],
      );
      expect(
        WorkflowRun.phaseGroups(run).single.state,
        WorkflowPhaseState.failed,
      );
    });

    test('never drops an agent that matches no phase', () {
      final run = WorkflowRun(
        runId: 'wf_1',
        workflowName: 'probe',
        status: 'running',
        phases: const <WorkflowPhase>[WorkflowPhase(title: 'One')],
        workflowProgress: <WorkflowProgressEvent>[
          const WorkflowPhaseEvent(index: 1, title: 'One', kind: 'start'),
          agent('orphan', 'progress', phaseIndex: 9, phaseTitle: 'Ghost'),
        ],
      );
      final groups = WorkflowRun.phaseGroups(run, fallbackTitle: 'Other');
      expect(groups, hasLength(2));
      expect(groups.last.phase.title, 'Other');
      expect(groups.last.agents.single.agentId, 'orphan');
    });

    test('buckets everything under a fallback phase when none are known', () {
      final run = WorkflowRun(
        runId: 'wf_1',
        workflowName: 'probe',
        status: 'running',
        workflowProgress: <WorkflowProgressEvent>[
          agent('a1', 'progress', phaseIndex: 0, phaseTitle: ''),
        ],
      );
      final groups = WorkflowRun.phaseGroups(run);
      expect(groups.single.phase.title, 'probe');
      expect(groups.single.agents, hasLength(1));
    });
  });
}
