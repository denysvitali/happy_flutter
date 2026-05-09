import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

/// Tests for orphan sidechain absorption.
///
/// Background: when a session's parent Task tool-call is missing from
/// the loaded message window (cache truncation, server pagination, or
/// a partial restore), all of that Task's sidechain children sit at
/// the top of the message list with `isSidechain: true`.  The chat
/// list filters those out (only grouped Task children are rendered)
/// and the AgentsListSheet enumerates only top-level Task tool-calls.
/// The net effect: 100+ messages can be silently invisible.
///
/// The fix detects stuck orphans in the deferred regroup sweep and
/// absorbs them into synthetic Task placeholders, which render as
/// normal Task rows in the chat and in the AgentsListSheet.
void main() {
  group('orphan recovery', () {
    late Sync sync;

    setUp(() {
      sync = createTestSync();
    });

    tearDown(() {
      sync.testClearSessionMessageState('s1');
    });

    test('absorbs orphan sidechains grouped by parentUuid into '
        'synthetic Task placeholders', () {
      sync.testSetSessionMessages('s1', [
        <String, dynamic>{
          'id': 'text-1',
          'kind': 'text',
          'role': 'user',
          'content': 'hello',
          'seq': 1,
          'createdAt': 100,
        },
        <String, dynamic>{
          'id': 'orph-1',
          'isSidechain': true,
          'parentUuid': 'parent-A',
          'uuid': 'u-1',
          'kind': 'text',
          'role': 'agent',
          'content': 'A first',
          'seq': 2,
          'createdAt': 200,
        },
        <String, dynamic>{
          'id': 'orph-2',
          'isSidechain': true,
          'parentUuid': 'parent-A',
          'uuid': 'u-2',
          'kind': 'text',
          'role': 'agent',
          'content': 'A second',
          'seq': 3,
          'createdAt': 300,
        },
        <String, dynamic>{
          'id': 'orph-3',
          'isSidechain': true,
          'parentUuid': 'parent-B',
          'uuid': 'u-3',
          'kind': 'text',
          'role': 'agent',
          'content': 'B first',
          'seq': 4,
          'createdAt': 400,
        },
      ]);

      final absorbed = sync.testAbsorbOrphansIntoSyntheticTasks('s1');
      expect(absorbed, isTrue);

      final messages = sync.testGetSessionMessages('s1');
      // Original text + one synthetic Task per parentUuid (A, B).
      expect(messages, hasLength(3));

      // No top-level isSidechain entries remain.
      expect(
        messages.where((m) => m['isSidechain'] == true).toList(),
        isEmpty,
        reason: 'orphans must be moved off the top-level list',
      );

      final tasks = messages
          .where((m) =>
              m['kind'] == 'tool-call' && m['name'] == 'Task')
          .toList();
      expect(tasks, hasLength(2));

      // Synthetic Task A should contain its two children.
      final taskA = tasks.firstWhere(
        (t) => t['uuid'] == 'parent-A',
      );
      expect(taskA['_orphanRecovery'], isTrue);
      expect(taskA['id'], 'orphan-recovery-parent-A');
      final childrenA =
          (taskA['children'] as List).cast<Map<String, dynamic>>();
      expect(childrenA.map((c) => c['id']), ['orph-1', 'orph-2']);

      // Synthetic Task B should contain its single child.
      final taskB = tasks.firstWhere(
        (t) => t['uuid'] == 'parent-B',
      );
      final childrenB =
          (taskB['children'] as List).cast<Map<String, dynamic>>();
      expect(childrenB.map((c) => c['id']), ['orph-3']);
    });

    test('returns false when there are no orphan sidechains', () {
      sync.testSetSessionMessages('s1', [
        <String, dynamic>{
          'id': 'text-1',
          'kind': 'text',
          'role': 'user',
          'content': 'hello',
          'seq': 1,
        },
      ]);

      final absorbed = sync.testAbsorbOrphansIntoSyntheticTasks('s1');
      expect(absorbed, isFalse);

      final messages = sync.testGetSessionMessages('s1');
      expect(messages, hasLength(1));
      expect(messages.first['id'], 'text-1');
    });

    test('groups orphans without parentUuid into a single bucket', () {
      sync.testSetSessionMessages('s1', [
        <String, dynamic>{
          'id': 'orph-1',
          'isSidechain': true,
          'kind': 'text',
          'role': 'agent',
          'content': 'unparented A',
          'seq': 5,
        },
        <String, dynamic>{
          'id': 'orph-2',
          'isSidechain': true,
          'kind': 'text',
          'role': 'agent',
          'content': 'unparented B',
          'seq': 6,
        },
      ]);

      final absorbed = sync.testAbsorbOrphansIntoSyntheticTasks('s1');
      expect(absorbed, isTrue);

      final messages = sync.testGetSessionMessages('s1');
      expect(messages, hasLength(1));
      final task = messages.first;
      expect(task['kind'], 'tool-call');
      expect(task['name'], 'Task');
      expect(task['uuid'], isNull,
          reason: 'unparented orphans must not invent a uuid');
      final children =
          (task['children'] as List).cast<Map<String, dynamic>>();
      expect(children.map((c) => c['id']), ['orph-1', 'orph-2']);
    });

    test('synthetic Task uses the earliest seq and createdAt of its '
        'children (sort stability)', () {
      sync.testSetSessionMessages('s1', [
        <String, dynamic>{
          'id': 'orph-late',
          'isSidechain': true,
          'parentUuid': 'parent-A',
          'kind': 'text',
          'seq': 50,
          'createdAt': 5000,
        },
        <String, dynamic>{
          'id': 'orph-early',
          'isSidechain': true,
          'parentUuid': 'parent-A',
          'kind': 'text',
          'seq': 10,
          'createdAt': 1000,
        },
      ]);

      sync.testAbsorbOrphansIntoSyntheticTasks('s1');

      final messages = sync.testGetSessionMessages('s1');
      final task = messages.first;
      expect(task['seq'], 10);
      expect(task['createdAt'], 1000);
    });

    test('synthetic Task uuid lets future orphan-grouping passes '
        'attach later sidechains for the same parent', () {
      // Cold start: cache restore yields orphans with no Task in
      // the list.  Absorb them; a brand-new sidechain then arrives
      // via socket inline processing.  When the grouper next runs
      // (e.g. after onSessionVisible re-fetch), the synthetic
      // Task's uuid==parentUuid lets it index as a Task and the
      // new sidechain attaches naturally.
      sync.testSetSessionMessages('s1', [
        <String, dynamic>{
          'id': 'orph-1',
          'isSidechain': true,
          'parentUuid': 'parent-X',
          'kind': 'text',
          'seq': 1,
        },
      ]);

      sync.testAbsorbOrphansIntoSyntheticTasks('s1');

      final after = sync.testGetSessionMessages('s1');
      expect(after, hasLength(1));
      final synthetic = after.first;
      expect(synthetic['uuid'], 'parent-X');
      expect(synthetic['kind'], 'tool-call');
      expect(synthetic['name'], 'Task');
    });

    // ── Chain-root coalescing (regression: subagent fragmentation) ──
    test('chain-root coalesce: orphans whose parentUuids form a chain '
        'collapse into ONE synthetic Task per logical subagent', () {
      // Subagent transcripts chain via the previous message uuid.
      // Pre-fix this produced one synthetic per turn (3 here);
      // post-fix it produces one synthetic per logical subagent
      // (the chain root is "task-A" — which is not present in the
      // orphan set, so all three orphans coalesce under it).
      sync.testSetSessionMessages('s1', [
        <String, dynamic>{
          'id': 'orph-1',
          'isSidechain': true,
          'uuid': 'u1',
          'parentUuid': 'task-A',
          'kind': 'text',
          'role': 'agent',
          'seq': 10,
        },
        <String, dynamic>{
          'id': 'orph-2',
          'isSidechain': true,
          'uuid': 'u2',
          'parentUuid': 'u1',
          'kind': 'text',
          'role': 'agent',
          'seq': 11,
        },
        <String, dynamic>{
          'id': 'orph-3',
          'isSidechain': true,
          'uuid': 'u3',
          'parentUuid': 'u2',
          'kind': 'tool-call',
          'name': 'Bash',
          'role': 'agent',
          'seq': 12,
        },
      ]);

      final absorbed = sync.testAbsorbOrphansIntoSyntheticTasks('s1');
      expect(absorbed, isTrue);

      final messages = sync.testGetSessionMessages('s1');
      // ONE synthetic Task — not three.
      expect(messages, hasLength(1));
      final task = messages.first;
      expect(task['_orphanRecovery'], isTrue);
      expect(task['uuid'], 'task-A',
          reason: 'synthetic uuid is the chain root, not an intermediate');
      final children =
          (task['children'] as List).cast<Map<String, dynamic>>();
      expect(children.map((c) => c['id']),
          ['orph-1', 'orph-2', 'orph-3']);
    });

    test('chain-root coalesce: two independent subagent chains '
        'produce two synthetics', () {
      sync.testSetSessionMessages('s1', [
        // Chain A: rootA → uA1 → uA2
        <String, dynamic>{
          'id': 'a1',
          'isSidechain': true,
          'uuid': 'uA1',
          'parentUuid': 'rootA',
          'seq': 1,
        },
        <String, dynamic>{
          'id': 'a2',
          'isSidechain': true,
          'uuid': 'uA2',
          'parentUuid': 'uA1',
          'seq': 2,
        },
        // Chain B: rootB → uB1
        <String, dynamic>{
          'id': 'b1',
          'isSidechain': true,
          'uuid': 'uB1',
          'parentUuid': 'rootB',
          'seq': 3,
        },
      ]);

      sync.testAbsorbOrphansIntoSyntheticTasks('s1');

      final messages = sync.testGetSessionMessages('s1');
      expect(messages, hasLength(2));
      final taskRoots = messages.map((m) => m['uuid']).toSet();
      expect(taskRoots, {'rootA', 'rootB'});
    });

    // ── Synthetic dissolution (fix #4) ──
    group('dissolve stale synthetics on real Task arrival', () {
      test('dissolves synthetic when its uuid matches a real Task uuid',
          () {
        // Post-absorb state: synthetic with uuid=task-A holds two
        // children.  Then a real Task with the same uuid arrives.
        sync.testSetSessionMessages('s1', [
          <String, dynamic>{
            'id': 'real-task',
            'kind': 'tool-call',
            'name': 'Task',
            'role': 'agent',
            'uuid': 'task-A',
            'toolUseId': 'toolu_real',
            'seq': 5,
          },
          <String, dynamic>{
            'id': 'orphan-recovery-task-A',
            '_orphanRecovery': true,
            'kind': 'tool-call',
            'name': 'Task',
            'uuid': 'task-A',
            'children': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'c1',
                'isSidechain': true,
                'uuid': 'u1',
                'parentUuid': 'task-A',
                'seq': 6,
              },
              <String, dynamic>{
                'id': 'c2',
                'isSidechain': true,
                'uuid': 'u2',
                'parentUuid': 'u1',
                'seq': 7,
              },
            ],
            'seq': 6,
          },
        ]);

        final dissolved = sync.testDissolveStaleOrphanSynthetics('s1');
        expect(dissolved, isTrue);

        final after = sync.testGetSessionMessages('s1');
        // Real Task remains; synthetic is gone; children flattened.
        expect(after.where((m) => m['_orphanRecovery'] == true),
            isEmpty);
        expect(after.where((m) => m['id'] == 'real-task'), hasLength(1));
        final flattenedIds = after.where((m) => m['isSidechain'] == true)
            .map((m) => m['id'])
            .toList();
        expect(flattenedIds, ['c1', 'c2']);
      });

      test('dissolves synthetic when a child chain resolves to a real '
          'Task toolUseId', () {
        sync.testSetSessionMessages('s1', [
          <String, dynamic>{
            'id': 'real-task',
            'kind': 'tool-call',
            'name': 'Agent',
            'role': 'agent',
            'uuid': 'real-uuid',
            'toolUseId': 'toolu_xyz',
            'seq': 1,
          },
          <String, dynamic>{
            'id': 'orphan-recovery-toolu_xyz',
            '_orphanRecovery': true,
            'kind': 'tool-call',
            'name': 'Task',
            'uuid': 'toolu_xyz',
            'children': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'c1',
                'isSidechain': true,
                'uuid': 'cu1',
                'parentUuid': 'toolu_xyz',
                'seq': 2,
              },
            ],
            'seq': 2,
          },
        ]);

        expect(sync.testDissolveStaleOrphanSynthetics('s1'), isTrue);
        final after = sync.testGetSessionMessages('s1');
        expect(after.where((m) => m['_orphanRecovery'] == true),
            isEmpty);
      });

      test('does NOT dissolve synthetic when no real Task can resolve '
          'its chain', () {
        sync.testSetSessionMessages('s1', [
          <String, dynamic>{
            'id': 'orphan-recovery-mystery',
            '_orphanRecovery': true,
            'kind': 'tool-call',
            'name': 'Task',
            'uuid': 'mystery',
            'children': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'c1',
                'isSidechain': true,
                'uuid': 'cu1',
                'parentUuid': 'mystery',
                'seq': 1,
              },
            ],
            'seq': 1,
          },
        ]);

        expect(sync.testDissolveStaleOrphanSynthetics('s1'), isFalse);
        final after = sync.testGetSessionMessages('s1');
        expect(after, hasLength(1));
        expect(after.first['_orphanRecovery'], isTrue);
      });

      test('grouping pass dissolves stale synthetic and re-attaches '
          'children to real Task end-to-end', () {
        // Cold-start scenario: cache had only sidechain children
        // (parent Task was truncated).  Absorb -> synthetic.  Then
        // fetchMessages backfills the real Task.  testGroupSidechainMessages
        // must dissolve the synthetic and re-attach its children to
        // the real Task as Task.children.
        sync.testSetSessionMessages('s1', [
          <String, dynamic>{
            'id': 'c1',
            'isSidechain': true,
            'uuid': 'cu1',
            'parentUuid': 'task-real',
            'role': 'agent',
            'kind': 'text',
            'seq': 2,
          },
          <String, dynamic>{
            'id': 'c2',
            'isSidechain': true,
            'uuid': 'cu2',
            'parentUuid': 'cu1',
            'role': 'agent',
            'kind': 'text',
            'seq': 3,
          },
        ]);
        sync.testAbsorbOrphansIntoSyntheticTasks('s1');

        // Backfill the real Task and trigger grouping.
        final state = sync.testGetSessionMessages('s1');
        final withReal = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'real-task',
            'kind': 'tool-call',
            'name': 'Task',
            'role': 'agent',
            'uuid': 'task-real',
            'toolUseId': 'toolu_real',
            'seq': 1,
          },
          ...state,
        ];
        sync.testSetSessionMessages('s1', withReal);
        sync.testGroupSidechainMessages('s1');

        final after = sync.testGetSessionMessages('s1');
        // No synthetic remains.
        expect(after.where((m) => m['_orphanRecovery'] == true),
            isEmpty);
        // Real Task picked up the children.
        final realTask = after.firstWhere(
            (m) => m['id'] == 'real-task');
        final children = (realTask['children'] as List?)
            ?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
        expect(children.map((c) => c['id']).toList(), ['c1', 'c2']);
      });
    });

    // ── Cache strip on save (fix #5) ──
    group('strip orphan synthetics on cache save', () {
      test('replaces synthetic Tasks with flattened sidechain children',
          () {
        final input = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'real-1',
            'kind': 'tool-call',
            'name': 'Bash',
            'role': 'agent',
            'seq': 1,
          },
          <String, dynamic>{
            'id': 'orphan-recovery-X',
            '_orphanRecovery': true,
            'kind': 'tool-call',
            'name': 'Task',
            'uuid': 'X',
            'children': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'c1',
                'isSidechain': true,
                'uuid': 'u1',
                'parentUuid': 'X',
                'seq': 2,
              },
              <String, dynamic>{
                'id': 'c2',
                'isSidechain': true,
                'uuid': 'u2',
                'parentUuid': 'u1',
                'seq': 3,
              },
            ],
            'seq': 2,
          },
          <String, dynamic>{
            'id': 'real-2',
            'kind': 'text',
            'role': 'agent',
            'seq': 4,
          },
        ];

        final stripped = SyncTestHelpers.testStripOrphanSynthetics(input);
        // Real messages preserved; synthetic replaced with its 2 children.
        expect(stripped.map((m) => m['id']).toList(),
            ['real-1', 'c1', 'c2', 'real-2']);
        // Children are reset to top-level isSidechain entries.
        expect(stripped[1]['isSidechain'], isTrue);
        expect(stripped[2]['isSidechain'], isTrue);
        // No synthetics remain.
        expect(stripped.where((m) => m['_orphanRecovery'] == true),
            isEmpty);
      });

      test('returns the same list when no synthetics are present', () {
        final input = <Map<String, dynamic>>[
          <String, dynamic>{'id': 'a', 'kind': 'text', 'seq': 1},
          <String, dynamic>{'id': 'b', 'kind': 'text', 'seq': 2},
        ];
        final stripped = SyncTestHelpers.testStripOrphanSynthetics(input);
        expect(identical(stripped, input), isTrue,
            reason: 'no-op path must avoid allocation');
      });
    });

    // ── Sweep-count delay before absorb (fix #2) ──
    group('delays absorb until multiple no-progress sweeps', () {
      test('does NOT absorb after first no-progress sweep', () {
        // Orphans present with no parent Task.  After one sweep with
        // no progress, absorb must NOT run — we need 2 consecutive
        // sweeps before absorbing.
        sync.testSetSessionMessages('s1', [
          <String, dynamic>{
            'id': 'orph-1',
            'isSidechain': true,
            'uuid': 'u1',
            'parentUuid': 'task-A',
            'role': 'agent',
            'kind': 'text',
            'seq': 2,
          },
          <String, dynamic>{
            'id': 'orph-2',
            'isSidechain': true,
            'uuid': 'u2',
            'parentUuid': 'u1',
            'role': 'agent',
            'kind': 'tool-call',
            'name': 'Bash',
            'seq': 3,
          },
        ]);
        expect(sync.testGetSidechainRegroupSweepCount('s1'), 0);

        // First sweep — still orphan but count < 2, no absorb.
        sync.testRunDeferredRegroupSweep('s1');
        expect(sync.testGetSidechainRegroupSweepCount('s1'), 1);

        // Still no absorb — orphans should remain at top level.
        final after1 = sync.testGetSessionMessages('s1');
        final orphanCount1 = after1
            .where((m) => m['isSidechain'] == true)
            .length;
        expect(orphanCount1, 2,
            reason: 'absorb must not have run after only 1 no-progress sweep');

        // No synthetic Task created.
        expect(
          after1.where((m) => m['_orphanRecovery'] == true),
          isEmpty,
        );
      });

      test('absorbs after second consecutive no-progress sweep', () {
        sync.testSetSessionMessages('s1', [
          <String, dynamic>{
            'id': 'orph-1',
            'isSidechain': true,
            'uuid': 'u1',
            'parentUuid': 'task-A',
            'role': 'agent',
            'kind': 'text',
            'seq': 2,
          },
        ]);
        // First sweep — no progress.
        sync.testRunDeferredRegroupSweep('s1');
        expect(sync.testGetSidechainRegroupSweepCount('s1'), 1);

        // Second sweep with same orphans — now absorb should fire.
        sync.testRunDeferredRegroupSweep('s1');
        expect(sync.testGetSidechainRegroupSweepCount('s1'), 2);

        final after = sync.testGetSessionMessages('s1');
        // One synthetic Task for the chain-root.
        final synthetics = after.where((m) => m['_orphanRecovery'] == true);
        expect(synthetics, hasLength(1));
        expect(synthetics.first['uuid'], 'task-A');
        // Children absorbed.
        expect(
          after.where((m) => m['isSidechain'] == true),
          isEmpty,
        );
      });

      test('new message resets sweep count before absorb threshold', () {
        sync.testSetSessionMessages('s1', [
          <String, dynamic>{
            'id': 'orph-1',
            'isSidechain': true,
            'uuid': 'u1',
            'parentUuid': 'task-A',
            'role': 'agent',
            'kind': 'text',
            'seq': 2,
          },
        ]);
        // First sweep — no progress, count = 1.
        sync.testRunDeferredRegroupSweep('s1');
        expect(sync.testGetSidechainRegroupSweepCount('s1'), 1);

        // Simulate a new message arriving (resets counter).
        sync.testResetSidechainRegroupSweepCount('s1');
        expect(sync.testGetSidechainRegroupSweepCount('s1'), 0);

        // Second sweep should NOT absorb yet (count reset to 0).
        sync.testRunDeferredRegroupSweep('s1');
        expect(sync.testGetSidechainRegroupSweepCount('s1'), 1);

        final after = sync.testGetSessionMessages('s1');
        expect(after.where((m) => m['_orphanRecovery'] == true),
            isEmpty,
            reason: 'reset mid-flight must prevent absorb on second sweep');
      });

      test('dissolve of stale synthetic resets sweep count', () {
        // Pre-state: synthetic from a prior absorb is present, and
        // a real Task has just arrived (will dissolve the synthetic).
        sync.testSetSessionMessages('s1', [
          <String, dynamic>{
            'id': 'real-task',
            'kind': 'tool-call',
            'name': 'Task',
            'role': 'agent',
            'uuid': 'task-A',
            'seq': 1,
          },
          <String, dynamic>{
            'id': 'orphan-recovery-task-A',
            '_orphanRecovery': true,
            'kind': 'tool-call',
            'name': 'Task',
            'uuid': 'task-A',
            'children': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'c1',
                'isSidechain': true,
                'uuid': 'cu1',
                'parentUuid': 'task-A',
                'seq': 2,
              },
            ],
            'seq': 2,
          },
        ]);

        // Simulate prior failed sweeps (count = 1).
        // Note: _groupSidechainMessages calls _dissolveStaleOrphanSynthetics
        // first, which will dissolve the synthetic and reset count.
        sync.testRunDeferredRegroupSweep('s1');

        final after = sync.testGetSessionMessages('s1');
        // Synthetic dissolved; children back at top level.
        expect(after.where((m) => m['_orphanRecovery'] == true),
            isEmpty);
        final isSidechainChildren =
            after.where((m) => m['isSidechain'] == true).toList();
        expect(isSidechainChildren, hasLength(1));
        expect(isSidechainChildren.first['id'], 'c1');
      });
    });

    // ── End-to-end: all three fixes working together ──
    group('end-to-end: sweep delay + chain-root coalesce + dissolve', () {
      test('real Task backfill after sweep-delay absorbs and then '
          'dissolves correctly', () {
        // Cold-start: only orphans in cache, no parent Task.
        sync.testSetSessionMessages('s1', [
          <String, dynamic>{
            'id': 'c1',
            'isSidechain': true,
            'uuid': 'cu1',
            'parentUuid': 'task-A',
            'role': 'agent',
            'kind': 'text',
            'seq': 2,
          },
          <String, dynamic>{
            'id': 'c2',
            'isSidechain': true,
            'uuid': 'cu2',
            'parentUuid': 'cu1',
            'role': 'agent',
            'kind': 'text',
            'seq': 3,
          },
        ]);

        // Sweep 1: no absorb yet.
        sync.testRunDeferredRegroupSweep('s1');
        expect(sync.testGetSidechainRegroupSweepCount('s1'), 1);
        expect(sync.testGetSessionMessages('s1')
                .where((m) => m['_orphanRecovery'] == true),
            isEmpty,
            reason: 'absorb must not fire on first sweep');

        // Sweep 2: now we absorb — chain-root coalesce produces ONE
        // synthetic Task (not two per-orphan).
        sync.testRunDeferredRegroupSweep('s1');
        final afterAbsorb = sync.testGetSessionMessages('s1');
        final synthetics = afterAbsorb
            .where((m) => m['_orphanRecovery'] == true)
            .toList();
        expect(synthetics, hasLength(1));
        expect(synthetics.first['uuid'], 'task-A');
        expect(
          (synthetics.first['children'] as List).length,
          2,
          reason: 'both orphans must be in the single synthetic',
        );

        // Now the real Task backfills via fetchMessages.
        final state = sync.testGetSessionMessages('s1');
        final withReal = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'real-task',
            'kind': 'tool-call',
            'name': 'Task',
            'role': 'agent',
            'uuid': 'task-A',
            'toolUseId': 'toolu_A',
            'seq': 1,
          },
          ...state,
        ];
        sync.testSetSessionMessages('s1', withReal);

        // Next grouping pass must dissolve the synthetic and re-attach
        // children to the real Task.
        sync.testGroupSidechainMessages('s1');

        final afterDissolve = sync.testGetSessionMessages('s1');
        // Synthetic gone.
        expect(afterDissolve.where((m) => m['_orphanRecovery'] == true),
            isEmpty);
        // Real Task has both children.
        final realTask = afterDissolve
            .firstWhere((m) => m['id'] == 'real-task');
        final children = (realTask['children'] as List?)
            ?.cast<Map<String, dynamic>>() ?? const [];
        expect(children.map((c) => c['id']).toList(),
            ['c1', 'c2']);
      });
    });
  });
}
