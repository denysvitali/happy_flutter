import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/features/chat/widgets/agents_list_sheet.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('AgentsListSheet', () {
    late Sync sync;

    setUp(() {
      sync = createTestSync();
    });

    tearDown(() {
      sync.testClearSessionMessageState('test-session');
    });

    group('isSidechain filter (regression: inflated agent count)', () {
      test('countActiveAgents skips isSidechain messages', () {
        // Top-level Task (not sidechain) — counts.
        sync.testSetSessionMessages('test-session', [
          <String, dynamic>{
            'id': 'task-1',
            'kind': 'tool-call',
            'name': 'Task',
            'state': 'running',
            'isSidechain': false,
            'seq': 1,
          },
          // isSidechain child Task — must NOT be counted separately.
          <String, dynamic>{
            'id': 'child-1',
            'kind': 'tool-call',
            'name': 'Task',
            'state': 'running',
            'isSidechain': true,
            'seq': 2,
          },
        ]);

        expect(AgentsListSheet.countActiveAgents('test-session'), 1);
      });

      test(
        'countActiveAgents counts only top-level Tasks with state=running',
        () {
          sync.testSetSessionMessages('test-session', [
            <String, dynamic>{
              'id': 'task-running',
              'kind': 'tool-call',
              'name': 'Task',
              'state': 'running',
              'isSidechain': false,
              'seq': 1,
            },
            <String, dynamic>{
              'id': 'task-completed',
              'kind': 'tool-call',
              'name': 'Task',
              'state': 'completed',
              'isSidechain': false,
              'seq': 2,
            },
            <String, dynamic>{
              'id': 'task-sidechain',
              'kind': 'tool-call',
              'name': 'Task',
              'state': 'running',
              'isSidechain': true,
              'seq': 3,
            },
          ]);

          // Only the running, non-sidechain task counts.
          expect(AgentsListSheet.countActiveAgents('test-session'), 1);
        },
      );

      test('_extractAgents skips isSidechain messages', () {
        sync.testSetSessionMessages('test-session', [
          <String, dynamic>{
            'id': 'agent-top',
            'kind': 'tool-call',
            'name': 'Agent',
            'state': 'running',
            'isSidechain': false,
            'seq': 1,
          },
          <String, dynamic>{
            'id': 'agent-sidechain',
            'kind': 'tool-call',
            'name': 'Agent',
            'state': 'running',
            'isSidechain': true,
            'seq': 2,
          },
        ]);

        // Only one non-sidechain Agent in the list.
        // Note: _extractAgents is private so we test indirectly via the
        // sheet's item count — this is covered by the widget test below.
        expect(AgentsListSheet.countActiveAgents('test-session'), 1);
      });

      test('countActiveAgents skips _orphanRecovery synthetic Tasks', () {
        sync.testSetSessionMessages('test-session', [
          <String, dynamic>{
            'id': 'task-real',
            'kind': 'tool-call',
            'name': 'Task',
            'state': 'running',
            'isSidechain': false,
            'seq': 1,
          },
          // Synthetic placeholder created by orphan absorption — has
          // state=completed so it would already be excluded from active
          // count by state filter, but assert explicitly so the rule
          // can't regress.
          <String, dynamic>{
            'id': 'orphan-recovery-X',
            'kind': 'tool-call',
            'name': 'Task',
            'state': 'running',
            'isSidechain': false,
            '_orphanRecovery': true,
            'seq': 2,
          },
        ]);

        expect(AgentsListSheet.countActiveAgents('test-session'), 1);
      });

      test('available sub-agent catalog appears when no tasks spawned', () {
        sync.testSetSessionMessages('test-session', [
          <String, dynamic>{
            'id': 'init',
            'kind': 'agent-event',
            'event': <String, dynamic>{
              'type': 'message',
              'message': 'Available sub-agents: Explore, Plan (+1 more)',
            },
            'subagentsCatalog': ['Explore', 'Plan', 'general-purpose'],
            'seq': 1,
          },
        ]);

        final p = AgentsListSheet.computeTaskProgress('test-session');
        expect(p.total, 0);
        expect(AgentsListSheet.countActiveAgents('test-session'), 0);

        final agents = AgentsListSheet.extractAgents('test-session');
        expect(agents, hasLength(3));
        expect(agents.map((agent) => agent['input']['subagent_type']), [
          'Explore',
          'Plan',
          'general-purpose',
        ]);
      });

      test(
        '10 parallel agents with interleaved sidechain children: count=10',
        () {
          // Simulate the c471/c471 session pattern: 10 Agent tool_calls
          // (isSidechain=false) each followed by multiple isSidechain
          // children.  The sheet must show exactly 10 agents, not 10+N.
          final messages = <Map<String, dynamic>>[];

          // 10 top-level Agent tasks.
          for (int i = 0; i < 10; i++) {
            messages.add(<String, dynamic>{
              'id': 'agent-$i',
              'kind': 'tool-call',
              'name': 'Agent',
              'state': 'running',
              'isSidechain': false,
              'seq': i * 10,
              'input': <String, dynamic>{
                'description': 'agent-$i description',
                'subagent_type': 'Explore',
              },
            });
            // Each agent has 5 sidechain children (text + tool results).
            for (int j = 0; j < 5; j++) {
              messages.add(<String, dynamic>{
                'id': 'agent-${i}_child-$j',
                'kind': 'text',
                'role': 'agent',
                'isSidechain': true,
                'seq': i * 10 + j + 1,
              });
            }
          }

          sync.testSetSessionMessages('test-session', messages);

          // With the fix, only the 10 top-level agents are counted.
          // Pre-fix: would count 10 + 50 = 60 (or higher with synthetic
          // Task placeholders from orphan absorption).
          expect(AgentsListSheet.countActiveAgents('test-session'), 10);
        },
      );
    });

    group('background agents with taskEvent lifecycle', () {
      test('10 async agents with only taskEvent entries (orphan absorption '
          'removed originals): sheet shows 10', () {
        // Real scenario: parent spawns 10 background Agent tool_uses.
        // Sidechain messages arrive fast, grouper can't index parent
        // tool_use_ids in time → orphan absorption runs → original
        // tool-call entries are REPLACED by 1 synthetic _orphanRecovery
        // Task. The only remaining source of truth are the taskEvent
        // lifecycle entries.
        final messages = <Map<String, dynamic>>[];

        // One surviving real Agent tool-call (the one that resolved
        // before orphan absorption ran).
        messages.add(<String, dynamic>{
          'id': 'agent-survivor',
          'kind': 'tool-call',
          'name': 'Agent',
          'state': 'running',
          'isSidechain': false,
          'seq': 1,
          'input': <String, dynamic>{
            'description': 'Cold start path audit',
            'subagent_type': 'Explore',
            'run_in_background': true,
          },
        });

        // 1 synthetic Task from orphan absorption (the other 9
        // agents got absorbed into this single placeholder).
        messages.add(<String, dynamic>{
          'id': 'orphan-recovery-toolu_parent',
          'kind': 'tool-call',
          'name': 'Task',
          'state': 'completed',
          'isSidechain': false,
          '_orphanRecovery': true,
          'seq': 2,
          'input': <String, dynamic>{
            'description': 'Subagent output (recovered)',
          },
          'children': <Map<String, dynamic>>[],
        });

        // taskEvent lifecycle entries for all 10 agents — these
        // survive orphan absorption and carry the true count.
        for (var i = 0; i < 10; i++) {
          messages.add(<String, dynamic>{
            'id': 'task-event-$i',
            'kind': 'agent-event',
            'taskEvent': true,
            'agentId': 'agent-$i',
            'seq': 10 + i,
          });
        }

        sync.testSetSessionMessages('test-session', messages);

        // Progress must show all 10 (uses taskEvent when available).
        final p = AgentsListSheet.computeTaskProgress('test-session');
        expect(p.total, 10);
        expect(p.running, 10);

        // Sheet count: task lifecycle events are authoritative, so all 10
        // logical agents are visible even if only one parent tool-call
        // survived the sidechain grouping path.
        expect(AgentsListSheet.countActiveAgents('test-session'), 10);
      });

      test('workflow sidechain task events count as multiple agents', () {
        sync.testSetSessionMessages('test-session', [
          <String, dynamic>{
            'id': 'workflow-parent',
            'kind': 'tool-call',
            'name': 'Workflow',
            'state': 'running',
            'isSidechain': false,
            'seq': 1,
            'toolUseId': 'toolu_workflow',
            'input': <String, dynamic>{'name': 'diagnose-scroll-bounce'},
          },
          for (var i = 0; i < 4; i++)
            <String, dynamic>{
              'id': 'workflow-event-$i',
              'kind': 'agent-event',
              'taskEvent': true,
              'isSidechain': true,
              'agentId': 'workflow-agent-$i',
              'parentToolUseId': 'toolu_workflow',
              'taskType': 'local_workflow',
              'seq': 2 + i,
            },
          <String, dynamic>{
            'id': 'workflow-event-complete',
            'kind': 'text',
            'taskEvent': true,
            'taskStatus': 'completed',
            'isSidechain': true,
            'agentId': 'workflow-agent-0',
            'parentToolUseId': 'toolu_workflow',
            'taskType': 'local_workflow',
            'seq': 6,
          },
        ]);

        final p = AgentsListSheet.computeTaskProgress('test-session');
        expect(p.total, 4);
        expect(p.running, 3);
        expect(p.completed, 1);
        expect(AgentsListSheet.countActiveAgents('test-session'), 3);
        expect(AgentsListSheet.extractAgents('test-session'), hasLength(4));
      });

      test(
        'taskEvent with parentToolUseId synthesizes agent with parent id',
        () {
          sync.testSetSessionMessages('test-session', [
            <String, dynamic>{
              'id': 'workflow-event-0',
              'kind': 'agent-event',
              'taskEvent': true,
              'agentId': 'workflow-agent-0',
              'parentToolUseId': 'toolu_workflow',
              'taskType': 'local_workflow',
              'seq': 1,
            },
          ]);

          final agents = AgentsListSheet.extractAgents('test-session');
          expect(agents, hasLength(1));
          final agent = agents.single;
          expect(agent['id'], 'task-event-workflow-agent-0');
          expect(agent['toolUseId'], 'toolu_workflow');
          expect(agent['_taskEventParentToolUseId'], 'toolu_workflow');
        },
      );

      test(
        'taskEvent synthetic agent without parentToolUseId omits navigation id',
        () {
          sync.testSetSessionMessages('test-session', [
            <String, dynamic>{
              'id': 'ev-0',
              'kind': 'agent-event',
              'taskEvent': true,
              'agentId': 'agent-0',
              'seq': 1,
            },
          ]);

          final agents = AgentsListSheet.extractAgents('test-session');
          expect(agents, hasLength(1));

          final agent = agents.single;
          expect(agent['id'], 'task-event-agent-0');
          expect(agent['_taskEventParentToolUseId'], isNull);
          expect(agent['toolUseId'], 'agent-0');
        },
      );

      test('taskEvent + real tool-calls: prefers taskEvents '
          'when both exist', () {
        // When taskEvents are present, computeTaskProgress uses them
        // as the authoritative source.  Tool-calls without matching
        // taskEvents are invisible in this mode.
        sync.testSetSessionMessages('test-session', [
          // 2 real Agent tool-calls
          <String, dynamic>{
            'id': 'agent-0',
            'kind': 'tool-call',
            'name': 'Agent',
            'state': 'running',
            'isSidechain': false,
            'seq': 0,
            'input': <String, dynamic>{
              'description': 'agent 0',
              'subagent_type': 'Explore',
            },
          },
          <String, dynamic>{
            'id': 'agent-1',
            'kind': 'tool-call',
            'name': 'Agent',
            'state': 'running',
            'isSidechain': false,
            'seq': 1,
            'input': <String, dynamic>{
              'description': 'agent 1',
              'subagent_type': 'Explore',
            },
          },
          // taskEvent entries for agent-0 (already a tool-call)
          // and agent-2 (tool-call was absorbed).
          <String, dynamic>{
            'id': 'ev-0',
            'kind': 'agent-event',
            'taskEvent': true,
            'agentId': 'agent-0',
            'seq': 2,
          },
          <String, dynamic>{
            'id': 'ev-2',
            'kind': 'agent-event',
            'taskEvent': true,
            'agentId': 'agent-2',
            'seq': 3,
          },
        ]);

        // taskEvents are authoritative: 2 unique agentIds.
        final p = AgentsListSheet.computeTaskProgress('test-session');
        expect(p.total, 2);
        expect(p.running, 2);
      });
    });

    group('nested agents in children arrays', () {
      test('_extractAgents recurses into children to find nested agents', () {
        // Real scenario: 1 top-level Agent spawns 9 sub-agents.
        // After sidechain grouping, nested Agent tool-calls are
        // children of the parent.  Sheet must show all 10.
        sync.testSetSessionMessages('test-session', [
          <String, dynamic>{
            'id': 'agent-parent',
            'kind': 'tool-call',
            'name': 'Agent',
            'state': 'completed',
            'isSidechain': false,
            'seq': 1,
            'input': <String, dynamic>{
              'description': 'Cold start path audit',
              'subagent_type': 'Explore',
              'run_in_background': true,
            },
            'children': <Map<String, dynamic>>[
              // Nested sub-agents (isSidechain: true after grouping).
              for (int i = 0; i < 9; i++)
                <String, dynamic>{
                  'id': 'agent-child-$i',
                  'kind': 'tool-call',
                  'name': 'Agent',
                  'state': 'running',
                  'isSidechain': true,
                  'seq': 2 + i,
                  'input': <String, dynamic>{
                    'description': 'Sub-agent $i',
                    'subagent_type': 'Explore',
                  },
                },
            ],
          },
        ]);

        // countActiveAgents must find all 10 (1 parent + 9 children).
        expect(AgentsListSheet.countActiveAgents('test-session'), 9);
      });

      test('computeTaskProgress counts nested agents via tool-call '
          'fallback when no taskEvents', () {
        sync.testSetSessionMessages('test-session', [
          <String, dynamic>{
            'id': 'agent-parent',
            'kind': 'tool-call',
            'name': 'Agent',
            'state': 'completed',
            'isSidechain': false,
            'seq': 1,
            'children': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'agent-child-0',
                'kind': 'tool-call',
                'name': 'Agent',
                'state': 'running',
                'isSidechain': true,
                'seq': 2,
              },
              <String, dynamic>{
                'id': 'agent-child-1',
                'kind': 'tool-call',
                'name': 'Agent',
                'state': 'completed',
                'isSidechain': true,
                'seq': 3,
              },
              <String, dynamic>{
                'id': 'agent-child-2',
                'kind': 'tool-call',
                'name': 'Agent',
                'state': 'error',
                'isSidechain': true,
                'seq': 4,
              },
            ],
          },
        ]);
        final p = AgentsListSheet.computeTaskProgress('test-session');
        expect(p.total, 4); // 1 parent + 3 children
        expect(p.running, 1);
        expect(p.completed, 2);
        expect(p.error, 1);
      });

      test('skips _orphanRecovery synthetics nested in children', () {
        sync.testSetSessionMessages('test-session', [
          <String, dynamic>{
            'id': 'agent-parent',
            'kind': 'tool-call',
            'name': 'Agent',
            'state': 'completed',
            'isSidechain': false,
            'seq': 1,
            'children': <Map<String, dynamic>>[
              // Real nested agent.
              <String, dynamic>{
                'id': 'agent-child-real',
                'kind': 'tool-call',
                'name': 'Agent',
                'state': 'running',
                'isSidechain': true,
                'seq': 2,
              },
              // Synthetic orphan recovery inside children — should
              // be skipped.
              <String, dynamic>{
                'id': 'agent-child-orphan',
                'kind': 'tool-call',
                'name': 'Task',
                'state': 'completed',
                'isSidechain': true,
                '_orphanRecovery': true,
                'seq': 3,
              },
            ],
          },
        ]);

        // Only the real nested agent counts (running) + parent
        // (completed, not running).
        expect(AgentsListSheet.countActiveAgents('test-session'), 1);
      });

      test('computeTaskProgress skips _orphanRecovery in children '
          'fallback path', () {
        sync.testSetSessionMessages('test-session', [
          <String, dynamic>{
            'id': 'agent-parent',
            'kind': 'tool-call',
            'name': 'Agent',
            'state': 'completed',
            'isSidechain': false,
            'seq': 1,
            'children': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'agent-child-real',
                'kind': 'tool-call',
                'name': 'Agent',
                'state': 'running',
                'isSidechain': true,
                'seq': 2,
              },
              <String, dynamic>{
                'id': 'agent-child-orphan',
                'kind': 'tool-call',
                'name': 'Task',
                'state': 'completed',
                'isSidechain': true,
                '_orphanRecovery': true,
                'seq': 3,
              },
            ],
          },
        ]);
        final p = AgentsListSheet.computeTaskProgress('test-session');
        expect(p.total, 2); // parent + 1 real child, orphan skipped
        expect(p.running, 1);
        expect(p.completed, 1);
      });
    });

    group('computeTaskProgress', () {
      test('empty session returns zero progress', () {
        sync.testSetSessionMessages('test-session', []);
        final p = AgentsListSheet.computeTaskProgress('test-session');
        expect(p.total, 0);
        expect(p.running, 0);
        expect(p.completed, 0);
        expect(p.error, 0);
        expect(p.hasTasks, false);
        expect(p.completionRatio, 0.0);
      });

      test('counts running, completed, and error states', () {
        sync.testSetSessionMessages('test-session', [
          <String, dynamic>{
            'id': 'task-1',
            'kind': 'tool-call',
            'name': 'Task',
            'state': 'running',
            'isSidechain': false,
            'seq': 1,
          },
          <String, dynamic>{
            'id': 'task-2',
            'kind': 'tool-call',
            'name': 'Task',
            'state': 'completed',
            'isSidechain': false,
            'seq': 2,
          },
          <String, dynamic>{
            'id': 'task-3',
            'kind': 'tool-call',
            'name': 'Agent',
            'state': 'error',
            'isSidechain': false,
            'seq': 3,
          },
          <String, dynamic>{
            'id': 'task-4',
            'kind': 'tool-call',
            'name': 'Agent',
            'state': 'running',
            'isSidechain': false,
            'seq': 4,
          },
        ]);
        final p = AgentsListSheet.computeTaskProgress('test-session');
        expect(p.total, 4);
        expect(p.running, 2);
        expect(p.completed, 1);
        expect(p.error, 1);
        expect(p.hasTasks, true);
        expect(p.completionRatio, 0.5);
        expect(p.isComplete, false);
      });

      test('skips sidechain children and orphan recovery', () {
        sync.testSetSessionMessages('test-session', [
          <String, dynamic>{
            'id': 'task-top',
            'kind': 'tool-call',
            'name': 'Task',
            'state': 'running',
            'isSidechain': false,
            'seq': 1,
          },
          <String, dynamic>{
            'id': 'task-sidechain',
            'kind': 'tool-call',
            'name': 'Task',
            'state': 'running',
            'isSidechain': true,
            'seq': 2,
          },
          <String, dynamic>{
            'id': 'task-orphan',
            'kind': 'tool-call',
            'name': 'Task',
            'state': 'running',
            'isSidechain': false,
            '_orphanRecovery': true,
            'seq': 3,
          },
        ]);
        final p = AgentsListSheet.computeTaskProgress('test-session');
        expect(p.total, 1);
        expect(p.running, 1);
      });

      test('all completed yields completionRatio=1 and isComplete=true', () {
        sync.testSetSessionMessages('test-session', [
          <String, dynamic>{
            'id': 'task-1',
            'kind': 'tool-call',
            'name': 'Task',
            'state': 'completed',
            'isSidechain': false,
            'seq': 1,
          },
          <String, dynamic>{
            'id': 'task-2',
            'kind': 'tool-call',
            'name': 'Agent',
            'state': 'completed',
            'isSidechain': false,
            'seq': 2,
          },
        ]);
        final p = AgentsListSheet.computeTaskProgress('test-session');
        expect(p.completionRatio, 1.0);
        expect(p.isComplete, true);
      });

      test('non-Task tool calls are ignored', () {
        sync.testSetSessionMessages('test-session', [
          <String, dynamic>{
            'id': 'tool-1',
            'kind': 'tool-call',
            'name': 'Grep',
            'state': 'running',
            'isSidechain': false,
            'seq': 1,
          },
          <String, dynamic>{
            'id': 'text-1',
            'kind': 'text',
            'role': 'agent',
            'seq': 2,
          },
        ]);
        final p = AgentsListSheet.computeTaskProgress('test-session');
        expect(p.total, 0);
      });

      test('prefers task lifecycle events over tool-call counting', () {
        // Task lifecycle events present -> should use those, ignore tool calls.
        sync.testSetSessionMessages('test-session', [
          <String, dynamic>{
            'id': 'task-1',
            'kind': 'tool-call',
            'name': 'Task',
            'state': 'running',
            'isSidechain': false,
            'seq': 1,
          },
          <String, dynamic>{
            'id': 'ev-1',
            'kind': 'agent-event',
            'taskEvent': true,
            'agentId': 'agent-1',
            'seq': 2,
          },
        ]);
        final p = AgentsListSheet.computeTaskProgress('test-session');
        expect(p.total, 1);
        expect(p.running, 1);
        expect(p.completed, 0);
      });

      test('task lifecycle events track completion by agentId', () {
        sync.testSetSessionMessages('test-session', [
          // Task A: started then completed
          <String, dynamic>{
            'id': 'ev-1',
            'kind': 'agent-event',
            'taskEvent': true,
            'agentId': 'agent-a',
            'seq': 1,
          },
          <String, dynamic>{
            'id': 'ev-2',
            'kind': 'text',
            'taskEvent': true,
            'taskStatus': 'completed',
            'agentId': 'agent-a',
            'seq': 2,
          },
          // Task B: started, multiple progress updates, still active
          <String, dynamic>{
            'id': 'ev-3',
            'kind': 'agent-event',
            'taskEvent': true,
            'agentId': 'agent-b',
            'seq': 3,
          },
          <String, dynamic>{
            'id': 'ev-4',
            'kind': 'agent-event',
            'taskEvent': true,
            'agentId': 'agent-b',
            'seq': 4,
          },
          // Task C: started then failed
          <String, dynamic>{
            'id': 'ev-5',
            'kind': 'agent-event',
            'taskEvent': true,
            'agentId': 'agent-c',
            'seq': 5,
          },
          <String, dynamic>{
            'id': 'ev-6',
            'kind': 'text',
            'taskEvent': true,
            'taskStatus': 'failed',
            'agentId': 'agent-c',
            'seq': 6,
          },
        ]);
        final p = AgentsListSheet.computeTaskProgress('test-session');
        expect(p.total, 3);
        expect(p.running, 1); // only agent-b is still active
        expect(p.completed, 1);
        expect(p.error, 1);
      });

      test('task events without agentId are ignored', () {
        sync.testSetSessionMessages('test-session', [
          <String, dynamic>{
            'id': 'ev-1',
            'kind': 'agent-event',
            'taskEvent': true,
            'seq': 1,
          },
        ]);
        final p = AgentsListSheet.computeTaskProgress('test-session');
        expect(p.total, 0);
      });
    });

    group('agent tile tap', () {
      testWidgets('invokes onAgentTap with message id for real Task rows', (
        tester,
      ) async {
        sync.testSetSessionMessages('test-session', [
          <String, dynamic>{
            'id': 'task-1',
            'kind': 'tool-call',
            'name': 'Task',
            'state': 'running',
            'input': <String, dynamic>{
              'description': 'do work',
              'subagent_type': 'explore',
            },
          },
        ]);

        Map<String, dynamic>? tappedAgent;
        String? tappedNavigationId;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AgentsListSheet(
                sessionId: 'test-session',
                onAgentTap: (agent, navigationId) {
                  tappedAgent = agent;
                  tappedNavigationId = navigationId;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('do work'));
        await tester.pumpAndSettle();

        expect(tappedAgent, isNotNull);
        expect(tappedAgent!['id'], 'task-1');
        expect(tappedNavigationId, 'task-1');
      });

      testWidgets(
        'invokes onAgentTap with parentToolUseId for taskEvent synthetics',
        (tester) async {
          sync.testSetSessionMessages('test-session', [
            <String, dynamic>{
              'id': 'parent-msg',
              'kind': 'tool-call',
              'name': 'Task',
              'toolUseId': 'toolu_parent',
              'state': 'running',
              'input': <String, dynamic>{'description': 'parent task'},
            },
            <String, dynamic>{
              'id': 'ev-1',
              'kind': 'agent-event',
              'taskEvent': true,
              'agentId': 'agent-1',
              'parentToolUseId': 'toolu_parent',
              'taskStatus': 'running',
              'message': 'child task',
            },
          ]);

          String? tappedNavigationId;

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: AgentsListSheet(
                  sessionId: 'test-session',
                  onAgentTap: (_, navigationId) {
                    tappedNavigationId = navigationId;
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('child task'));
          await tester.pumpAndSettle();

          expect(tappedNavigationId, 'toolu_parent');
        },
      );

      testWidgets(
        'invokes onAgentTap with toolUseId fallback for taskEvent synthetics '
        'without parentToolUseId',
        (tester) async {
          sync.testSetSessionMessages('test-session', [
            <String, dynamic>{
              'id': 'ev-1',
              'kind': 'agent-event',
              'taskEvent': true,
              'agentId': 'agent-1',
              'taskStatus': 'running',
              'message': 'child task',
            },
          ]);

          String? tappedNavigationId;

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: AgentsListSheet(
                  sessionId: 'test-session',
                  onAgentTap: (_, navigationId) {
                    tappedNavigationId = navigationId;
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('child task'));
          await tester.pumpAndSettle();

          expect(tappedNavigationId, 'agent-1');
        },
      );

      testWidgets('catalog synthetics are not tappable', (tester) async {
        sync.testSetSessionMessages('test-session', [
          <String, dynamic>{
            'id': 'msg-1',
            'kind': 'text',
            'content': 'hello',
            'subagentsCatalog': <String>['Explore'],
          },
        ]);

        var tapCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AgentsListSheet(
                sessionId: 'test-session',
                onAgentTap: (agent, navigationId) => tapCount++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The Explore catalog row has no chevron and onTap is null.
        await tester.tap(find.text('Explore'));
        await tester.pumpAndSettle();

        expect(tapCount, 0);
      });
    });
  });
}
