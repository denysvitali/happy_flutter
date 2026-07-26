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
      // The deferred sweep only does work for the visible session —
      // background sessions defer regrouping until onSessionVisible.
      sync.testSetVisibleSessionId('s1');
    });

    tearDown(() {
      sync.testClearSessionMessageState('s1');
      sync.testSetVisibleSessionId(null);
    });

    // ── Top-level invariant: no absorb path may create synthetics ──
    test('deferred sweep on stuck orphans NEVER creates '
        '_orphanRecovery synthetics — orphans stay at top level', () {
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
        reason:
            'sidechain messages must never be absorbed into a '
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
      expect(messages.where((m) => m['id'] == 'text-1').toList(), hasLength(1));
    });

    test('orphans without any parentUuid are preserved verbatim (no '
        'synthetic grouping)', () {
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
        reason:
            'no synthetic Task may be created for unparented '
            'orphans — they render inline as text bubbles',
      );
    });

    test('chain-root orphans: long subagent runs do NOT collapse into '
        'a synthetic — each message stays at the top level', () {
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
      expect(messages.where((m) => m['_orphanRecovery'] == true), isEmpty);
      expect(
        messages.where((m) => m['isSidechain'] == true).map((m) => m['id']),
        ['orph-1', 'orph-2', 'orph-3'],
      );
    });

    test('two independent subagent chains do NOT each get a synthetic', () {
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
      expect(messages.where((m) => m['_orphanRecovery'] == true), isEmpty);
      expect(messages.map((m) => m['id']).toList(), ['a1', 'a2', 'b1']);
    });

    // ── Real parent arrival still works through the grouper ──
    test('real Task arrival attaches orphans to its children — no '
        'synthetic was ever needed', () {
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
    });

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

    // ── fetchOlder retry path: keep paginating, never absorb ──
    //
    // The deferred sweep still kicks off `fetchOlderMessages` when
    // every visible orphan carries `parent_tool_use_id` AND more
    // history is available. This is the only legitimate "recovery"
    // path; the sweep does NOT create a synthetic Task while it is
    // trying. When history is exhausted, the sweep stops running
    // and the orphans remain inline in the chat.
    group('parent_tool_use_id walk-back policy', () {
      const orphanFetchOlderPageSize = Sync.orphanFetchOlderPageSizeForTesting;
      late Sync syncWithEnc;
      late int fetchOlderCount;
      late List<int> fetchOlderLimits;
      late int orphanAggressiveAttempts;

      setUp(() {
        // We need real session encryption so fetchOlderMessages can
        // pass its `getSessionEncryption(sessionId) == null` guard
        // and hit the testFetchOlderMessagesOverride hook.
        syncWithEnc = createTestSync();
        syncWithEnc.encryption = _OrphanFakeEncryption();
        syncWithEnc.testIsInitialized = true;
        orphanAggressiveAttempts =
            syncWithEnc.testOrphanFetchOlderAggressiveAttempts;
        // Walk-back only runs for the visible session.
        syncWithEnc.testSetVisibleSessionId('s2');
        syncWithEnc.testSessions['s2'] = _makeOrphanSession('s2', lastSeq: 500);
        fetchOlderCount = 0;
        fetchOlderLimits = <int>[];
        syncWithEnc.testFetchOlderMessagesOverride =
            (sessionId, afterSeq, limit) async {
              fetchOlderCount++;
              fetchOlderLimits.add(limit);
              // Return an empty page so the sweep's follow-up logic
              // doesn't actually upsert anything — we want to isolate
              // the walk-back scheduling behavior.
              return {'messages': <Map<String, dynamic>>[], 'hasMore': true};
            };
      });

      tearDown(() {
        syncWithEnc.testFetchOlderMessagesOverride = null;
        syncWithEnc.testClearSessionMessageState('s2');
        syncWithEnc.testSetVisibleSessionId(null);
      });

      test('with parentToolUseId and more history: fetchOlder fires, '
          'no absorb occurs', () async {
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

        expect(
          fetchOlderCount,
          1,
          reason: 'first sweep must call fetchOlderMessages',
        );
        expect(fetchOlderLimits.last, orphanFetchOlderPageSize);
        var msgs = syncWithEnc.testGetSessionMessages('s2');
        expect(
          msgs.where((m) => m['_orphanRecovery'] == true),
          isEmpty,
          reason:
              'no synthetic Task may exist while we can still '
              'paginate to find the real parent',
        );
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
        // forbidden.  Aggressive mode enforces a floor between pages, so
        // clear the throttle stamp to keep this an instant follow-up.
        syncWithEnc.testClearOrphanFetchOlderAttemptedMs('s2');
        syncWithEnc.testRunDeferredRegroupSweep('s2');
        await _drainAsyncWork();

        expect(
          fetchOlderCount,
          2,
          reason:
              'aggressive mode must allow a second fetchOlder '
              'call rather than absorbing the orphans',
        );
        expect(fetchOlderLimits.last, orphanFetchOlderPageSize);
        msgs = syncWithEnc.testGetSessionMessages('s2');
        expect(msgs.where((m) => m['_orphanRecovery'] == true), isEmpty);
        // Top-level orphans must still be present — they were not
        // absorbed into a synthetic Task.
        expect(
          msgs.where((m) => m['isSidechain'] == true).length,
          2,
          reason:
              'orphans must remain on the top-level list until '
              'we either find the parent or exhaust history',
        );
      });

      test('with no remaining history: sweep stops, orphans stay inline', () {
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
        expect(
          fetchOlderCount,
          0,
          reason: 'no history → no fetchOlder attempts',
        );
        final msgs = syncWithEnc.testGetSessionMessages('s2');
        // Still no synthetic.
        expect(msgs.where((m) => m['_orphanRecovery'] == true), isEmpty);
        // Orphans are preserved at the top level so the chat
        // renders them inline.
        expect(
          msgs.where((m) => m['isSidechain'] == true).map((m) => m['id']),
          ['orph-1', 'orph-2'],
        );
      });

      test('aggressive mode stops after bounded no-progress attempts and falls '
          'back to the default throttle', () async {
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
        // Aggressive budget is orphanAggressiveAttempts fetchOlder calls
        // × pageSize 500; bump firstLoadedSeq so the boundary does not
        // collapse to 0 before the budget exhausts (800 seqs of headroom
        // was tightened by the pageSize bump to 500).
        syncWithEnc.testSetSessionFirstLoadedSeq(
          's2',
          orphanAggressiveAttempts * orphanFetchOlderPageSize + 1000,
        );
        expect(syncWithEnc.hasOlderMessages('s2'), isTrue);

        // Run enough sweeps to exhaust the aggressive budget.
        for (var i = 0; i < orphanAggressiveAttempts; i++) {
          // Aggressive mode now enforces a floor between pages; clear the
          // throttle stamp so the loop still exercises the full budget.
          syncWithEnc.testClearOrphanFetchOlderAttemptedMs('s2');
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
          orphanAggressiveAttempts,
          reason: 'aggressive mode should fire for its bounded budget',
        );

        // The next sweep is within the 60s throttle window, so it must
        // NOT fire another fetchOlder and must set suppression.
        syncWithEnc.testRunDeferredRegroupSweep('s2');
        await _drainAsyncWork();

        expect(
          fetchOlderCount,
          orphanAggressiveAttempts,
          reason:
              'after aggressive budget is exhausted, sweep must '
              'respect the default throttle and not call fetchOlder',
        );
        expect(
          syncWithEnc
              .testGetSessionMessages('s2')
              .where((m) => m['_orphanRecovery'] == true),
          isEmpty,
        );
      });

      test(
        'message upserts do NOT reset the no-progress counter — the '
        'walk-back\'s own fetched pages must not refresh its budget',
        () async {
          // Production regression: fetchOlderMessages upserts every page
          // it fetches. A blanket counter reset in _upsertSessionMessages
          // pinned the counter at 1 (reset-then-increment each cycle),
          // so neither the aggressive cutoff nor the hard cap
          // could ever fire — the walk-back fetched older pages every
          // ~450ms indefinitely.
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
          // Burn through the aggressive budget × pageSize 500 seqs each.
          syncWithEnc.testSetSessionFirstLoadedSeq(
            's2',
            orphanAggressiveAttempts * orphanFetchOlderPageSize + 1000,
          );

          // Burn through the aggressive budget.
          for (var i = 0; i < orphanAggressiveAttempts; i++) {
            // Aggressive mode now enforces a floor between pages; clear the
            // throttle stamp so the loop still exercises the full budget.
            syncWithEnc.testClearOrphanFetchOlderAttemptedMs('s2');
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
          expect(fetchOlderCount, orphanAggressiveAttempts);
          expect(
            syncWithEnc.testOrphanFetchOlderNoProgressCount('s2'),
            orphanAggressiveAttempts,
          );

          // A message upsert that does not change the orphan set (e.g.
          // an older page fetched by the walk-back itself, or a new tail
          // message) must NOT refresh the budget.
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
          expect(
            syncWithEnc.testOrphanFetchOlderNoProgressCount('s2'),
            orphanAggressiveAttempts,
            reason:
                'upserts must not reset the no-progress counter — '
                'this is what kept the production walk-back looping',
          );

          syncWithEnc.testRunDeferredRegroupSweep('s2');
          await _drainAsyncWork();

          expect(
            fetchOlderCount,
            orphanAggressiveAttempts,
            reason:
                'with the aggressive budget exhausted and the orphan '
                'set unchanged, the sweep must not fetch again',
          );
        },
      );

      test('a changed orphan set opens a fresh walk-back budget', () async {
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
        // Aggressive budget × pageSize 500 each, plus slack.
        syncWithEnc.testSetSessionFirstLoadedSeq(
          's2',
          orphanAggressiveAttempts * orphanFetchOlderPageSize + 1000,
        );

        // Burn through the aggressive budget on orph-1.
        for (var i = 0; i < orphanAggressiveAttempts; i++) {
          // Aggressive mode now enforces a floor between pages; clear the
          // throttle stamp so the loop still exercises the full budget.
          syncWithEnc.testClearOrphanFetchOlderAttemptedMs('s2');
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
        expect(fetchOlderCount, orphanAggressiveAttempts);

        // orph-1 is still unresolved and still present, but a disjoint
        // orph-NEW burst (a different parent Task group) arrives
        // alongside it. The walk-back tracks parent Task groups
        // alongside orphan ids precisely so this case still opens a
        // fresh budget: a brand-new, unrelated burst deserves its own
        // look even while an older, stuck burst is still pending. This
        // is distinct from pure growth of the SAME parent group (more
        // children of orph-1's own stuck parent arriving) — see
        // sidechain_orphan_walkback_test.dart's "no-progress counter
        // must not be pinned at zero" and "a disjoint new parent group
        // opens a fresh budget even while an older stuck parent group
        // is still pending" regressions for both halves of this
        // contract.
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
            'id': 'orph-NEW',
            'isSidechain': true,
            'uuid': 'u9',
            'parentUuid': 'task-B',
            'parentToolUseId': 'toolu_B',
            'role': 'agent',
            'kind': 'text',
            'seq': 300,
          },
        ]);

        syncWithEnc.testClearOrphanFetchOlderAttemptedMs('s2');
        syncWithEnc.testRunDeferredRegroupSweep('s2');
        await _drainAsyncWork();

        expect(
          fetchOlderCount,
          orphanAggressiveAttempts + 1,
          reason: 'a disjoint new parent group must grant a fresh budget '
              'even while the older orphan is still present',
        );
      });

      test('aggressive mode still enforces a floor between pages', () async {
        // Aggressive mode used to run with no throttle at all, so the first
        // pages of a walk-back went out back-to-back — in production that
        // meant several ~1.5 MB requests in a row.
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
        syncWithEnc.testSetSessionFirstLoadedSeq('s2', 5000);

        syncWithEnc.testRunDeferredRegroupSweep('s2');
        await _drainAsyncWork();
        expect(fetchOlderCount, 1);

        // An immediate follow-up sweep is inside the floor window.
        syncWithEnc.testRunDeferredRegroupSweep('s2');
        await _drainAsyncWork();
        expect(
          fetchOlderCount,
          1,
          reason: 'aggressive walk-back pages must not fire back-to-back',
        );
      });

      test('a session at the visible message cap skips the walk-back', () async {
        // _upsertSessionMessages trims a visible session back to the newest
        // Sync.maxVisibleSessionMessagesForTesting rows, so a fetched older
        // page — and the parent Task inside it — is discarded before the
        // grouper can see it. Every page is then guaranteed to make zero
        // progress, so the walk-back must not run at all.
        final atCap = <Map<String, dynamic>>[
          for (var i = 0; i < Sync.maxVisibleSessionMessagesForTesting; i++)
            <String, dynamic>{
              'id': 'm-$i',
              'role': 'agent',
              'kind': 'text',
              'seq': 1000 + i,
              'createdAt': 1700000000000 + i,
            },
        ]..add(<String, dynamic>{
          'id': 'orph-1',
          'isSidechain': true,
          'uuid': 'u1',
          'parentUuid': 'task-A',
          'parentToolUseId': 'toolu_A',
          'role': 'agent',
          'kind': 'text',
          'seq': 102,
        });
        syncWithEnc.testSetSessionMessages('s2', atCap);
        syncWithEnc.testSetSessionFirstLoadedSeq('s2', 5000);

        syncWithEnc.testRunDeferredRegroupSweep('s2');
        await _drainAsyncWork();

        expect(
          fetchOlderCount,
          0,
          reason:
              'a session at the visible cap trims away every fetched page, '
              'so the walk-back can never make progress',
        );
      });

      test('background sessions never walk back — recovery is deferred '
          'until the session becomes visible', () async {
        // Production regression: a background session (trimmed to the
        // newest 200 messages on every upsert) looped fetchOlderMessages
        // even though each fetched page was discarded by the trim
        // before the grouper could see the parent Task.
        syncWithEnc.testSetVisibleSessionId('other-session');
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

        for (var i = 0; i < 5; i++) {
          syncWithEnc.testRunDeferredRegroupSweep('s2');
          await _drainAsyncWork();
        }
        expect(
          fetchOlderCount,
          0,
          reason:
              'background sessions must not fetch older pages — '
              'the background trim cap discards them anyway',
        );

        // Once the session is visible, the sweep may walk back.
        syncWithEnc.testSetVisibleSessionId('s2');
        syncWithEnc.testRunDeferredRegroupSweep('s2');
        await _drainAsyncWork();
        expect(
          fetchOlderCount,
          1,
          reason: 'visible session gets a fresh walk-back budget',
        );
      });

      test('hard cap gives up and suppresses further work once the no-progress '
          'counter reaches the limit', () async {
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

        // Set the counter at the cap. The signature must be primed so
        // the sweep treats this orphan set as already-seen — otherwise
        // first sight grants a fresh budget by design.
        syncWithEnc.testPrimeOrphanWalkbackSignature('s2');
        final maxAttempts = syncWithEnc.testOrphanFetchOlderMaxAttempts;
        syncWithEnc.testSetOrphanFetchOlderNoProgressCount('s2', maxAttempts);

        syncWithEnc.testRunDeferredRegroupSweep('s2');
        await _drainAsyncWork();

        expect(
          fetchOlderCount,
          0,
          reason: 'at the hard cap sweep must not call fetchOlder',
        );

        // Subsequent sweeps are also suppressed, and the counter
        // stays at the cap so the give-up cannot undo itself.
        for (var i = 0; i < 5; i++) {
          syncWithEnc.testRunDeferredRegroupSweep('s2');
          await _drainAsyncWork();
        }
        expect(
          fetchOlderCount,
          0,
          reason: 'suppression must persist across repeated sweeps',
        );
        expect(
          syncWithEnc.testOrphanFetchOlderNoProgressCount('s2'),
          maxAttempts,
          reason: 'hard-cap give-up must keep the counter sticky',
        );
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
