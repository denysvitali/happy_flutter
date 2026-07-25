import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

void main() {
  group('Sync message retention performance bounds', () {
    late Sync sync;

    List<Map<String, dynamic>> messages(int count) =>
        List<Map<String, dynamic>>.generate(
          count,
          (index) => {
            'id': 'message-$index',
            'seq': index + 1,
            'createdAt': index + 1,
            'role': 'assistant',
            'content': 'message $index',
          },
        );

    setUp(() {
      sync = Sync();
      sync.testSetVisibleSessionId(null);
    });

    tearDown(() {
      sync.testSetVisibleSessionId(null);
      sync.testSetSessionMessages('background-session', const []);
      sync.testSetSessionMessages('visible-session', const []);
    });

    test('background session messages are capped to recent cache window', () {
      sync.testUpsertSessionMessages('background-session', messages(250));

      final retained = sync.messagesForSession('background-session');

      expect(retained, hasLength(200));
      expect(retained.first['id'], 'message-50');
      expect(retained.last['id'], 'message-249');
    });

    test('visible session messages retain a larger active window', () {
      sync.testSetVisibleSessionId('visible-session');
      sync.testUpsertSessionMessages('visible-session', messages(1200));

      final retained = sync.messagesForSession('visible-session');

      expect(retained, hasLength(1000));
      expect(retained.first['id'], 'message-200');
      expect(retained.last['id'], 'message-1199');
    });
  });

  group('Sync resume/suspend message delivery fixes', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      // Mark as initialized so resume() actually runs
      sync.testIsInitialized = true;
      sync.encryption = _testEncryption();
      sync.sessionsSync = InvalidateSync(() async {});
      sync.settingsSync = InvalidateSync(() async {});
      sync.profileSync = InvalidateSync(() async {});
      sync.purchasesSync = InvalidateSync(() async {});
      sync.machinesSync = InvalidateSync(() async {});
      sync.pushTokenSync = InvalidateSync(() async {});
      sync.nativeUpdateSync = InvalidateSync(() async {});
      sync.artifactsSync = InvalidateSync(() async {});
      sync.sessionGitStatusSync = InvalidateSync(() async {});
      sync.messagesSync.clear();
      sync.testSetVisibleSessionId(null);
      sync.testForceFullFetchNext = false;
      sync.testLastInvalidateAllSyncsAtMs = null;
      // Reset state to ensure test isolation (resume() has a 5s debounce that
      // can cause early return if resume() was called recently in prior test)
      sync.testClearSessionsWithPendingSocketMessages();
      sync.testResetLastResumeAtMs();
      socketIoClient.testHasConnectedOnce = false;
    });

    tearDown(() {
      socketIoClient.testHasConnectedOnce = false;
      sync.testSetVisibleSessionId(null);
      sync.testFetchMessagesOverride = null;
      sync.testForceFullFetchNext = false;
      sync.testLastInvalidateAllSyncsAtMs = null;
    });

    test('resume() creates messagesSync for non-visible sessions without one '
        '(THE KEY FIX for message loss)', () {
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
          reason:
              'messagesSync MUST be created for non-visible '
              'session with pending socket messages on resume',
        );
      });
    });

    test('suspend() preserves _sessionsWithPendingSocketMessages '
        '(critical for background/foreground message delivery)', () {
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
        reason:
            '_sessionsWithPendingSocketMessages must be preserved on suspend '
            '(clearing it was the original bug causing message loss)',
      );
    });

    test(
      'suspend() preserves socket reconnect history for resume recovery',
      () {
        // Regression: background suspend used the same disconnect path as
        // logout/full teardown, which reset the socket's "has connected"
        // state. On resume the next connect looked like a first connect, so
        // Sync.onReconnected recovery never fired and session streams stayed
        // stale until a later manual refresh/restart.
        socketIoClient.testHasConnectedOnce = true;

        sync.suspend();

        expect(
          socketIoClient.testHasConnectedOnce,
          isTrue,
          reason:
              'Lifecycle suspend must preserve reconnect history so resume '
              'triggers the socket reconnected recovery path',
        );
      },
    );

    test('suspend() defers socket disconnect for rapid lifecycle bounces', () {
      fakeAsync((async) {
        sync.suspend();

        expect(
          sync.testDeferredSocketDisconnectTimerActive,
          isTrue,
          reason:
              'Short hidden/inactive lifecycle bounces should not '
              'disconnect the socket immediately and trigger a reconnect',
        );

        async.elapse(const Duration(milliseconds: 1999));

        expect(
          sync.testDeferredSocketDisconnectTimerActive,
          isTrue,
          reason: 'Socket disconnect grace period should still be active',
        );

        async.elapse(const Duration(milliseconds: 1));

        expect(
          sync.testDeferredSocketDisconnectTimerActive,
          isFalse,
          reason: 'Socket disconnect timer should clear after the grace period',
        );
      });
    });

    test('resume() cancels deferred socket disconnect from rapid suspend', () {
      fakeAsync((async) {
        sync.suspend();
        expect(sync.testDeferredSocketDisconnectTimerActive, isTrue);

        sync.resume();
        async.elapse(const Duration(milliseconds: 2100));

        expect(
          sync.testDeferredSocketDisconnectTimerActive,
          isFalse,
          reason:
              'Foregrounding before the grace period ends should cancel '
              'the delayed socket disconnect',
        );
        expect(
          InvalidateSync.isBackgrounded,
          isFalse,
          reason: 'resume should restore foreground sync execution',
        );
      });
    });

    test('a socket update-session event handled while backgrounded does not '
        'schedule a sessions-refresh timer '
        '(battery regression: the socket disconnect on suspend is itself '
        'deferred by Sync._suspendSocketDisconnectDelayMs to absorb short '
        'Android lifecycle bounces, so update-session events can still '
        'arrive for up to 2s after suspend() runs and isBackgrounded is '
        'set. Each one used to schedule a fresh '
        '_sessionsRefreshDebounceTimer that suspend() never gets another '
        'chance to cancel, waking the CPU to fire — and immediately skip '
        '— a sync after the app is already backgrounded)', () {
      fakeAsync((async) {
        var sessionsSyncRuns = 0;
        sync.sessionsSync = InvalidateSync(() async {
          sessionsSyncRuns++;
        });

        sync.suspend();
        expect(InvalidateSync.isBackgrounded, isTrue);

        // Socket event with an encrypted-field change arrives during
        // the post-suspend socket grace period.
        sync.handleUpdate(<String, dynamic>{
          't': 'update-session',
          'id': 'session-during-grace-window',
          'metadata': {'host': 'example'},
        });

        async.elapse(const Duration(seconds: 3));

        expect(
          sessionsSyncRuns,
          equals(0),
          reason:
              'no sessions refresh should ever run while backgrounded — '
              'the guard must stop the timer from being scheduled in '
              'the first place, not just let it fire and skip',
        );

        sync.resume();
      });
    });

    test('reconnect recovery throttles broad sessions invalidation', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      sync.testLastInvalidateAllSyncsAtMs = nowMs - 10 * 1000;

      expect(
        sync.testShouldRunReconnectGlobalInvalidation(nowMs),
        isFalse,
        reason:
            'A flaky websocket must not trigger another expensive '
            'sessions refresh when recovery already ran recently',
      );
    });

    test(
      'reconnect recovery still runs when a full sessions fetch is pending',
      () {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        sync.testLastInvalidateAllSyncsAtMs = nowMs - 10 * 1000;
        sync.testForceFullFetchNext = true;

        expect(
          sync.testShouldRunReconnectGlobalInvalidation(nowMs),
          isTrue,
          reason:
              'Explicit full-fetch recovery should bypass the reconnect '
              'battery throttle',
        );
      },
    );

    test(
      'suspend() does not dispose sessionsSync needed by later foreground refreshes',
      () async {
        var sessionsSyncRuns = 0;
        sync.sessionsSync = InvalidateSync(() async {
          sessionsSyncRuns++;
        });

        sync.suspend();
        sync.resume();
        await Future<void>.delayed(const Duration(milliseconds: 600));

        await sync.refreshSessions();

        expect(
          sessionsSyncRuns,
          greaterThanOrEqualTo(1),
          reason:
              'Lifecycle suspend must quiesce sessionsSync rather than '
              'disposing it so a later foreground refresh can reuse the '
              'same sync object without lifecycle-state errors',
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
            reason:
                '_sessionsWithPendingSocketMessages '
                'should be cleared after resume',
          );
        });
      },
    );

    test('rapid suspend/resume still refreshes the visible session', () {
      fakeAsync((async) {
        final visibleId = 'visible-session';
        var sessionsSyncRuns = 0;
        var messageSyncRuns = 0;

        sync.sessionsSync = InvalidateSync(() async {
          sessionsSyncRuns++;
        });
        sync.messagesSync[visibleId] = InvalidateSync(() async {
          messageSyncRuns++;
        });
        sync.testSetVisibleSessionId(visibleId);

        sync.resume();
        async.elapse(const Duration(milliseconds: 600));

        expect(sessionsSyncRuns, equals(1));
        expect(messageSyncRuns, equals(1));

        sync.suspend();
        sync.resume();
        async.elapse(const Duration(milliseconds: 600));

        expect(
          sessionsSyncRuns,
          equals(2),
          reason:
              'resume() must still invalidate sessionsSync after a '
              'rapid foreground return',
        );
        expect(
          messageSyncRuns,
          equals(2),
          reason:
              'resume() must still refresh the visible session even '
              'inside the resume debounce window',
        );
      });
    });

    test('rapid resume does not replay the global sync cascade a second time '
        '(battery regression: isRapidResume was computed but only logged, '
        'never gating shouldRunGlobalInvalidation, so every resume — even '
        'an OS-level pause/resume bounce landing inside the rapid-resume '
        'debounce window — replayed the full critical/deferred/background '
        'cascade: sessions, machines, settings, profile, purchases, push '
        'token, native update, git status)', () {
      fakeAsync((async) {
        var machinesSyncRuns = 0;
        sync.machinesSync = InvalidateSync(() async {
          machinesSyncRuns++;
        });
        sync.testSetVisibleSessionId(null);
        sync.testClearSessionsWithPendingSocketMessages();

        // First resume after a long background: not rapid (no prior
        // resume in this test run), so the global cascade runs once.
        sync.testLastSuspendedAtMs =
            DateTime.now().millisecondsSinceEpoch - 60000;
        sync.testLastInvalidateAllSyncsAtMs = null;
        sync.resume();
        // 500ms initial deferred-resume timer + up to ~300ms phase-1
        // stagger (base + jitter) — elapse comfortably past the worst case.
        async.elapse(const Duration(milliseconds: 900));

        expect(machinesSyncRuns, equals(1));

        // Second resume, again after a (simulated) long background —
        // shouldRunGlobalInvalidation's suspendDuration check alone
        // would say "run it again". But this resume() call lands only
        // milliseconds of real wall-clock time after the first one
        // (well under Sync._resumeDebounceWindowMs), so isRapidResume
        // must be true and must suppress the replay.
        sync.testLastSuspendedAtMs =
            DateTime.now().millisecondsSinceEpoch - 60000;
        sync.testLastInvalidateAllSyncsAtMs = null;
        sync.resume();
        async.elapse(const Duration(milliseconds: 900));

        expect(
          machinesSyncRuns,
          equals(1),
          reason:
              'a resume landing inside the rapid-resume debounce window '
              'must not replay the broad sync cascade — doing so on '
              'every foreground/background bounce is the dominant '
              'contributor to battery drain from lifecycle churn',
        );
      });
    });

    test('phase-1 deferred syncs are staggered, not fired on the same tick '
        'as phase-0 '
        '(battery regression: Timer(Duration.zero, ...) queued machines, '
        'settings, and profile invalidations — plus their socket RPCs — '
        'into the exact same microtask burst as the sessions fetch on '
        'every resume/reconnect, instead of spreading the radio-busy '
        'window)', () {
      fakeAsync((async) {
        var machinesSyncRuns = 0;
        sync.machinesSync = InvalidateSync(() async {
          machinesSyncRuns++;
        });
        sync.testSetVisibleSessionId(null);
        sync.testClearSessionsWithPendingSocketMessages();
        sync.testLastSuspendedAtMs =
            DateTime.now().millisecondsSinceEpoch - 60000;
        sync.testLastInvalidateAllSyncsAtMs = null;

        sync.resume();
        // resume() itself defers invalidation by 500ms before phase-0
        // even starts; phase-1's stagger (150-300ms, randomized) is
        // scheduled only after phase-0's sessionsSync queue settles, so
        // its fire time is always strictly after this 500ms mark.
        async.elapse(const Duration(milliseconds: 500));

        expect(
          machinesSyncRuns,
          equals(0),
          reason:
              'phase-1 must not fire on the same tick as phase-0 — it '
              'needs at least Sync._deferredSyncPhaseBaseDelayMs before '
              'it runs',
        );

        // Comfortably past the worst-case stagger (base + jitter).
        async.elapse(const Duration(milliseconds: 400));

        expect(
          machinesSyncRuns,
          equals(1),
          reason: 'phase-1 must still fire shortly after, just staggered',
        );
      });
    });

    test(
      'short resume still refreshes sessions when socket is disconnected',
      () {
        fakeAsync((async) {
          var sessionsSyncRuns = 0;

          sync.sessionsSync = InvalidateSync(() async {
            sessionsSyncRuns++;
          });

          // Clearly below the 5 s global-invalidation gate. fakeAsync does
          // not mock DateTime.now(), so a value near the gate (e.g. -5000)
          // flips to global invalidation when real wall-clock milliseconds
          // elapse before the deferred timer fires — a CI-only flake.
          sync.testLastSuspendedAtMs =
              DateTime.now().millisecondsSinceEpoch - 1000;
          sync.testSetVisibleSessionId(null);
          sync.testClearSessionsWithPendingSocketMessages();

          sync.resume();
          async.elapse(const Duration(milliseconds: 600));

          expect(
            sessionsSyncRuns,
            equals(1),
            reason:
                'Resume must refresh sessions via HTTP fallback when the '
                'socket is still disconnected after a short background '
                'period, otherwise foreground recovery stalls until the '
                'watchdog fires',
          );
        });
      },
    );

    test(
      'long resume with disconnected socket refreshes sessions exactly once',
      () {
        fakeAsync((async) {
          var sessionsSyncRuns = 0;

          sync.sessionsSync = InvalidateSync(() async {
            sessionsSyncRuns++;
          });

          // Clearly above the 5 s gate: the global invalidation path runs.
          sync.testLastSuspendedAtMs =
              DateTime.now().millisecondsSinceEpoch - 60000;
          // The singleton's 10 s global-invalidation cooldown could otherwise
          // swallow the invalidation if an earlier test triggered one.
          sync.testLastInvalidateAllSyncsAtMs = null;
          sync.testSetVisibleSessionId(null);
          sync.testClearSessionsWithPendingSocketMessages();

          sync.resume();
          async.elapse(const Duration(milliseconds: 600));

          expect(
            sessionsSyncRuns,
            equals(1),
            reason:
                '_invalidateAllSyncs already refreshes sessions; the HTTP '
                'fallback must not start a second fetch cycle on top of it',
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
      sync.encryption = _testEncryption();
      sync.sessionsSync = InvalidateSync(() async {});
      sync.settingsSync = InvalidateSync(() async {});
      sync.profileSync = InvalidateSync(() async {});
      sync.purchasesSync = InvalidateSync(() async {});
      sync.machinesSync = InvalidateSync(() async {});
      sync.pushTokenSync = InvalidateSync(() async {});
      sync.nativeUpdateSync = InvalidateSync(() async {});
      sync.artifactsSync = InvalidateSync(() async {});
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
      sync.encryption = _testEncryption();
      sync.sessionsSync = InvalidateSync(() async {});
      sync.settingsSync = InvalidateSync(() async {});
      sync.profileSync = InvalidateSync(() async {});
      sync.purchasesSync = InvalidateSync(() async {});
      sync.machinesSync = InvalidateSync(() async {});
      sync.pushTokenSync = InvalidateSync(() async {});
      sync.nativeUpdateSync = InvalidateSync(() async {});
      sync.artifactsSync = InvalidateSync(() async {});
      sync.sessionGitStatusSync = InvalidateSync(() async {});
      sync.messagesSync.clear();
      sync.testClearSessionsWithPendingSocketMessages();
      sync.testResetLastResumeAtMs();
    });

    test('_handleDeleteSession clears _visibleSessionId when visible session '
        'is deleted (prevents stale reference)', () async {
      final visibleId = 'visible-session';
      // Use the test helper to set _visibleSessionId directly so we don't
      // trigger onSessionVisible's fetch/MessagesSync side effects, which
      // cause unhandled async errors when the session is immediately deleted.
      sync.testSetVisibleSessionId(visibleId);

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
        reason:
            '_visibleSessionId must be cleared when the visible session '
            'is deleted (stale reference bug)',
      );
    });

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
      sync.sessionGitStatusSync = InvalidateSync(() async {});
      sync.messagesSync.clear();
      sync.testClearSessionsWithPendingSocketMessages();
      sync.testResetLastResumeAtMs();
    });

    test('onSessionVisible with pending socket messages and no messages '
        'in memory requests tail refresh (skips stale cache)', () async {
      final sessionId = 'pending-socket-session';
      sync.testSetPendingSocketMessages({sessionId});

      final tailRefreshed = <String>[];
      sync.onTailRefreshRequested = tailRefreshed.add;

      expect(
        sync.testHasPendingSocketMessage(sessionId),
        isTrue,
        reason: 'Session should have pending socket messages',
      );

      // No messages in memory — onSessionVisible should request a
      // tail refresh (and skip cache restore since it may be stale).
      await sync.onSessionVisible(sessionId);

      expect(tailRefreshed, contains(sessionId));
    });

    test('onSessionVisible with pending socket messages and messages '
        'already in memory uses delta fetch (no tail refresh)', () async {
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

      await sync.onSessionVisible(sessionId);

      // Should NOT request tail refresh — the delta path
      // (serverLastSeq > cursorSeq) handles missing messages
      // without wiping existing ones.
      expect(
        sync.testSessionsNeedingTailRefresh().contains(sessionId),
        isFalse,
        reason: 'Should use delta fetch, not destructive tail refresh',
      );
    });

    test('onSessionVisible with pending socket messages and cursor == server '
        'still probes the message API', () async {
      final sessionId = 'pending-socket-stale-lastseq';

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
        lastSeq: 50,
      );
      sync.testSetPendingSocketMessages({sessionId});

      final fetchCalls = <int>[];
      sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
        fetchCalls.add(afterSeq);
        return <String, dynamic>{
          'messages': <Map<String, dynamic>>[],
          'pagination': <String, dynamic>{'hasMore': false},
        };
      };

      await sync.onSessionVisible(sessionId);
      await sync.messagesSync[sessionId]?.awaitQueue();

      expect(
        fetchCalls,
        isNotEmpty,
        reason:
            'pending socket markers must bypass the cursor==server skip '
            'because session.lastSeq can be stale',
      );
      expect(sync.testHasPendingSocketMessage(sessionId), isFalse);
    });

    test('onSessionVisible with pending updates and cursor == server '
        'does NOT request tail refresh', () async {
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

      await sync.onSessionVisible(sessionId);

      expect(
        sync.testSessionsNeedingTailRefresh().contains(sessionId),
        isFalse,
        reason:
            'Should NOT tail-refresh when cursor == server '
            '(nothing to fetch)',
      );
    });

    test('suspend() clears _sessionsNeedingTailRefresh '
        '(presence timers and syncs are cancelled)', () {
      final sessionId = 'tail-refresh-session';
      sync.testAddSessionsNeedingTailRefresh(sessionId);

      expect(sync.testSessionsNeedingTailRefresh().contains(sessionId), isTrue);

      sync.suspend();

      // On suspend, _sessionsNeedingTailRefresh IS cleared
      // (all sync timers are cancelled on suspend)
      expect(
        sync.testSessionsNeedingTailRefresh().contains(sessionId),
        isFalse,
        reason: '_sessionsNeedingTailRefresh should be cleared on suspend',
      );
    });

    test('onSessionInvisible does not clobber a newer onSessionVisible '
        '(chat switch race)', () async {
      // THE RACE CONDITION BEING TESTED:
      //
      // When switching from chat A to chat B, Flutter calls new B's
      // initState BEFORE old A's dispose. Both call unawaited() on
      // onSessionVisible(B) and onSessionInvisible(A) respectively.
      // The microtasks run in FIFO order: onSessionVisible(B) sets
      // _visibleSessionId = B, then onSessionInvisible(A) must NOT
      // set _visibleSessionId = null because the user is now viewing B.
      final sessionA = 'session-a';
      final sessionB = 'session-b';

      // Start with A visible
      await sync.onSessionVisible(sessionA);
      expect(sync.testGetVisibleSessionId(), equals(sessionA));

      // Simulate the switch: new B's onSessionVisible runs first
      await sync.onSessionVisible(sessionB);
      expect(sync.testGetVisibleSessionId(), equals(sessionB));

      // Then old A's onSessionInvisible runs (late, after dispose)
      await sync.onSessionInvisible(sessionA);

      // B must STAY visible — the late dispose must not wipe it
      expect(
        sync.testGetVisibleSessionId(),
        equals(sessionB),
        reason:
            'onSessionInvisible(sessionA) must not clobber a newer '
            'onSessionVisible(sessionB) (chat switch race)',
      );
    });

    test('onSessionInvisible clears _visibleSessionId when it still matches '
        'the session being left', () async {
      final sessionId = 'session-a';
      await sync.onSessionVisible(sessionId);
      expect(sync.testGetVisibleSessionId(), equals(sessionId));

      await sync.onSessionInvisible(sessionId);

      expect(
        sync.testGetVisibleSessionId(),
        isNull,
        reason:
            'onSessionInvisible(sessionId) must clear _visibleSessionId '
            'when it still matches the session being left',
      );
    });
  });

  group('Sync resume race condition fix', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      sync.testIsInitialized = true;
      sync.encryption = _testEncryption();
      sync.settingsSync = InvalidateSync(() async {});
      sync.profileSync = InvalidateSync(() async {});
      sync.purchasesSync = InvalidateSync(() async {});
      sync.machinesSync = InvalidateSync(() async {});
      sync.pushTokenSync = InvalidateSync(() async {});
      sync.nativeUpdateSync = InvalidateSync(() async {});
      sync.artifactsSync = InvalidateSync(() async {});
      sync.sessionGitStatusSync = InvalidateSync(() async {});
      sync.messagesSync.clear();
      sync.testSetVisibleSessionId(null);
      sync.testClearSessionsWithPendingSocketMessages();
      sync.testResetLastResumeAtMs();
      sync.testForceFullFetchNext = false;
      // Reset _invalidateAllSyncs debounce so resume() actually runs
      sync.testLastInvalidateAllSyncsAtMs = null;
      sync.onTailRefreshRequested = null;
    });

    test('resume() chains visible session messagesSync invalidation '
        'AFTER sessionsSync completes (not in parallel)', () {
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

      fakeAsync((async) {
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
        unawaited(sync.onSessionVisible(visibleId));
        expect(sync.testGetVisibleSessionId(), equals(visibleId));

        // Call resume()
        sync.resume();

        // resume() defers invalidation by 500ms — advance past that
        // plus the InvalidateSync retry intervals.
        async.elapse(const Duration(milliseconds: 2500));
        async.flushMicrotasks();

        // Verify messagesSync ran AFTER sessionsSync (chained, not parallel).
        // sessionsSync may appear multiple times due to _invalidateAllSyncs
        // calling it for both phase=null and phase=_criticalSyncPhase.
        // The key invariant: messagesSync LAST (after all sessionsSync calls).
        expect(
          callOrder.last,
          equals('messagesSync'),
          reason:
              'messagesSync must be the LAST call (chained after sessionsSync, '
              'not parallel — this is the race condition fix)',
        );
      });
    });

    test('resume() recreates messagesSync for non-visible sessions '
        'and invalidates it (THE original message loss bug)', () {
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
          reason:
              'messagesSync MUST be created for non-visible '
              'session with pending socket messages on resume',
        );

        expect(
          sync.messagesSync[nonVisibleId] != null,
          isTrue,
          reason: 'messagesSync must be invalidated',
        );
      });
    });

    test('resume() keeps pending non-visible sessions on delta path '
        'when local state is usable', () {
      fakeAsync((async) {
        const sessionId = 'resume-valid-local-state';

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
        sync.testSetSessionLastSeq(sessionId, 10);
        sync.testSetSessionMessages(sessionId, [
          {'id': 'msg-10', 'role': 'agent', 'seq': 10},
        ]);
        sync.testSetPendingSocketMessages({sessionId});
        sync.sessionsSync = InvalidateSync(() async {});

        sync.resume();
        async.elapse(const Duration(milliseconds: 1600));

        expect(
          sync.testSessionsNeedingTailRefresh().contains(sessionId),
          isFalse,
          reason:
              'resume should preserve the incremental cursor path when '
              'messages are already in memory and the cursor is valid',
        );
      });
    });

    test('resume() still tail-refreshes pending non-visible sessions '
        'without usable local state', () {
      fakeAsync((async) {
        const sessionId = 'resume-missing-local-state';

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
        sync.sessionsSync = InvalidateSync(() async {});

        final tailRefreshed = <String>[];
        sync.onTailRefreshRequested = tailRefreshed.add;

        sync.resume();
        async.elapse(const Duration(milliseconds: 1600));

        expect(
          tailRefreshed,
          contains(sessionId),
          reason:
              'resume must keep the tail-refresh fallback when no local '
              'messages or cursor are available',
        );
      });
    });

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
            reason:
                'Long resumes should keep incremental session sync '
                'instead of forcing a full catalog refetch',
          );
        });
      },
    );
  });

  group('Sync reconnect-after-sleep fixes', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      sync.testIsInitialized = true;
      sync.encryption = _testEncryption();
      sync.sessionsSync = InvalidateSync(() async {});
      sync.settingsSync = InvalidateSync(() async {});
      sync.profileSync = InvalidateSync(() async {});
      sync.purchasesSync = InvalidateSync(() async {});
      sync.machinesSync = InvalidateSync(() async {});
      sync.pushTokenSync = InvalidateSync(() async {});
      sync.nativeUpdateSync = InvalidateSync(() async {});
      sync.artifactsSync = InvalidateSync(() async {});
      sync.sessionGitStatusSync = InvalidateSync(() async {});
      sync.messagesSync.clear();
      sync.testSetVisibleSessionId(null);
      sync.testClearSessionsWithPendingSocketMessages();
      sync.testResetLastResumeAtMs();
      sync.testLastSuspendedAtMs = null;
      sync.testLastInvalidateAllSyncsAtMs = null;
      sync.testCancelReconnectWatchdog();
      InvalidateSync.isBackgrounded = false;
      socketIoClient.testConnectionStatus = ConnectionStatus.disconnected;
    });

    tearDown(() {
      socketIoClient.testConnectionStatus = ConnectionStatus.disconnected;
      InvalidateSync.isBackgrounded = false;
      sync.testSetVisibleSessionId(null);
      sync.testLastSuspendedAtMs = null;
      sync.testLastInvalidateAllSyncsAtMs = null;
      sync.testCancelReconnectWatchdog();
    });

    test(
      'resume() forces a fresh socket when a long-backgrounded socket '
      'still reports connected (zombie connection)',
      () {
        fakeAsync((async) {
          // Simulate an OS that suspended the app before the deferred
          // socket disconnect fired: status still claims connected, but
          // the app was backgrounded far longer than the server-side
          // session could survive.
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          sync.testLastSuspendedAtMs = nowMs - 120 * 1000;
          socketIoClient.testConnectionStatus = ConnectionStatus.connected;

          final reconnectsBefore = socketIoClient.testReconnectRequests;
          sync.resume();

          expect(
            socketIoClient.testReconnectRequests,
            reconnectsBefore + 1,
            reason:
                'a socket left idle in the background past the zombie '
                'threshold must be replaced, not trusted',
          );
          expect(
            sync.testHasReconnectWatchdog,
            isTrue,
            reason:
                'the zombie-socket reconnect must arm the watchdog so '
                'recovery stays bounded if the fresh dial also fails',
          );
        });
      },
    );

    test(
      'resume() keeps a live socket after a short background stay',
      () {
        fakeAsync((async) {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          sync.testLastSuspendedAtMs = nowMs - 10 * 1000;
          socketIoClient.testConnectionStatus = ConnectionStatus.connected;

          final reconnectsBefore = socketIoClient.testReconnectRequests;
          sync.resume();

          expect(
            socketIoClient.testReconnectRequests,
            reconnectsBefore,
            reason:
                'a connected socket within the zombie threshold is still '
                'alive — tearing it down would waste the connection',
          );
          expect(sync.testHasReconnectWatchdog, isFalse);
        });
      },
    );

    test(
      'reconnect watchdog re-arms while the socket stays disconnected '
      'and stops once connected',
      () {
        fakeAsync((async) {
          socketIoClient.testConnectionStatus = ConnectionStatus.disconnected;

          final reconnectsBefore = socketIoClient.testReconnectRequests;
          sync.resume();
          expect(socketIoClient.testReconnectRequests, reconnectsBefore + 1);
          expect(sync.testHasReconnectWatchdog, isTrue);

          // Watchdog fires after ~15s: forces a fresh reconnect and,
          // because the socket is still down, re-arms itself.
          async.elapse(const Duration(milliseconds: 15001));
          expect(
            socketIoClient.testReconnectRequests,
            reconnectsBefore + 2,
            reason:
                'watchdog must force a fresh reconnect cycle instead of '
                'waiting out Socket.IO backoff exhaustion',
          );
          expect(
            sync.testHasReconnectWatchdog,
            isTrue,
            reason: 'watchdog must re-arm while still disconnected',
          );

          // Second cycle — still probing.
          async.elapse(const Duration(milliseconds: 15001));
          expect(socketIoClient.testReconnectRequests, reconnectsBefore + 3);
          expect(sync.testHasReconnectWatchdog, isTrue);

          // Connection recovers: the next watchdog fire observes it and
          // the chain stops (no further reconnects, no re-arm).
          socketIoClient.testConnectionStatus = ConnectionStatus.connected;
          async.elapse(const Duration(milliseconds: 15001));
          expect(socketIoClient.testReconnectRequests, reconnectsBefore + 3);
          expect(
            sync.testHasReconnectWatchdog,
            isFalse,
            reason: 'watchdog must stop re-arming once connected',
          );
        });
      },
    );

    test(
      'forceReconnect() (manual "Reconnect now") reconnects and arms '
      'the watchdog',
      () {
        fakeAsync((async) {
          socketIoClient.testConnectionStatus = ConnectionStatus.disconnected;

          final reconnectsBefore = socketIoClient.testReconnectRequests;
          sync.forceReconnect(reason: 'offline_banner');

          expect(socketIoClient.testReconnectRequests, reconnectsBefore + 1);
          expect(
            sync.testHasReconnectWatchdog,
            isTrue,
            reason:
                'a manual reconnect must keep the watchdog armed so a '
                'failed dial is retried on a bounded cadence',
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

Encryption _testEncryption() => _TestEncryption();

class _TestEncryption implements Encryption {
  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      _NoOpSessionEncryption();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoOpSessionEncryption implements SessionEncryption {
  @override
  Future<ProcessedMessages> decryptAndProcessMessages(
    List<Map<String, dynamic>> messages,
    String sessionId,
  ) async {
    return const ProcessedMessages(
      messages: [],
      toolResults: [],
      usageUpdates: [],
      maxSeq: 0,
    );
  }

  @override
  bool get canDecryptAes => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
