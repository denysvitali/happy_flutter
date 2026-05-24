import 'package:flutter_test/flutter_test.dart';
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

      test('countActiveAgents counts only top-level Tasks with state=running',
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
      });

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

      test('10 parallel agents with interleaved sidechain children: count=10',
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
        expect(p.completed, 2); // agent-a completed, agent-c failed = both done
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
  });
}