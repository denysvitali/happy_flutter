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

/// Contract tests for orphan sidechain handling.
///
/// Background: when a session's parent Task tool-call is missing from
/// the loaded message window (cache truncation, server pagination, or
/// a partial restore), the Task's sidechain children sit at the top of
/// the message list with `isSidechain: true` and no real parent in
/// scope. Historically the sync layer tried to recover these by
/// absorbing them into a `_orphanRecovery: true` synthetic Task tile
/// so the user could at least see "Subagent output (recovered)" in
/// the chat and the agents list. That path:
///   1. silently dropped any sidechain whose chain did not terminate
///      in a known parent uuid (the synthetic's own filtering made
///      the children invisible in the chat list);
///   2. fired the GlitchTip warning HAPPY_FLUTTER-3C9 on every
///      cold-start with stuck orphans, drowning the issue tracker
///      with happy-path recovery events;
///   3. required an elaborate dissolve-on-real-Parent-arrival
///      dance plus a 30s suppression window to avoid re-firing.
///
/// The new contract is simpler: **sidechain messages are never
/// dropped, and they are never absorbed into a synthetic Task**.
/// When a real parent Task is in scope, the grouper attaches the
/// children to its `children` array. When no real parent is in
/// scope, the orphans stay at the top level of the message list
/// and the chat renders them inline — the user always sees the
/// actual subagent output (text, tool-calls) instead of a
/// placeholder tile.
///
/// These tests pin that contract at every level:
///   * no path creates `_orphanRecovery: true` synthetics;
///   * orphans survive an arbitrary number of deferred regroup
///     sweeps, including after the 4-sweep threshold that used
///     to trigger absorb;
///   * the deferred sweep still kicks off fetchOlder when the
///     wire promises a real parent (parent_tool_use_id present)
///     and history is available;
///   * the grouper still attaches orphans to a real Task when one
///     is in scope;
///   * legacy cache scrubbing of pre-fix synthetics still works
///     (defense in depth for users with old MMKV caches).
void main() {
  group('orphan sidechain: never absorb, always preserve', () {
    late Sync sync;

    setUp(() {
      sync = createTestSync();
    });

    tearDown(() {
      sync.testClearSessionMessageState('s1');
    });

    // ── Top-level invariant: no absorb path may create synthetics ──
    test(
      'deferred sweep on stuck orphans NEVER creates '
      '_orphanRecovery synthetics — orphans stay at top level',
      () {
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

        // Run more sweeps than the legacy absorb threshold (4) so a
        // regression cannot sneak past by accident.
        for (var i = 0; i < 8; i++) {
          sync.testRunDeferredRegroupSweep('s1');
        }

        final messages = sync.testGetSessionMessages('s1');
        // No synthetic Task placeholder was ever created.
        expect(
          messages.where((m) => m['_orphanRecovery'] == true).toList(),
          isEmpty,
          reason: 'sidechain messages must never be absorbed into a '
              '_orphanRecovery synthetic Task',
        );
        // Every sidechain message is still on the top-level list so
        // the chat can render it inline.
        final orphanIds = messages
            .where((m) => m['isSidechain'] == true)
            .map((m) => m['id'])
            .toList();
        expect(orphanIds, ['orph-1', 'orph-2', 'orph-3']);
        // Non-sidechain messages also preserved.
        expect(
          messages.where((m) => m['id'] == 'text-1').toList(),
          hasLength(1),
        );
      },
    );

    test(
      'orphans without any parentUuid are preserved verbatim (no '
      'synthetic grouping)',
      () {
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
        for (var i = 0; i < 6; i++) {
          sync.testRunDeferredRegroupSweep('s1');
        }
        final messages = sync.testGetSessionMessages('s1');
        expect(messages, hasLength(2));
        expect(messages.map((m) => m['id']), ['orph-1', 'orph-2']);
        // No synthetic was inserted.
        expect(
          messages.where((m) => m['kind'] == 'tool-call'),
          isEmpty,
          reason: 'no synthetic Task may be created for unparented '
              'orphans — they render inline as text bubbles',
        );
      },
    );

    test(
      'chain-root orphans: long subagent runs do NOT collapse into '
      'a synthetic — each message stays at the top level',
      () {
        // Subagent transcripts chain via the previous message uuid.
        // Pre-fix this would have produced one synthetic per chain
        // (3 here). Post-fix every orphan stays at the top level
        // so the chat can render the actual subagent text in
        // chronological order.
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
        for (var i = 0; i < 6; i++) {
          sync.testRunDeferredRegroupSweep('s1');
        }
        final messages = sync.testGetSessionMessages('s1');
        expect(
          messages.where((m) => m['_orphanRecovery'] == true),
          isEmpty,
        );
        expect(
          messages.where((m) => m['isSidechain'] == true).map(
                (m) => m['id'],
              ),
          ['orph-1', 'orph-2', 'orph-3'],
        );
      },
    );

    test(
      'two independent subagent chains do NOT each get a synthetic',
      () {
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
        for (var i = 0; i < 6; i++) {
          sync.testRunDeferredRegroupSweep('s1');
        }
        final messages = sync.testGetSessionMessages('s1');
        expect(
          messages.where((m) => m['_orphanRecovery'] == true),
          isEmpty,
        );
        expect(
          messages.map((m) => m['id']).toList(),
          ['a1', 'a2', 'b1'],
        );
      },
    );

    // ── Real parent arrival still works through the grouper ──
    test(
      'real Task arrival attaches orphans to its children — no '
      'synthetic was ever needed',
      () {
        // Cold start: only sidechain children in cache, no parent
        // Task. Sweep enough times to exercise the (now-removed)
        // absorb path. Then backfill the real Task and re-run the
        // grouper. The orphans must attach directly to the real
        // Task; no synthetic placeholder should exist at any point.
        sync.testSetSessionMessages('s1', [
          <String, dynamic>{
            'id': 'c1',
            'isSidechain': true,
            'uuid': 'cu1',
            'parentUuid': 'task-real',
            'parentToolUseId': 'toolu_real',
            'role': 'agent',
            'kind': 'text',
            'seq': 2,
          },
          <String, dynamic>{
            'id': 'c2',
            'isSidechain': true,
            'uuid': 'cu2',
            'parentUuid': 'cu1',
            'parentToolUseId': 'toolu_real',
            'role': 'agent',
            'kind': 'text',
            'seq': 3,
          },
        ]);
        for (var i = 0; i < 6; i++) {
          sync.testRunDeferredRegroupSweep('s1');
        }
        // Sweeps must not have absorbed anything.
        expect(
          sync
              .testGetSessionMessages('s1')
              .where((m) => m['_orphanRecovery'] == true),
          isEmpty,
        );

        // Backfill the real Task and re-run the grouper.
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
        // Still no synthetic — we never need one.
        expect(after.where((m) => m['_orphanRecovery'] == true), isEmpty);
        // Real Task picked up the children via parentToolUseId.
        final realTask = after.firstWhere((m) => m['id'] == 'real-task');
        final children =
            (realTask['children'] as List?)?.cast<Map<String, dynamic>>() ??
                const <Map<String, dynamic>>[];
        expect(children.map((c) => c['id']).toList(), ['c1', 'c2']);
      },
    );

    // ── Legacy cache scrub still strips pre-fix synthetics ──
    //
    // Users with pre-fix MMKV caches still have `_orphanRecovery:
    // true` synthetic tiles in their stored message lists. The
    // cache-write path flattens them back to top-level isSidechain
    // messages so a future cold start gets a clean slate. This
    // contract is unchanged by the absorb removal and stays as
    // defense in depth.
    group('legacy cache scrubbing (defense in depth)', () {
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
        // Real messages preserved; synthetic replaced with its 2
        // children.
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
        expect(
          stripped.where((m) => m['_orphanRecovery'] == true),
          isEmpty,
        );
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

    // ── fetchOlder retry path: keep paginating, never absorb ──
    //
    // The deferred sweep still kicks off `fetchOlderMessages` when
    // every visible orphan carries `parent_tool_use_id` AND more
    // history is available. This is the only legitimate "recovery"
    // path; the sweep does NOT create a synthetic Task while it is
    // trying. When history is exhausted, the sweep stops running
    // and the orphans remain inline in the chat.
    group('parent_tool_use_id walk-back policy', () {
      late Sync syncWithEnc;
      late int fetchOlderCount;

      setUp(() {
        // We need real session encryption so fetchOlderMessages can
        // pass its `getSessionEncryption(sessionId) == null` guard
        // and hit the testFetchOlderMessagesOverride hook.
        syncWithEnc = createTestSync();
        syncWithEnc.encryption = _OrphanFakeEncryption();
        syncWithEnc.testIsInitialized = true;
        syncWithEnc.testSessions['s2'] = _makeOrphanSession(
          's2',
          lastSeq: 500,
        );
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

      test(
        'with parentToolUseId and more history: fetchOlder fires, '
        'no absorb occurs',
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
          // firstLoadedSeq > 1 means hasOlderMessages == true.
          syncWithEnc.testSetSessionFirstLoadedSeq('s2', 800);
          expect(syncWithEnc.hasOlderMessages('s2'), isTrue);

          // Sweep 1 — fires fetchOlderMessages. Drain microtasks.
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

          // Re-seed orphans to focus on scheduling behavior.
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

          // Sweep 2 — fetchOlder fires again; absorb remains
          // forbidden.
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
        },
      );

      test(
        'with no remaining history: sweep stops, orphans stay inline',
        () {
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
          // firstLoadedSeq == 0 means history is exhausted.
          syncWithEnc.testSetSessionFirstLoadedSeq('s2', 0);
          expect(syncWithEnc.hasOlderMessages('s2'), isFalse);

          for (var i = 0; i < 8; i++) {
            syncWithEnc.testRunDeferredRegroupSweep('s2');
          }

          // No fetchOlder attempted (no history available).
          expect(fetchOlderCount, 0,
              reason: 'no history → no fetchOlder attempts');
          final msgs = syncWithEnc.testGetSessionMessages('s2');
          // Still no synthetic.
          expect(
            msgs.where((m) => m['_orphanRecovery'] == true),
            isEmpty,
          );
          // Orphans are preserved at the top level so the chat
          // renders them inline.
          expect(
            msgs.where((m) => m['isSidechain'] == true).map(
                  (m) => m['id'],
                ),
            ['orph-1', 'orph-2'],
          );
        },
      );

      test(
        'aggressive mode stops after 3 no-progress attempts and falls '
        'back to the default throttle',
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
          ]);
          syncWithEnc.testSetSessionFirstLoadedSeq('s2', 800);
          expect(syncWithEnc.hasOlderMessages('s2'), isTrue);

          // Run enough sweeps to exhaust the aggressive budget.
          for (var i = 0; i < 3; i++) {
            syncWithEnc.testRunDeferredRegroupSweep('s2');
            await _drainAsyncWork();
            // Re-seed the orphan because the sweep's then() schedules a
            // regroup but the fake fetchOlder returns no messages, so the
            // grouper would otherwise see an empty list on the next pass.
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
            ]);
          }

          expect(
            fetchOlderCount,
            3,
            reason: 'aggressive mode should fire for the first 3 attempts',
          );

          // The next sweep is within the 60s throttle window, so it must
          // NOT fire another fetchOlder and must set suppression.
          syncWithEnc.testRunDeferredRegroupSweep('s2');
          await _drainAsyncWork();

          expect(
            fetchOlderCount,
            3,
            reason: 'after aggressive budget is exhausted, sweep must '
                'respect the default throttle and not call fetchOlder',
          );
          expect(
            syncWithEnc.testGetSessionMessages('s2').where(
              (m) => m['_orphanRecovery'] == true,
            ),
            isEmpty,
          );
        },
      );

      test(
        'new messages reset the no-progress counter so recovery can try '
        'again',
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
          ]);
          syncWithEnc.testSetSessionFirstLoadedSeq('s2', 800);

          // Burn through the aggressive budget.
          for (var i = 0; i < 3; i++) {
            syncWithEnc.testRunDeferredRegroupSweep('s2');
            await _drainAsyncWork();
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
            ]);
          }
          expect(fetchOlderCount, 3);

          // Simulate a new message arriving for the session.
          syncWithEnc.testUpsertSessionMessages('s2', [
            <String, dynamic>{
              'id': 'new-msg',
              'kind': 'text',
              'role': 'user',
              'content': 'hello',
              'seq': 200,
              'createdAt': 1700000002000,
            },
          ]);

          // The next sweep should be allowed to use aggressive mode again
          // because the no-progress counter was reset.
          syncWithEnc.testRunDeferredRegroupSweep('s2');
          await _drainAsyncWork();

          expect(
            fetchOlderCount,
            4,
            reason: 'new messages must reset the no-progress counter',
          );
        },
      );

      test(
        'hard cap gives up and suppresses further work once the no-progress '
        'counter reaches the limit',
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
          ]);
          syncWithEnc.testSetSessionFirstLoadedSeq('s2', 800);

          // Set the counter at the cap. The next sweep must give up
          // immediately without calling fetchOlder and must suppress
          // further work.
          syncWithEnc.testSetOrphanFetchOlderNoProgressCount('s2', 12);

          syncWithEnc.testRunDeferredRegroupSweep('s2');
          await _drainAsyncWork();

          expect(
            fetchOlderCount,
            0,
            reason: 'at the hard cap sweep must not call fetchOlder',
          );

          // Subsequent sweeps are also suppressed.
          for (var i = 0; i < 5; i++) {
            syncWithEnc.testRunDeferredRegroupSweep('s2');
            await _drainAsyncWork();
          }
          expect(
            fetchOlderCount,
            0,
            reason: 'suppression must persist across repeated sweeps',
          );
        },
      );
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
