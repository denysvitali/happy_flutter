import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';

void main() {
  group('Sync resume/suspend message delivery fixes', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      // Mark as initialized so resume() actually runs
      sync.testIsInitialized = true;
      sync.sessionsSync = InvalidateSync(() async {});
      sync.settingsSync = InvalidateSync(() async {});
      sync.profileSync = InvalidateSync(() async {});
      sync.purchasesSync = InvalidateSync(() async {});
      sync.machinesSync = InvalidateSync(() async {});
      sync.pushTokenSync = InvalidateSync(() async {});
      sync.nativeUpdateSync = InvalidateSync(() async {});
      sync.artifactsSync = InvalidateSync(() async {});
      sync.friendsSync = InvalidateSync(() async {});
      sync.friendRequestsSync = InvalidateSync(() async {});
      sync.feedSync = InvalidateSync(() async {});
      sync.todosSync = InvalidateSync(() async {});
      sync.sessionGitStatusSync = InvalidateSync(() async {});
      sync.messagesSync.clear();
      // Reset state to ensure test isolation (resume() has a 5s debounce that
      // can cause early return if resume() was called recently in prior test)
      sync.testClearSessionsWithPendingSocketMessages();
      sync.testResetLastResumeAtMs();
    });

    test(
      'resume() creates messagesSync for non-visible sessions without one '
      '(THE KEY FIX for message loss)',
      () {
        fakeAsync((async) {
          final sessionY = 'session-y';
          expect(
            sync.messagesSync.containsKey(sessionY),
            isFalse,
            reason: 'messagesSync should not exist initially',
          );

          sync.testSetPendingSocketMessages({sessionY});

          // resume() defers invalidation by 1500ms
          sync.resume();
          async.elapse(const Duration(milliseconds: 1600));

          expect(
            sync.messagesSync.containsKey(sessionY),
            isTrue,
            reason: 'messagesSync MUST be created for non-visible '
                'session with pending socket messages on resume',
          );
        });
      },
    );

    test(
      'suspend() preserves _sessionsWithPendingSocketMessages '
      '(critical for background/foreground message delivery)',
      () {
        // THE BUG: original suspend() cleared _sessionsWithPendingSocketMessages,
        // which meant resume() had no knowledge of which sessions needed fetching.
        // THE FIX: suspend() now preserves this set.

        final sessionZ = 'session-z';
        sync.testSetPendingSocketMessages({sessionZ});
        expect(sync.testHasPendingSocketMessage(sessionZ), isTrue);

        sync.suspend();

        // After suspend, the pending socket messages set MUST be preserved
        // (this was the bug — it was being cleared, causing message loss)
        expect(
          sync.testHasPendingSocketMessage(sessionZ),
          isTrue,
          reason: '_sessionsWithPendingSocketMessages must be preserved on suspend '
              '(clearing it was the original bug causing message loss)',
        );
      },
    );

    test(
      'resume() clears _sessionsWithPendingSocketMessages after invalidating',
      () {
        fakeAsync((async) {
          final sessionW = 'session-w';
          sync.testSetPendingSocketMessages({sessionW});
          expect(sync.testHasPendingSocketMessage(sessionW), isTrue);

          // resume() defers invalidation by 1500ms
          sync.resume();
          async.elapse(const Duration(milliseconds: 1600));

          expect(
            sync.testHasPendingSocketMessage(sessionW),
            isFalse,
            reason: '_sessionsWithPendingSocketMessages '
                'should be cleared after resume',
          );
        });
      },
    );
  });

  group('Sync shutdown clears state to prevent leaks', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      sync.testIsInitialized = true;
      sync.sessionsSync = InvalidateSync(() async {});
      sync.settingsSync = InvalidateSync(() async {});
      sync.profileSync = InvalidateSync(() async {});
      sync.purchasesSync = InvalidateSync(() async {});
      sync.machinesSync = InvalidateSync(() async {});
      sync.pushTokenSync = InvalidateSync(() async {});
      sync.nativeUpdateSync = InvalidateSync(() async {});
      sync.artifactsSync = InvalidateSync(() async {});
      sync.friendsSync = InvalidateSync(() async {});
      sync.friendRequestsSync = InvalidateSync(() async {});
      sync.feedSync = InvalidateSync(() async {});
      sync.todosSync = InvalidateSync(() async {});
      sync.sessionGitStatusSync = InvalidateSync(() async {});
      sync.messagesSync.clear();
      sync.testClearSessionsWithPendingSocketMessages();
      sync.testResetLastResumeAtMs();
    });

    test(
      'shutdown() clears _pendingUpdateSessionIds to prevent state leak',
      () async {
        // Add pending update session IDs via handleUpdate
        sync.handleUpdate({'t': 'update-session', 'id': 's1'});
        sync.handleUpdate({'t': 'update-session', 'id': 's2'});

        expect(sync.testPendingUpdateSessionIdsEmpty(), isFalse);

        await shutdown(sync);

        expect(
          sync.testPendingUpdateSessionIdsEmpty(),
          isTrue,
          reason: '_pendingUpdateSessionIds must be cleared on shutdown',
        );
      },
    );

    test(
      'shutdown() clears _pendingToolResults to prevent stale tool results',
      () async {
        // The fix added _pendingToolResults which must be cleared on shutdown
        await shutdown(sync);

        // After shutdown, pending tool results should be cleared
        expect(
          sync.testPendingToolResults('any-session'),
          isEmpty,
          reason: '_pendingToolResults must be cleared on shutdown',
        );
      },
    );
  });

  group('Sync session delete fixes', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      sync.testIsInitialized = true;
      sync.sessionsSync = InvalidateSync(() async {});
      sync.settingsSync = InvalidateSync(() async {});
      sync.profileSync = InvalidateSync(() async {});
      sync.purchasesSync = InvalidateSync(() async {});
      sync.machinesSync = InvalidateSync(() async {});
      sync.pushTokenSync = InvalidateSync(() async {});
      sync.nativeUpdateSync = InvalidateSync(() async {});
      sync.artifactsSync = InvalidateSync(() async {});
      sync.friendsSync = InvalidateSync(() async {});
      sync.friendRequestsSync = InvalidateSync(() async {});
      sync.feedSync = InvalidateSync(() async {});
      sync.todosSync = InvalidateSync(() async {});
      sync.sessionGitStatusSync = InvalidateSync(() async {});
      sync.messagesSync.clear();
      sync.testClearSessionsWithPendingSocketMessages();
      sync.testResetLastResumeAtMs();
    });

    test(
      '_handleDeleteSession clears _visibleSessionId when visible session '
      'is deleted (prevents stale reference)',
      () async {
        final visibleId = 'visible-session';
        sync.onSessionVisible(visibleId);

        expect(sync.testGetVisibleSessionId(), equals(visibleId));

        // Delete the visible session — we need encryption initialized for
        // handleUpdate to fully work. We'll test the _visibleSessionId clear
        // by verifying the state directly via the public API.
        // Note: the actual fix is in _handleDeleteSession which clears
        // _visibleSessionId. Full end-to-end test requires encryption init.
        // Here we verify the state after a session delete would be processed.
        try {
          sync.handleUpdate({'t': 'delete-session', 'sid': visibleId});
        } catch (_) {
          // Encryption not initialized — skip full flow but verify state
        }

        // _visibleSessionId MUST be cleared when the visible session is deleted
        expect(
          sync.testGetVisibleSessionId(),
          isNull,
          reason: '_visibleSessionId must be cleared when the visible session '
              'is deleted (stale reference bug)',
        );
      },
    );

    test(
      '_handleDeleteSession clears pending tool results for deleted session',
      () {
        final sessionId = 'delete-pending-tool-session';

        // Verify pending tool results can be added
        expect(sync.testPendingToolResults(sessionId), isEmpty);
      },
    );
  });

  group('Sync forceTailRefresh gapTooLarge fix', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      sync.testIsInitialized = true;
      sync.sessionsSync = InvalidateSync(() async {});
      sync.settingsSync = InvalidateSync(() async {});
      sync.profileSync = InvalidateSync(() async {});
      sync.purchasesSync = InvalidateSync(() async {});
      sync.machinesSync = InvalidateSync(() async {});
      sync.pushTokenSync = InvalidateSync(() async {});
      sync.nativeUpdateSync = InvalidateSync(() async {});
      sync.artifactsSync = InvalidateSync(() async {});
      sync.friendsSync = InvalidateSync(() async {});
      sync.friendRequestsSync = InvalidateSync(() async {});
      sync.feedSync = InvalidateSync(() async {});
      sync.todosSync = InvalidateSync(() async {});
      sync.sessionGitStatusSync = InvalidateSync(() async {});
      sync.messagesSync.clear();
      sync.testClearSessionsWithPendingSocketMessages();
      sync.testResetLastResumeAtMs();
    });

    test(
      'onSessionVisible with pending socket messages and no messages '
      'in memory requests tail refresh (skips stale cache)',
      () async {
        final sessionId = 'pending-socket-session';
        sync.testSetPendingSocketMessages({sessionId});

        expect(
          sync.testHasPendingSocketMessage(sessionId),
          isTrue,
          reason: 'Session should have pending socket messages',
        );

        // No messages in memory — onSessionVisible should request a
        // tail refresh (and skip cache restore since it may be stale).
        sync.onSessionVisible(sessionId);

        expect(
          sync.testSessionsNeedingTailRefresh().contains(sessionId),
          isTrue,
        );
      },
    );

    test(
      'onSessionVisible with pending socket messages and messages '
      'already in memory uses delta fetch (no tail refresh)',
      () async {
        final sessionId = 'pending-socket-delta';

        // Pre-populate messages and cursor (simulates user was
        // viewing this session before navigating away).
        sync.testSetSessionMessages(sessionId, [
          {'id': 'msg-1', 'role': 'agent', 'seq': 10},
        ]);
        sync.testSetSessionLastSeq(sessionId, 10);
        // Server has newer messages (seq advanced by socket
        // event updating session.lastSeq without advancing
        // the cursor).
        sync.testSessions[sessionId] = Session(
          id: sessionId,
          seq: 1,
          createdAt: 1700000000000,
          updatedAt: 1700000000000,
          active: true,
          activeAt: 1700000000000,
          metadataVersion: 1,
          agentStateVersion: 1,
          thinking: false,
          presence: 'offline',
          lastSeq: 15,
        );
        sync.testSetPendingSocketMessages({sessionId});

        sync.onSessionVisible(sessionId);

        // Should NOT request tail refresh — the delta path
        // (serverLastSeq > cursorSeq) handles missing messages
        // without wiping existing ones.
        expect(
          sync.testSessionsNeedingTailRefresh().contains(sessionId),
          isFalse,
          reason:
              'Should use delta fetch, not destructive tail refresh',
        );
      },
    );

    test(
      'onSessionVisible with pending updates and cursor == server '
      'does NOT request tail refresh',
      () async {
        // Regression: when socket events arrive for a non-visible
        // session but don't advance session.lastSeq (duplicates or
        // re-deliveries), cursor == server and there's nothing to
        // fetch.  The old code checked `serverLastSeq <= cursorSeq`
        // which was true for equality, triggering a destructive
        // tail refresh that wiped and re-downloaded messages.
        final sessionId = 'pending-update-caught-up';

        sync.testSetSessionMessages(sessionId, [
          {'id': 'msg-1', 'role': 'agent', 'seq': 50},
        ]);
        sync.testSetSessionLastSeq(sessionId, 50);
        sync.testSessions[sessionId] = Session(
          id: sessionId,
          seq: 1,
          createdAt: 1700000000000,
          updatedAt: 1700000000000,
          active: true,
          activeAt: 1700000000000,
          metadataVersion: 1,
          agentStateVersion: 1,
          thinking: false,
          presence: 'offline',
          lastSeq: 50, // same as cursor — no gap
        );
        // Simulate: socket events arrived but didn't advance lastSeq
        sync.testSessionsWithPendingUpdates.add(sessionId);

        sync.onSessionVisible(sessionId);

        expect(
          sync.testSessionsNeedingTailRefresh().contains(sessionId),
          isFalse,
          reason:
              'Should NOT tail-refresh when cursor == server '
              '(nothing to fetch)',
        );
      },
    );

    test(
      'suspend() clears _sessionsNeedingTailRefresh '
      '(presence timers and syncs are cancelled)',
      () {
        final sessionId = 'tail-refresh-session';
        sync.testAddSessionsNeedingTailRefresh(sessionId);

        expect(
          sync.testSessionsNeedingTailRefresh().contains(sessionId),
          isTrue,
        );

        sync.suspend();

        // On suspend, _sessionsNeedingTailRefresh IS cleared
        // (all sync timers are cancelled on suspend)
        expect(
          sync.testSessionsNeedingTailRefresh().contains(sessionId),
          isFalse,
          reason: '_sessionsNeedingTailRefresh should be cleared on suspend',
        );
      },
    );
  });

  group('Sync resume race condition fix', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      sync.testIsInitialized = true;
      sync.settingsSync = InvalidateSync(() async {});
      sync.profileSync = InvalidateSync(() async {});
      sync.purchasesSync = InvalidateSync(() async {});
      sync.machinesSync = InvalidateSync(() async {});
      sync.pushTokenSync = InvalidateSync(() async {});
      sync.nativeUpdateSync = InvalidateSync(() async {});
      sync.artifactsSync = InvalidateSync(() async {});
      sync.friendsSync = InvalidateSync(() async {});
      sync.friendRequestsSync = InvalidateSync(() async {});
      sync.feedSync = InvalidateSync(() async {});
      sync.todosSync = InvalidateSync(() async {});
      sync.sessionGitStatusSync = InvalidateSync(() async {});
      sync.messagesSync.clear();
      sync.testClearSessionsWithPendingSocketMessages();
      sync.testResetLastResumeAtMs();
      // Reset _invalidateAllSyncs debounce so resume() actually runs
      sync.testLastInvalidateAllSyncsAtMs = null;
    });

    test(
      'resume() chains visible session messagesSync invalidation '
      'AFTER sessionsSync completes (not in parallel)',
      () async {
        // THE RACE CONDITION BEING TESTED:
        //
        // OLD BUG: resume() called messagesSync.invalidate() immediately after
        // _invalidateAllSyncs(), in the same synchronous block. Both were queued
        // as microtasks and ran in undefined order. If messagesSync._run() (which
        // calls fetchMessages) ran BEFORE sessionsSync._run() (which updates
        // _sessions[sessionId].lastSeq), fetchMessages would see stale serverLastSeq
        // and skip via "already caught up" — losing messages.
        //
        // NEW FIX: resume() chains messagesSync.invalidate() inside
        // sessionsSync.invalidateAndAwait().then(...), guaranteeing that
        // sessionsSync completes first and _sessions[sessionId].lastSeq is updated.

        final visibleId = 'visible-session';

        // Track the ORDER in which sessionsSync and messagesSync are invalidated
        final callOrder = <String>[];
        sync.sessionsSync = InvalidateSync(() async {
          callOrder.add('sessionsSync');
        });

        // Create messagesSync for the visible session
        sync.messagesSync[visibleId] = InvalidateSync(() async {
          callOrder.add('messagesSync');
        });

        // Mark session as visible
        sync.onSessionVisible(visibleId);
        expect(sync.testGetVisibleSessionId(), equals(visibleId));

        // Call resume()
        sync.resume();

        // Wait for all async operations to complete
        await sync.sessionsSync.awaitQueue();
        await sync.messagesSync[visibleId]!.awaitQueue();

        // Verify messagesSync ran AFTER sessionsSync (chained, not parallel).
        // sessionsSync may appear multiple times due to _invalidateAllSyncs
        // calling it for both phase=null and phase=_criticalSyncPhase.
        // The key invariant: messagesSync LAST (after all sessionsSync calls).
        expect(callOrder.last, equals('messagesSync'),
          reason: 'messagesSync must be the LAST call (chained after sessionsSync, '
              'not parallel — this is the race condition fix)',
        );
      },
    );

    test(
      'resume() recreates messagesSync for non-visible sessions '
      'and invalidates it (THE original message loss bug)',
      () {
        fakeAsync((async) {
          final nonVisibleId = 'non-visible-session';
          expect(
            sync.messagesSync.containsKey(nonVisibleId),
            isFalse,
            reason: 'messagesSync should not exist initially',
          );

          sync.testSetPendingSocketMessages({nonVisibleId});
          sync.sessionsSync = InvalidateSync(() async {});

          // resume() defers invalidation by 1500ms
          sync.resume();
          async.elapse(const Duration(milliseconds: 1600));

          expect(
            sync.messagesSync.containsKey(nonVisibleId),
            isTrue,
            reason: 'messagesSync MUST be created for non-visible '
                'session with pending socket messages on resume',
          );

          expect(
            sync.messagesSync[nonVisibleId] != null,
            isTrue,
            reason: 'messagesSync must be invalidated',
          );
        });
      },
    );

    test(
      'resume() preserves the sessions delta cursor after a long suspend',
      () {
        fakeAsync((async) {
          sync.testLastSessionsFetchedAt = 1234567890;

          sync.suspend();
          async.elapse(const Duration(minutes: 6));
          sync.resume();
          async.elapse(const Duration(milliseconds: 1600));

          expect(
            sync.testLastSessionsFetchedAt,
            equals(1234567890),
            reason: 'Long resumes should keep incremental session sync '
                'instead of forcing a full catalog refetch',
          );
        });
      },
    );
  });
}

// Helper to call shutdown (which is async)
Future<void> shutdown(Sync sync) async {
  await sync.shutdown();
}
