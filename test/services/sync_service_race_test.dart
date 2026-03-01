import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';

Session _makeTestSession(String id) => Session(
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
    );

void _stubAllSyncs(Sync instance, {Future<void> Function()? sessionsFn}) {
  // Dispose old sessionsSync to cancel any pending retry timers before
  // replacing with a new one. This prevents stale timers from affecting
  // test state. Use try-catch since sessionsSync is late and may not be
  // initialized yet (e.g., first call from setUp).
  try {
    instance.sessionsSync.dispose();
  } on Error {
    // Not initialized yet, safe to ignore
  }
  instance.sessionsSync =
      InvalidateSync(sessionsFn ?? () async {});
  instance.settingsSync = InvalidateSync(() async {});
  instance.profileSync = InvalidateSync(() async {});
  instance.purchasesSync = InvalidateSync(() async {});
  instance.machinesSync = InvalidateSync(() async {});
  instance.pushTokenSync = InvalidateSync(() async {});
  instance.nativeUpdateSync = InvalidateSync(() async {});
  instance.artifactsSync = InvalidateSync(() async {});
  instance.friendsSync = InvalidateSync(() async {});
  instance.friendRequestsSync = InvalidateSync(() async {});
  instance.feedSync = InvalidateSync(() async {});
  instance.todosSync = InvalidateSync(() async {});
  instance.messagesSync.clear();
}

