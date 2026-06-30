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

/// Walk-back contract tests for orphan sidechain recovery.
///
/// These tests pin the page-size, no-progress counter, and signature
/// behavior of the orphan-recovery walk-back introduced by the
/// "walk back farther for orphaned sidechains" fix. The fix replaced
/// the legacy 100-message page with a 500-message page so a single
/// walk-back can reach parents sitting thousands of seqs below the
/// loaded window, and pinned a deterministic signature/no-progress
/// ledger so the walk-back can't loop indefinitely while still
/// resetting whenever real progress happens.
void main() {
  late Sync sync;
  late int fetchOlderCount;
  late List<int> fetchOlderLimits;
  late List<int> fetchOlderStartSeqs;

  setUp(() {
    sync = createTestSync();
    sync.encryption = _WalkbackFakeEncryption();
    sync.testIsInitialized = true;
    sync.testSetVisibleSessionId('s1');
    sync.testSessions['s1'] = _makeWalkbackSession('s1', lastSeq: 50000);
    fetchOlderCount = 0;
    fetchOlderLimits = <int>[];
    fetchOlderStartSeqs = <int>[];
    sync.testFetchOlderMessagesOverride =
        (sessionId, afterSeq, limit) async {
      fetchOlderCount++;
      fetchOlderLimits.add(limit);
      fetchOlderStartSeqs.add(afterSeq);
      // Default: return empty pages so the walk-back keeps firing
      // without actually upserting anything. Individual tests can
      // override this on a per-call basis if they need to simulate
      // progress.
      return {'messages': <Map<String, dynamic>>[], 'hasMore': true};
    };
  });

  tearDown(() {
    sync.testFetchOlderMessagesOverride = null;
    sync.testClearSessionMessageState('s1');
    sync.testSetVisibleSessionId(null);
  });

  // ──────────────────────────────────────────────────────────────────
  // Test 1: walk-back continues past the legacy 12-attempt cap when
  // history is deep. The new behavior must allow > 12 fetchOlder calls
  // up to the 50-page / 50*500=25000-seq budget before giving up.
  // ──────────────────────────────────────────────────────────────────
  test(
    'walk-back continues past the legacy 12-attempt cap when history '
    'is deep — fires >12 fetchOlder pages with 500-seq window',
    () async {
      // Deep history: firstLoadedSeq 40k means 40k seqs of backlog.
      // Each 500-page can advance the cursor by up to 500 seqs; the
      // budget allows up to 50 such pages (50 * 500 = 25000 seqs of
      // walking) before the walk-back exhausts.
      sync.testSetSessionMessages('s1', [
        <String, dynamic>{
          'id': 'orph-1',
          'isSidechain': true,
          'uuid': 'u1',
          'parentUuid': 'task-A',
          'parentToolUseId': 'toolu_A',
          'role': 'agent',
          'kind': 'text',
          'seq': 1000,
          'createdAt': 1000,
        },
      ]);
      sync.testSetSessionFirstLoadedSeq('s1', 40000);

      // Drive 20 deferred regroup sweeps to exercise the full budget.
      for (var i = 0; i < 20; i++) {
        // Re-seed orphan between sweeps so the signature stays
        // stable — this isolates the walk-back cadence from the
        // signature-reset path.
        sync.testSetSessionMessages('s1', [
          <String, dynamic>{
            'id': 'orph-1',
            'isSidechain': true,
            'uuid': 'u1',
            'parentUuid': 'task-A',
            'parentToolUseId': 'toolu_A',
            'role': 'agent',
            'kind': 'text',
            'seq': 1000,
            'createdAt': 1000,
          },
        ]);
        // Clear the throttle timestamp so each sweep can fire.
        sync.testClearOrphanFetchOlderAttemptedMs('s1');
        sync.testRunDeferredRegroupSweep('s1');
        await _drainAsyncWork();
      }

      // Walk-back must have fired MORE than the legacy 12-attempt cap.
      expect(
        fetchOlderCount,
        greaterThan(12),
        reason: 'walk-back must continue past the legacy 12-attempt cap '
            'with the larger 500-seq page size',
      );

      // Every fetchOlder must use the orphan-recovery page size (500).
      // This is the actual fix: the legacy code used 100, which couldn't
      // reach parents sitting > 1200 seqs below the loaded window
      // without burning the entire budget.
      expect(
        fetchOlderLimits.every((l) => l == 500),
        isTrue,
        reason: 'walk-back must use the 500-seq orphan-recovery page '
            'size on every fetchOlder call',
      );

      // The no-progress counter grew beyond the legacy 12 cap.
      // (The walk-back uses the same counter as the merge sweep.)
      expect(
        sync.testOrphanFetchOlderNoProgressCount('s1'),
        greaterThan(12),
        reason: 'no-progress counter must grow past the legacy 12 cap '
            'when history is deep and pages return empty',
      );

      // The walk-back advanced the startSeq window across calls —
      // each fetchOlder asks for an older window than the last, so
      // the startSeqs must be monotonically decreasing or equal.
      for (var i = 1; i < fetchOlderStartSeqs.length; i++) {
        expect(
          fetchOlderStartSeqs[i],
          lessThanOrEqualTo(fetchOlderStartSeqs[i - 1]),
          reason:
              'fetchOlder must keep walking older (startSeq must not '
              'increase between calls)',
        );
      }
    },
  );

  // ──────────────────────────────────────────────────────────────────
  // Test 2: no-progress counter resets when a fetchOlder call returns
  // a different older window. Simulating progress: every 5th call
  // returns an empty page (no orphan attached, but window advanced).
  // The counter bumps on no-progress calls and resets when the
  // window advances.
  // ──────────────────────────────────────────────────────────────────
  test(
    'no-progress counter resets when a fetchOlder call returns a '
    'different older window',
    () async {
      // Custom override: every 5th call (calls #5, #10, ...) returns
      // a successful empty page that advances firstLoadedSeq — this
      // simulates real pagination progress.
      var localCount = 0;
      var currentFirstLoaded = 800;
      sync.testFetchOlderMessagesOverride = (s, afterSeq, limit) async {
        localCount++;
        // Every 5th call simulates progress by reporting a smaller
        // firstLoadedSeq on the next sweep — the walk-back's
        // post-fetch hook reads _sessionFirstLoadedSeq to detect
        // window advancement independent of orphan count.
        if (localCount % 5 == 0) {
          currentFirstLoaded = (currentFirstLoaded - 500).clamp(0, 100000);
        }
        return {'messages': <Map<String, dynamic>>[], 'hasMore': true};
      };

      // Seed one orphan with parentToolUseId so the walk-back fires.
      final seedOrphan = <String, dynamic>{
        'id': 'orph-1',
        'isSidechain': true,
        'uuid': 'u1',
        'parentUuid': 'task-A',
        'parentToolUseId': 'toolu_A',
        'role': 'agent',
        'kind': 'text',
        'seq': 100,
        'createdAt': 100,
      };
      sync.testSetSessionMessages('s1', [seedOrphan]);
      sync.testSetSessionFirstLoadedSeq('s1', currentFirstLoaded);

      // Run a sweep to start the cadence.
      sync.testRunDeferredRegroupSweep('s1');
      await _drainAsyncWork();
      // Pre-condition: at least one fetchOlder fired and the counter
      // started incrementing.
      expect(fetchOlderCount, 0); // not used here; localCount is.
      expect(localCount, 1);

      // Drive the counter up to 4 by running 3 more sweeps (we just
      // burned 1). Each non-progress sweep increments by 1 in the
      // post-fetch hook.
      for (var i = 0; i < 3; i++) {
        sync.testSetSessionMessages('s1', [seedOrphan]);
        sync.testSetSessionFirstLoadedSeq('s1', currentFirstLoaded);
        sync.testClearOrphanFetchOlderAttemptedMs('s1');
        sync.testRunDeferredRegroupSweep('s1');
        await _drainAsyncWork();
      }
      expect(localCount, 4);

      // Now bump firstLoadedSeq back DOWN to simulate the next page
      // actually moving the window — the orphan-count-vs-lowest-seq
      // progress axis treats "window advanced" as progress.
      currentFirstLoaded -= 500;

      // Run one more sweep with the advanced window. After the
      // fetchOlder, the lowestFirstLoadedSeq ledger should observe
      // progress and reset the no-progress counter.
      sync.testSetSessionMessages('s1', [seedOrphan]);
      sync.testSetSessionFirstLoadedSeq('s1', currentFirstLoaded);
      sync.testClearOrphanFetchOlderAttemptedMs('s1');
      sync.testRunDeferredRegroupSweep('s1');
      await _drainAsyncWork();

      // The counter must have been cleared by the window-advancing
      // fetchOlder. (If the implementation only checks orphan-count
      // change, this assertion will fail — that's the regression we
      // want to pin.)
      expect(
        sync.testOrphanFetchOlderNoProgressCount('s1'),
        lessThanOrEqualTo(4),
        reason: 'no-progress counter must not grow unbounded when a '
            'fetchOlder call advances the older window',
      );
    },
  );

  // ──────────────────────────────────────────────────────────────────
  // Test 3: fresh orphan signature during the suppression window
  // bypasses suppression. After the walk-back exhausts its budget
  // and suppression is set, a brand-new orphan set lifts the
  // suppression so the next sweep can invoke fetchOlder immediately.
  // ──────────────────────────────────────────────────────────────────
  test(
    'fresh orphan signature during the suppression window bypasses '
    'suppression — new orphan grants fresh budget without waiting '
    'for the 60s window to expire',
    () async {
      // Set the no-progress counter AT the hard cap (12) and prime
      // the signature so the sweep treats the current orphan set as
      // already-seen. This simulates the post-give-up state.
      sync.testSetSessionMessages('s1', [
        <String, dynamic>{
          'id': 'orph-1',
          'isSidechain': true,
          'uuid': 'u1',
          'parentUuid': 'task-A',
          'parentToolUseId': 'toolu_A',
          'role': 'agent',
          'kind': 'text',
          'seq': 100,
          'createdAt': 100,
        },
      ]);
      sync.testSetSessionFirstLoadedSeq('s1', 800);
      sync.testPrimeOrphanWalkbackSignature('s1');
      sync.testSetOrphanFetchOlderNoProgressCount('s1', 12);

      // One sweep at the cap must NOT fire fetchOlder.
      sync.testRunDeferredRegroupSweep('s1');
      await _drainAsyncWork();
      expect(
        fetchOlderCount,
        0,
        reason: 'at the hard cap with same signature, sweep must '
            'not invoke fetchOlder',
      );

      // Inject a brand-new orphan (different id) — this changes the
      // signature and must grant a fresh budget on the NEXT sweep.
      sync.testSetSessionMessages('s1', [
        <String, dynamic>{
          'id': 'orph-NEW',
          'isSidechain': true,
          'uuid': 'u-NEW',
          'parentUuid': 'task-B',
          'parentToolUseId': 'toolu_B',
          'role': 'agent',
          'kind': 'text',
          'seq': 200,
          'createdAt': 200,
        },
      ]);

      // Sweep again — the fresh signature must lift suppression.
      sync.testRunDeferredRegroupSweep('s1');
      await _drainAsyncWork();

      // The fresh signature must have granted a new budget — at
      // least one fetchOlder call should have fired even though the
      // previous cap (12) would normally block it.
      expect(
        fetchOlderCount,
        greaterThanOrEqualTo(1),
        reason: 'fresh orphan signature must bypass suppression and '
            'grant a fresh walk-back budget',
      );

      // The no-progress counter must have been reset by the
      // signature change.
      expect(
        sync.testOrphanFetchOlderNoProgressCount('s1'),
        lessThan(12),
        reason: 'fresh signature must reset the no-progress counter',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Test helpers (fake encryption + session factory) for the walk-back
// contract tests above.
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

Session _makeWalkbackSession(String id, {int lastSeq = 10}) {
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

class _WalkbackFakeEncryption implements Encryption {
  final Map<String, _WalkbackFakeSessionEncryption> _sessions = {};

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return _sessions.putIfAbsent(
      sessionId,
      () => _WalkbackFakeSessionEncryption(sessionId: sessionId),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _WalkbackFakeSessionEncryption extends SessionEncryption {
  _WalkbackFakeSessionEncryption({required String sessionId})
      : super(
          sessionId: sessionId,
          encryptor: _WalkbackFakeEncryptor(),
          decryptor: _WalkbackFakeEncryptor(),
          cache: EncryptionCache(),
        );
}

class _WalkbackFakeEncryptor implements Encryptor {
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
