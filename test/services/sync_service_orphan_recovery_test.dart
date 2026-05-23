import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
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
          .where((m) => m['kind'] == 'tool-call' && m['name'] == 'Task')
          .toList();
      expect(tasks, hasLength(2));

      // Synthetic Task A should contain its two children.
      final taskA = tasks.firstWhere((t) => t['uuid'] == 'parent-A');
      expect(taskA['_orphanRecovery'], isTrue);
      expect(taskA['id'], 'orphan-recovery-parent-A');
      final childrenA = (taskA['children'] as List)
          .cast<Map<String, dynamic>>();
      expect(childrenA.map((c) => c['id']), ['orph-1', 'orph-2']);

      // Synthetic Task B should contain its single child.
      final taskB = tasks.firstWhere((t) => t['uuid'] == 'parent-B');
      final childrenB = (taskB['children'] as List)
          .cast<Map<String, dynamic>>();
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

    test('does not report exhausted-history absorption as unresolved '
        'Sentry warning', () {
      sync.testSetSessionMessages('s1', [
        <String, dynamic>{
          'id': 'orph-1',
          'isSidechain': true,
          'parentUuid': 'parent-A',
          'uuid': 'u-1',
          'kind': 'text',
          'seq': 2,
        },
      ]);
      sync.testSetSessionFirstLoadedSeq('s1', 0);

      expect(sync.hasOlderMessages('s1'), isFalse);
      expect(
        sync.testReportOrphanAbsorbToSentry(
          sessionId: 's1',
          orphanCount: 1,
          triedFetchOlder: false,
          hasMoreOlder: sync.hasOlderMessages('s1'),
        ),
        isFalse,
        reason:
            'when firstLoadedSeq=0, there is no parent page left to '
            'fetch; the synthetic Task is expected UI recovery',
      );
    });

    // ─── GlitchTip HAPPY_FLUTTER-3C9: happy-path absorption ───────────
    //
    // Issue 3497 logged 100+ "Sidechain orphans absorbed into synthetic
    // Task (parent Task missing from history)" Sentry events/week on
    // what turned out to be the normal recovery path. These tests
    // pin the gating contract so the dominant non-anomalous shapes
    // never report to Sentry again.
    test('does not report when no fetchOlder was attempted '
        '(GlitchTip 3497 happy path)', () {
      // No older fetch has occurred yet — orphans were absorbed on
      // the very first pass. There is no evidence of a real data
      // gap; reporting this case is pure noise.
      expect(
        sync.testReportOrphanAbsorbToSentry(
          sessionId: 's1',
          orphanCount: 3,
          triedFetchOlder: false,
          hasMoreOlder: true,
        ),
        isFalse,
        reason: 'absorption without a prior fetchOlder is happy-path '
            'recovery, not an anomaly worth a Sentry event',
      );
    });

    test('does not report when only a small number of orphans were '
        'absorbed even after fetchOlder', () {
      // A single straggler orphan is well within the normal
      // sidechain recovery envelope.
      expect(
        sync.testReportOrphanAbsorbToSentry(
          sessionId: 's1',
          orphanCount: 1,
          triedFetchOlder: true,
          hasMoreOlder: true,
        ),
        isFalse,
        reason: 'small orphan counts are routine recovery, not an '
            'anomaly worth a Sentry event',
      );
    });

    test('reports only when fetchOlder was tried and a non-trivial '
        'orphan count remained stuck', () {
      // Anomalous: we paged back through history, there is still
      // more history available, AND a large pile of orphans is
      // still unresolved. This is the only shape we want to know
      // about in Sentry.
      expect(
        sync.testReportOrphanAbsorbToSentry(
          sessionId: 's1',
          orphanCount: SyncMessagingMerge.kOrphanAbsorbSentryMinCount,
          triedFetchOlder: true,
          hasMoreOlder: true,
        ),
        isTrue,
        reason: 'triedFetchOlder + hasMoreOlder + count >= threshold '
            'indicates a true data gap worth investigating',
      );
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
      expect(
        task['uuid'],
        isNull,
        reason: 'unparented orphans must not invent a uuid',
      );
      final children = (task['children'] as List).cast<Map<String, dynamic>>();
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
      expect(
        task['uuid'],
        'task-A',
        reason: 'synthetic uuid is the chain root, not an intermediate',
      );
      final children = (task['children'] as List).cast<Map<String, dynamic>>();
      expect(children.map((c) => c['id']), ['orph-1', 'orph-2', 'orph-3']);
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
      test('dissolves synthetic when its uuid matches a real Task uuid', () {
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
        expect(after.where((m) => m['_orphanRecovery'] == true), isEmpty);
        expect(after.where((m) => m['id'] == 'real-task'), hasLength(1));
        final flattenedIds = after
            .where((m) => m['isSidechain'] == true)
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
        expect(after.where((m) => m['_orphanRecovery'] == true), isEmpty);
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
        expect(after.where((m) => m['_orphanRecovery'] == true), isEmpty);
        // Real Task picked up the children.
        final realTask = after.firstWhere((m) => m['id'] == 'real-task');
        final children =
            (realTask['children'] as List?)?.cast<Map<String, dynamic>>() ??
            const <Map<String, dynamic>>[];
        expect(children.map((c) => c['id']).toList(), ['c1', 'c2']);
      });
    });

    // ── Cache strip on save (fix #5) ──
    group('strip orphan synthetics on cache save', () {
      test('replaces synthetic Tasks with flattened sidechain children', () {
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
        expect(stripped.map((m) => m['id']).toList(), [
          'real-1',
          'c1',
          'c2',
          'real-2',
        ]);
        // Children are reset to top-level isSidechain entries.
        expect(stripped[1]['isSidechain'], isTrue);
        expect(stripped[2]['isSidechain'], isTrue);
        // No synthetics remain.
        expect(stripped.where((m) => m['_orphanRecovery'] == true), isEmpty);
      });

      test('returns the same list when no synthetics are present', () {
        final input = <Map<String, dynamic>>[
          <String, dynamic>{'id': 'a', 'kind': 'text', 'seq': 1},
          <String, dynamic>{'id': 'b', 'kind': 'text', 'seq': 2},
        ];
        final stripped = SyncTestHelpers.testStripOrphanSynthetics(input);
        expect(
          identical(stripped, input),
          isTrue,
          reason: 'no-op path must avoid allocation',
        );
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
        expect(
          orphanCount1,
          2,
          reason: 'absorb must not have run after only 1 no-progress sweep',
        );

        // No synthetic Task created.
        expect(after1.where((m) => m['_orphanRecovery'] == true), isEmpty);
      });

      test('absorbs after fourth consecutive no-progress sweep', () {
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
        // Sweeps 1–3 — no progress, not enough to absorb yet.
        sync.testRunDeferredRegroupSweep('s1');
        expect(sync.testGetSidechainRegroupSweepCount('s1'), 1);
        sync.testRunDeferredRegroupSweep('s1');
        expect(sync.testGetSidechainRegroupSweepCount('s1'), 2);
        sync.testRunDeferredRegroupSweep('s1');
        expect(sync.testGetSidechainRegroupSweepCount('s1'), 3);
        expect(
          sync.testGetSessionMessages('s1').where(
            (m) => m['_orphanRecovery'] == true,
          ),
          isEmpty,
          reason: 'absorb must not fire before 4 consecutive no-progress sweeps',
        );

        // Fourth sweep with same orphans — now absorb should fire.
        sync.testRunDeferredRegroupSweep('s1');
        expect(sync.testGetSidechainRegroupSweepCount('s1'), 4);

        final after = sync.testGetSessionMessages('s1');
        // One synthetic Task for the chain-root.
        final synthetics = after.where((m) => m['_orphanRecovery'] == true);
        expect(synthetics, hasLength(1));
        expect(synthetics.first['uuid'], 'task-A');
        // Children absorbed.
        expect(after.where((m) => m['isSidechain'] == true), isEmpty);
      });

      test('repeated no-progress sweeps terminate (no infinite loop)', () {
        // Regression for production log showing a session pinned in
        // "1/2 no-progress sweeps — deferring absorb" forever, every
        // ~300ms, because the sweep counter was reset at the top of
        // _runDeferredRegroupSweep on every invocation.  The counter
        // must persist across consecutive no-progress sweeps so the
        // absorb path is reached within a bounded number of attempts.
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

        // Simulate the timer firing repeatedly with no new data and
        // no message-arrival reset.  Absorb must run within a small
        // bounded number of sweeps; remaining sweeps must be no-ops
        // because there are no orphans left.
        for (var i = 0; i < 20; i++) {
          sync.testRunDeferredRegroupSweep('s1');
        }

        final after = sync.testGetSessionMessages('s1');
        expect(
          after.where((m) => m['isSidechain'] == true),
          isEmpty,
          reason:
              'orphan must be absorbed within bounded sweeps — '
              'production hit "1/2 no-progress" forever',
        );
        expect(after.where((m) => m['_orphanRecovery'] == true), hasLength(1));
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
        expect(
          after.where((m) => m['_orphanRecovery'] == true),
          isEmpty,
          reason: 'reset mid-flight must prevent absorb on second sweep',
        );
      });

      test('dissolve of stale synthetic releases children to top level', () {
        // Pre-state: synthetic from a prior absorb is present, and
        // a real Task has just arrived.  The dissolver releases the
        // synthetic's children back to the top-level list with their
        // isSidechain flag intact, so the next grouping pass can
        // re-attach them to the real Task.  This test isolates the
        // dissolve step; the grouping pass is covered by the e2e
        // test below.
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

        final dissolved = sync.testDissolveStaleOrphanSynthetics('s1');
        expect(
          dissolved,
          isTrue,
          reason: 'real Task uuid matches synthetic uuid → must dissolve',
        );

        final after = sync.testGetSessionMessages('s1');
        // Synthetic dissolved; children back at top level.
        expect(after.where((m) => m['_orphanRecovery'] == true), isEmpty);
        final isSidechainChildren = after
            .where((m) => m['isSidechain'] == true)
            .toList();
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

        // Sweeps 1–3: no absorb yet (threshold is 4 consecutive sweeps).
        sync.testRunDeferredRegroupSweep('s1');
        expect(sync.testGetSidechainRegroupSweepCount('s1'), 1);
        expect(
          sync
              .testGetSessionMessages('s1')
              .where((m) => m['_orphanRecovery'] == true),
          isEmpty,
          reason: 'absorb must not fire on first sweep',
        );
        sync.testRunDeferredRegroupSweep('s1');
        expect(sync.testGetSidechainRegroupSweepCount('s1'), 2);
        expect(
          sync
              .testGetSessionMessages('s1')
              .where((m) => m['_orphanRecovery'] == true),
          isEmpty,
          reason: 'absorb must not fire on second sweep',
        );
        sync.testRunDeferredRegroupSweep('s1');
        expect(sync.testGetSidechainRegroupSweepCount('s1'), 3);
        expect(
          sync
              .testGetSessionMessages('s1')
              .where((m) => m['_orphanRecovery'] == true),
          isEmpty,
          reason: 'absorb must not fire on third sweep',
        );

        // Sweep 4: now we absorb — chain-root coalesce produces ONE
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
        expect(
          afterDissolve.where((m) => m['_orphanRecovery'] == true),
          isEmpty,
        );
        // Real Task has both children.
        final realTask = afterDissolve.firstWhere(
          (m) => m['id'] == 'real-task',
        );
        final children =
            (realTask['children'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];
        expect(children.map((c) => c['id']).toList(), ['c1', 'c2']);
      });
    });

    // ── parent_tool_use_id walk-back policy (bug fix) ──
    //
    // The wire stamps `parent_tool_use_id` on every Claude sidechain
    // message. When every visible orphan in the window carries that
    // field AND there is still older history to paginate through,
    // synthesising a "Subagent output (recovered)" tile is premature —
    // the real parent Task is just upstream. The sweep must keep
    // paginating as fast as fetchOlder completes instead of giving up
    // after 4 sweeps and entering the 30s suppression window.
    group('parent_tool_use_id walk-back policy', () {
      late Sync syncWithEnc;
      late int fetchOlderCount;

      setUp(() {
        // We need real session encryption so fetchOlderMessages can
        // pass its `getSessionEncryption(sessionId) == null` guard and
        // hit the testFetchOlderMessagesOverride hook.
        syncWithEnc = createTestSync();
        syncWithEnc.encryption = _OrphanFakeEncryption();
        syncWithEnc.testIsInitialized = true;
        syncWithEnc.testSessions['s2'] = _makeOrphanSession('s2', lastSeq: 500);
        fetchOlderCount = 0;
        syncWithEnc.testFetchOlderMessagesOverride =
            (sessionId, afterSeq, limit) async {
              fetchOlderCount++;
              // Return an empty page so the sweep's follow-up logic
              // doesn't actually upsert anything — we want to isolate
              // the walk-back scheduling behavior.
              return {'messages': <Map<String, dynamic>>[], 'hasMore': true};
            };
      });

      tearDown(() {
        syncWithEnc.testFetchOlderMessagesOverride = null;
        syncWithEnc.testClearSessionMessageState('s2');
      });

      test('does NOT absorb when every orphan has parentToolUseId and '
          'history has more pages — paginates without wall-clock throttle',
          () async {
        syncWithEnc.testSetSessionMessages('s2', [
          <String, dynamic>{
            'id': 'orph-1',
            'isSidechain': true,
            'uuid': 'u1',
            'parentUuid': 'task-A',
            'parentToolUseId': 'toolu_A',
            'role': 'agent',
            'kind': 'text',
            'seq': 102,
          },
          <String, dynamic>{
            'id': 'orph-2',
            'isSidechain': true,
            'uuid': 'u2',
            'parentUuid': 'u1',
            'parentToolUseId': 'toolu_A',
            'role': 'agent',
            'kind': 'tool-call',
            'name': 'Bash',
            'seq': 103,
          },
        ]);
        // firstLoadedSeq > 1 means hasOlderMessages == true: history
        // still has pages we haven't walked back through. Use a value
        // large enough that several 100-message pages remain ahead so
        // the across-sweep hasOlderMessages check stays true even
        // after a page-cursor advance.
        syncWithEnc.testSetSessionFirstLoadedSeq('s2', 800);
        expect(syncWithEnc.hasOlderMessages('s2'), isTrue);

        // Sweep 1 — fires fetchOlderMessages. Drain microtasks + the
        // unawaited fetch body so _loadingOlderMessages clears before
        // sweep 2.
        syncWithEnc.testRunDeferredRegroupSweep('s2');
        await _drainAsyncWork();

        expect(fetchOlderCount, 1,
            reason: 'first sweep must call fetchOlderMessages');
        var msgs = syncWithEnc.testGetSessionMessages('s2');
        expect(msgs.where((m) => m['_orphanRecovery'] == true), isEmpty,
            reason: 'no synthetic Task may exist while we can still '
                'paginate to find the real parent');
        // hasOlderMessages must remain true so the next sweep is
        // allowed to paginate further.
        expect(syncWithEnc.hasOlderMessages('s2'), isTrue);

        // Re-seed the orphans because the in-flight fetchOlder ran
        // _groupSidechainMessages on an empty page (which by itself
        // would NOT mutate the orphans, but the sweep follow-up
        // microtask may have reset internal counters). Re-seeding is
        // the simplest way to keep the test focused on the scheduling
        // behavior. Their parentToolUseId stays universal.
        syncWithEnc.testSetSessionMessages('s2', [
          <String, dynamic>{
            'id': 'orph-1',
            'isSidechain': true,
            'uuid': 'u1',
            'parentUuid': 'task-A',
            'parentToolUseId': 'toolu_A',
            'role': 'agent',
            'kind': 'text',
            'seq': 102,
          },
          <String, dynamic>{
            'id': 'orph-2',
            'isSidechain': true,
            'uuid': 'u2',
            'parentUuid': 'u1',
            'parentToolUseId': 'toolu_A',
            'role': 'agent',
            'kind': 'tool-call',
            'name': 'Bash',
            'seq': 103,
          },
        ]);

        // Sweep 2 — should call fetchOlder again without clearing any
        // throttle timestamp; absorb is NOT permitted because every
        // orphan still carries parentToolUseId and history has more
        // pages.
        syncWithEnc.testRunDeferredRegroupSweep('s2');
        await _drainAsyncWork();

        expect(fetchOlderCount, 2,
            reason: 'aggressive mode must allow a second fetchOlder '
                'call rather than absorbing the orphans');
        msgs = syncWithEnc.testGetSessionMessages('s2');
        expect(msgs.where((m) => m['_orphanRecovery'] == true), isEmpty);
        // Top-level orphans must still be present — they were not
        // absorbed into a synthetic Task.
        expect(
          msgs.where((m) => m['isSidechain'] == true).length,
          2,
          reason: 'orphans must remain on the top-level list until '
              'we either find the parent or exhaust history',
        );
      });

      test('aggressive mode does not use the default 60s throttle', () async {
        syncWithEnc.testSetSessionMessages('s2', [
          <String, dynamic>{
            'id': 'orph-1',
            'isSidechain': true,
            'uuid': 'u1',
            'parentUuid': 'task-A',
            'parentToolUseId': 'toolu_A',
            'role': 'agent',
            'kind': 'text',
            'seq': 200,
          },
        ]);
        syncWithEnc.testSetSessionFirstLoadedSeq('s2', 800);

        // First attempt fires.
        syncWithEnc.testRunDeferredRegroupSweep('s2');
        await _drainAsyncWork();
        expect(fetchOlderCount, 1);
        final firstAttemptMs =
            syncWithEnc.testOrphanFetchOlderAttemptedMs('s2');
        expect(firstAttemptMs, greaterThan(0));

        // Re-seed orphans so the post-fetch grouper pass hasn't
        // mutated them away from this test's expectations.
        syncWithEnc.testSetSessionMessages('s2', [
          <String, dynamic>{
            'id': 'orph-1',
            'isSidechain': true,
            'uuid': 'u1',
            'parentUuid': 'task-A',
            'parentToolUseId': 'toolu_A',
            'role': 'agent',
            'kind': 'text',
            'seq': 200,
          },
        ]);

        // Without resetting the timestamp, an immediate second sweep
        // still re-fires fetchOlder. Aggressive mode relies on
        // isLoadingOlderMessages and the fetch completion callback for
        // sequencing, not a wall-clock throttle.
        syncWithEnc.testRunDeferredRegroupSweep('s2');
        await _drainAsyncWork();
        expect(fetchOlderCount, 2,
            reason: 'aggressive mode must bypass the default throttle');
        // No synthetic absorb either, because parentToolUseId+more
        // history defers the absorb path.
        final msgs = syncWithEnc.testGetSessionMessages('s2');
        expect(msgs.where((m) => m['_orphanRecovery'] == true), isEmpty);
      });

      test('mixed parentToolUseId presence falls back to default '
          'behavior — absorbs after 4 sweeps', () {
        syncWithEnc.testSetSessionMessages('s2', [
          <String, dynamic>{
            'id': 'orph-1',
            'isSidechain': true,
            'uuid': 'u1',
            'parentUuid': 'task-A',
            'parentToolUseId': 'toolu_A',
            'role': 'agent',
            'kind': 'text',
            'seq': 50,
          },
          // Missing parentToolUseId — wire didn't stamp it for this
          // entry (e.g. legacy cached row), so we can't trust that
          // pagination will resolve it.
          <String, dynamic>{
            'id': 'orph-2',
            'isSidechain': true,
            'uuid': 'u2',
            'parentUuid': 'task-A',
            'role': 'agent',
            'kind': 'tool-call',
            'name': 'Bash',
            'seq': 51,
          },
        ]);
        syncWithEnc.testSetSessionFirstLoadedSeq('s2', 800);

        // Sweep 1 — default 60s throttle path; fetchOlder fires and
        // sets lastFetchAttempt so the fetchOlder gate is cleared for
        // subsequent sweeps. Not enough sweeps to absorb yet.
        syncWithEnc.testRunDeferredRegroupSweep('s2');
        var msgs = syncWithEnc.testGetSessionMessages('s2');
        expect(msgs.where((m) => m['_orphanRecovery'] == true), isEmpty,
            reason: 'no absorb after 1 sweep');

        // Sweeps 2–3 — throttle still in effect (60s not elapsed) so
        // fetchOlder cannot re-fire; sweep counter increments toward 4.
        syncWithEnc.testRunDeferredRegroupSweep('s2');
        msgs = syncWithEnc.testGetSessionMessages('s2');
        expect(msgs.where((m) => m['_orphanRecovery'] == true), isEmpty,
            reason: 'no absorb after 2 sweeps');

        syncWithEnc.testRunDeferredRegroupSweep('s2');
        msgs = syncWithEnc.testGetSessionMessages('s2');
        expect(msgs.where((m) => m['_orphanRecovery'] == true), isEmpty,
            reason: 'no absorb after 3 sweeps');

        // Sweep 4 — must hit the absorb path: fetchOlder cannot fire
        // (throttle not cleared) and 4 consecutive no-progress sweeps
        // have elapsed.
        // Two orphans with distinct chain roots (toolu_A vs task-A)
        // produce one synthetic per root — that is the existing
        // chain-root coalesce contract, unchanged by this work.
        syncWithEnc.testRunDeferredRegroupSweep('s2');
        msgs = syncWithEnc.testGetSessionMessages('s2');
        expect(msgs.where((m) => m['_orphanRecovery'] == true), hasLength(2),
            reason: 'mixed parentToolUseId must fall back to the '
                'existing 4-sweep absorb path');
        expect(msgs.where((m) => m['isSidechain'] == true), isEmpty,
            reason: 'orphans must be absorbed into the synthetic Task');
      });

      test('universal parentToolUseId but no more history — absorbs as '
          'today (exhausted history is the only safe fallback)', () {
        syncWithEnc.testSetSessionMessages('s2', [
          <String, dynamic>{
            'id': 'orph-1',
            'isSidechain': true,
            'uuid': 'u1',
            'parentUuid': 'task-A',
            'parentToolUseId': 'toolu_A',
            'role': 'agent',
            'kind': 'text',
            'seq': 2,
          },
          <String, dynamic>{
            'id': 'orph-2',
            'isSidechain': true,
            'uuid': 'u2',
            'parentUuid': 'u1',
            'parentToolUseId': 'toolu_A',
            'role': 'agent',
            'kind': 'tool-call',
            'name': 'Bash',
            'seq': 3,
          },
        ]);
        // firstLoadedSeq == 0 means we've exhausted history — there is
        // no parent page left to fetch.
        syncWithEnc.testSetSessionFirstLoadedSeq('s2', 0);
        expect(syncWithEnc.hasOlderMessages('s2'), isFalse);

        // Sweeps 1–3 — no fetchOlder available (no older history), so
        // sweep count increments but no absorb yet.
        for (var i = 1; i <= 3; i++) {
          syncWithEnc.testRunDeferredRegroupSweep('s2');
          expect(fetchOlderCount, 0,
              reason: 'no history → no fetchOlder attempts');
          final msgs = syncWithEnc.testGetSessionMessages('s2');
          expect(msgs.where((m) => m['_orphanRecovery'] == true), isEmpty,
              reason: 'absorb must not fire before 4 sweeps (i=$i)');
        }

        // Sweep 4 — absorb fires (4 consecutive no-progress sweeps,
        // throttle path didn't help because there is nothing older).
        syncWithEnc.testRunDeferredRegroupSweep('s2');
        final msgs = syncWithEnc.testGetSessionMessages('s2');
        expect(msgs.where((m) => m['_orphanRecovery'] == true), hasLength(1),
            reason: 'with no remaining history, absorption is the '
                'correct fallback even when parentToolUseId is universal');
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers (fake encryption + session factory) for the
// `parent_tool_use_id walk-back policy` group above.
// ---------------------------------------------------------------------------

/// Drains both microtask queue and any pending zero-duration timers
/// (Sentry transaction finish, `await Future.delayed(Duration.zero)`
/// inside `fetchOlderMessages`). Two yields are enough for the chain
/// of awaits in the fetchOlder body to settle.
Future<void> _drainAsyncWork() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Session _makeOrphanSession(String id, {int lastSeq = 10}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 1700000000000,
    updatedAt: 1700000000000,
    active: true,
    activeAt: 1700000000000,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    presence: 'offline',
    lastSeq: lastSeq,
  );
}

class _OrphanFakeEncryption implements Encryption {
  final Map<String, _OrphanFakeSessionEncryption> _sessions = {};

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return _sessions.putIfAbsent(
      sessionId,
      () => _OrphanFakeSessionEncryption(sessionId: sessionId),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _OrphanFakeSessionEncryption extends SessionEncryption {
  _OrphanFakeSessionEncryption({required String sessionId})
      : super(
          sessionId: sessionId,
          encryptor: _OrphanFakeEncryptor(),
          decryptor: _OrphanFakeEncryptor(),
          cache: EncryptionCache(),
        );
}

class _OrphanFakeEncryptor implements Encryptor {
  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    return data.map((item) {
      final json = jsonEncode(item);
      final bytes = utf8.encode(json);
      final output = Uint8List(bytes.length + 1);
      output[0] = 0x01;
      output.setRange(1, output.length, bytes);
      return output;
    }).toList();
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    return data.map((item) {
      if (item.isEmpty) return null;
      try {
        return item[0] == 0x01
            ? jsonDecode(utf8.decode(item.sublist(1)))
            : utf8.decode(item);
      } catch (_) {
        return null;
      }
    }).toList();
  }
}