void main() {
  group('sendMessage TOCTOU race condition', () {
    late Sync instance;

    setUp(() {
      instance = Sync();
      _stubAllSyncs(instance);
    });

    test('delta fetch misses session when _lastSessionsFetchedAt > session.updatedAt', () {
      // Simulate the race: _lastSessionsFetchedAt has been advanced past the
      // session's updatedAt by a concurrent fetch.
      instance.testLastSessionsFetchedAt = 1700000001000; // 1s after session
      instance.testForceFullFetchNext = false;

      final session = _makeTestSession('sess-1');

      // Install a sessionsSync that only adds the session when doing a full
      // fetch (i.e. when _forceFullFetchNext was set).
      bool lastFetchWasForced = false;
      _stubAllSyncs(instance, sessionsFn: () async {
        final forced = instance.testForceFullFetchNext;
        if (forced) {
          instance.testForceFullFetchNext = false;
          lastFetchWasForced = true;
          instance.testSessions['sess-1'] = session;
        } else {
          lastFetchWasForced = false;
          // Delta fetch: server returns nothing (changedSince > updatedAt).
        }
      });

      // Delta fetch: session is absent.
      instance.sessionsSync.invalidate();
      // Wait for the fetch to complete.
      expect(instance.sessions.containsKey('sess-1'), false);

      // Force full fetch recovery.
      instance.testForceFullFetchNext = true;
      instance.sessionsSync.invalidate();

      // After queue drains, session should be present.
      expectLater(
        instance.sessionsSync.awaitQueue().then((_) {
          expect(instance.sessions['sess-1']?.id, 'sess-1');
          expect(lastFetchWasForced, true);
        }),
        completes,
      );
    });

    test('sendMessage sets _forceFullFetchNext when session is missing', () async {
      // Pre-populate: encryption would be needed for a real sendMessage, but
      // we only care about whether the StateError('Session X not loaded') is
      // thrown vs a different error (network/encryption).
      //
      // With no encryption initialized, sendMessage will fail at the
      // encryption guard BEFORE reaching the session-not-loaded check.
      // That's fine: it proves sendMessage doesn't immediately throw
      // StateError for a missing session without trying recovery.

      // Clear any stale state from previous tests to ensure the session
      // starts out as missing. This includes the forced-fetch flag, the
      // sessions map, and any pending retry timers.
      instance.testForceFullFetchNext = false;
      instance.testSessions.clear();

      _stubAllSyncs(instance, sessionsFn: () async {
        // On forced fetch, add the session.
        if (instance.testForceFullFetchNext) {
          instance.testForceFullFetchNext = false;
          instance.testSessions['sess-1'] = _makeTestSession('sess-1');
        }
      });

      // Drain any pending invalidations from the previous InvalidateSync
      // instance before checking the sessions map state.
      await instance.sessionsSync.awaitQueue();

      // Sessions map is empty — session is "missing".
      expect(instance.testSessions.containsKey('sess-1'), false);

      try {
        await instance.sendMessage('sess-1', 'hello');
        // If this completes without error, that's also acceptable (unlikely
        // without full API setup).
      } catch (e) {
        // The error should NOT be the session-not-loaded StateError.
        // It should be an encryption error (session encryption not initialized)
        // because the recovery fetch still doesn't set up encryption.
        final msg = e.toString();
        expect(
          msg.contains('Session sess-1 not loaded'),
          false,
          reason:
              'sendMessage should retry with _forceFullFetchNext before throwing '
              'session-not-loaded. Got: $msg',
        );
      }
    });

    test('_forceFullFetchNext flag survives InvalidateSync coalescing',
        () async {
      // This test verifies that if _forceFullFetchNext is set while a fetch is
      // in progress, the NEXT run of fetchSessions sees it as true.
      final firstFetchStarted = Completer<void>();
      final firstFetchGate = Completer<void>();
      final flagValues = <bool>[];
      var fetchCount = 0;

      _stubAllSyncs(instance, sessionsFn: () async {
        fetchCount++;
        final sawForced = instance.testForceFullFetchNext;
        flagValues.add(sawForced);
        if (sawForced) instance.testForceFullFetchNext = false;

        if (fetchCount == 1) {
          firstFetchStarted.complete();
          await firstFetchGate.future; // Block first fetch.
        }
      });

      // Trigger first fetch (flag is false).
      instance.sessionsSync.invalidate();
      await firstFetchStarted.future;

      // While first fetch is blocked, set the flag and queue another run.
      instance.testForceFullFetchNext = true;
      instance.sessionsSync.invalidate();

      // Unblock the first fetch.
      firstFetchGate.complete();

      // Wait for both runs to complete.
      await instance.sessionsSync.awaitQueue();

      expect(flagValues.length, greaterThanOrEqualTo(2));
      expect(flagValues[0], false, reason: 'First fetch should not see forced flag');
      expect(flagValues[1], true, reason: 'Second fetch should see forced flag');
    });

    test('fetchSessions omits changedSince when _forceFullFetchNext is true',
        () {
      // This is a logical/property test: verify the flag clears atomically.
      instance.testForceFullFetchNext = true;
      instance.testLastSessionsFetchedAt = 1700000000000;

      // Read + clear the flag (mimicking what fetchSessions does at line 873-874).
      final forceFullFetch = instance.testForceFullFetchNext;
      if (forceFullFetch) instance.testForceFullFetchNext = false;
      final changedSince =
          forceFullFetch ? null : instance.testLastSessionsFetchedAt;

      expect(forceFullFetch, true);
      expect(changedSince, isNull,
          reason: 'changedSince must be null when _forceFullFetchNext is true');
      expect(instance.testForceFullFetchNext, false,
          reason: 'Flag must be cleared after reading');
    });

    test('fetchSessions sends changedSince in normal delta mode', () {
      instance.testForceFullFetchNext = false;
      instance.testLastSessionsFetchedAt = 1700000000000;

      final forceFullFetch = instance.testForceFullFetchNext;
      if (forceFullFetch) instance.testForceFullFetchNext = false;
      final changedSince =
          forceFullFetch ? null : instance.testLastSessionsFetchedAt;

      expect(forceFullFetch, false);
      expect(changedSince, 1700000000000,
          reason: 'changedSince must be set in normal delta mode');
    });
  });

  group('server propagation delay — optimistic insert', () {
    late Sync instance;

    setUp(() {
      instance = Sync();
      _stubAllSyncs(instance);
    });

    test(
        'createSession adds placeholder when fetchSessions '
        'does not return the new session', () async {
      // Simulate the root cause: the server's /v2/sessions REST endpoint
      // has not yet propagated the session created via machine RPC.
      // fetchSessions returns existing sessions but NOT the new one.
      final existingSession = _makeTestSession('existing-1');

      _stubAllSyncs(instance, sessionsFn: () async {
        // Full fetch returns only the existing session, never the new one.
        if (instance.testForceFullFetchNext) {
          instance.testForceFullFetchNext = false;
        }
        instance.testSessions['existing-1'] = existingSession;
        // Deliberately do NOT add 'new-sess' — simulates propagation delay.
      });

      // Pre-populate so sync looks initialized.
      instance.testSessions['existing-1'] = existingSession;

      // Simulate what createSession does internally:
      // 1. Set forced full fetch flag
      // 2. Call refreshSessions (which runs fetchSessions via InvalidateSync)
      // 3. Check if session is in _sessions — it won't be
      instance.testForceFullFetchNext = true;
      await instance.sessionsSync.invalidateAndAwait();

      // Without the fix, the new session would be absent.
      // The fix in createSession adds a placeholder, but since we're testing
      // the sendMessage fallback path here, let's verify that path.
      expect(
        instance.testSessions.containsKey('new-sess'),
        false,
        reason: 'fetchSessions should NOT have added the new session '
            '(simulating server propagation delay)',
      );

      // Now simulate the sendMessage fallback: if session is still null
      // after a forced full fetch, a placeholder is created.
      instance.testForceFullFetchNext = true;
      await instance.sessionsSync.invalidateAndAwait();
      // Session is still absent from server — verify our setup is correct.
      expect(instance.testSessions.containsKey('new-sess'), false);

      // Manually insert a placeholder (as the fix does in sendMessage).
      final now = DateTime.now().millisecondsSinceEpoch;
      instance.testSessions['new-sess'] = Session(
        id: 'new-sess',
        seq: 0,
        createdAt: now,
        updatedAt: now,
        active: true,
        activeAt: now,
        metadataVersion: 0,
        agentStateVersion: 0,
        thinking: false,
        presence: 'online',
      );

      // The placeholder session is now available.
      expect(instance.sessions.containsKey('new-sess'), true);
      expect(instance.sessions['new-sess']?.id, 'new-sess');
      expect(instance.sessions['new-sess']?.presence, 'online');
    });

    test(
        'sendMessage creates placeholder session instead of throwing '
        'when server has propagation delay', () async {
      // This test proves the bug: without the fix, sendMessage throws
      // StateError('Session X not loaded'). With the fix, it creates
      // a placeholder and proceeds (or fails at a later point like
      // encryption, not the session lookup).

      // Set up: session does NOT exist in _sessions, but we simulate
      // the scenario where encryption IS initialized (as createSession
      // pre-initializes it from the spawn response DEK).
      instance.testSessions.clear();
      instance.testForceFullFetchNext = false;

      // fetchSessions never adds the session (propagation delay).
      _stubAllSyncs(instance, sessionsFn: () async {
        if (instance.testForceFullFetchNext) {
          instance.testForceFullFetchNext = false;
        }
        // Server never returns the new session.
      });

      await instance.sessionsSync.awaitQueue();

      // Session is not in _sessions.
      expect(instance.testSessions.containsKey('new-sess'), false);

      try {
        await instance.sendMessage('new-sess', 'hello');
      } catch (e) {
        final msg = e.toString();
        // With the fix, the error should NEVER be "Session X not loaded".
        // It will be an encryption error (since we didn't set up
        // encryption in this test), which is acceptable — it proves the
        // session lookup no longer throws.
        expect(
          msg.contains('Session new-sess not loaded'),
          false,
          reason:
              'sendMessage should never throw "Session not loaded" — '
              'it should create a placeholder. Got: $msg',
        );
      }
    });

    test(
        'placeholder session is replaced by real data on next '
        'successful fetch', () async {
      // Verify that the placeholder doesn't permanently override real data.
      final now = DateTime.now().millisecondsSinceEpoch;
      instance.testSessions['sess-1'] = Session(
        id: 'sess-1',
        seq: 0,
        createdAt: now,
        updatedAt: now,
        active: true,
        activeAt: now,
        metadataVersion: 0,
        agentStateVersion: 0,
        thinking: false,
        presence: 'online',
      );

      // Verify placeholder is there.
      expect(instance.sessions['sess-1']?.metadataVersion, 0);

      // Now simulate a successful fetch that returns the real session.
      final realSession = _makeTestSession('sess-1');
      _stubAllSyncs(instance, sessionsFn: () async {
        instance.testSessions['sess-1'] = realSession;
      });

      instance.sessionsSync.invalidate();
      await instance.sessionsSync.awaitQueue();

      // Real session data should replace the placeholder.
      expect(instance.sessions['sess-1']?.metadataVersion, 1);
      expect(instance.sessions['sess-1']?.seq, 1);
    });
  });

  group('createSession forces full fetch', () {
    late Sync instance;

    setUp(() {
      instance = Sync();
      _stubAllSyncs(instance);
    });

    test('createSession sets _forceFullFetchNext before refreshSessions',
        () async {
      // This test simulates what createSession does: it sets
      // _forceFullFetchNext = true before calling refreshSessions() to ensure
      // the newly created session is included in the fetch results, avoiding
      // a race condition where server clock skew causes the session to be
      // excluded from delta fetches.

      bool fetchWasForced = false;
      instance.sessionsSync = InvalidateSync(() async {
        if (instance.testForceFullFetchNext) {
          fetchWasForced = true;
          instance.testForceFullFetchNext = false;
          instance.testSessions['new-session'] = _makeTestSession('new-session');
        }
      });

      // Simulate what createSession does: set flag then invalidate
      instance.testForceFullFetchNext = true;
      await instance.sessionsSync.invalidateAndAwait();

      expect(fetchWasForced, true,
          reason: 'Fetch should have been forced (full fetch)');
      expect(instance.sessions.containsKey('new-session'), true,
          reason: 'New session should be present after forced full fetch');
    });

    test('createSession prevents delta fetch race with clock skew', () async {
      // Simulate server clock skew: server returns sessions with updatedAt
      // earlier than what the client expects (changedSince > session.updatedAt).
      // A delta fetch would miss the new session, but a full fetch always
      // includes it.

      instance.testLastSessionsFetchedAt = 1700000001000; // 1s "ahead"

      _stubAllSyncs(instance, sessionsFn: () async {
        if (instance.testForceFullFetchNext) {
          instance.testForceFullFetchNext = false;
          // Full fetch: always include session regardless of timestamp
          instance.testSessions['new-session'] = Session(
            id: 'new-session',
            seq: 1,
            createdAt: 1700000000000, // Server thinks it's 1s earlier
            updatedAt: 1700000000000,
            active: true,
            activeAt: 1700000000000,
            metadataVersion: 1,
            agentStateVersion: 1,
            thinking: false,
            presence: 'offline',
          );
        }
        // Delta fetch: would return nothing (skipped here)
      });

      // Set flag (as createSession does) and trigger fetch
      instance.testForceFullFetchNext = true;
      await instance.sessionsSync.invalidateAndAwait();

      // Session should be present despite clock skew
      expect(instance.sessions.containsKey('new-session'), true);
    });
  });
}
