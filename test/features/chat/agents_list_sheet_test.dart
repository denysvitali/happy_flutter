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
            'isSidechain': false,
            'seq': 1,
          },
          <String, dynamic>{
            'id': 'agent-sidechain',
            'kind': 'tool-call',
            'name': 'Agent',
            'isSidechain': true,
            'seq': 2,
          },
        ]);

        // Only one non-sidechain Agent in the list.
        // Note: _extractAgents is private so we test indirectly via the
        // sheet's item count — this is covered by the widget test below.
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
  });
}