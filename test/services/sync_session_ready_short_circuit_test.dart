// Regression coverage for the sessionReady short-circuit fix.
//
// Before the fix, `_isSessionReady` required `_lastEphemeralAt` to be fresh
// (< 90 s) regardless of `lifecycleState`. When the agent was mid-think the
// daemon stopped emitting ephemeral keep-alives, so chat.send_message would
// stall `waitForAgentReady` for the full 3000 ms timeout even when the
// agent had clearly connected to Socket.IO (lifecycleState == 'running').
//
// The fix:
//   * `Sync.sessionReadyTimeoutMs` lowered 3000 -> 750 ms
//     (lib/core/services/sync_service.dart).
//   * `_isSessionReady` short-circuits to READY when
//     `effectiveLifecycleState == 'running'` AND
//     `lifecycleStateSince` is fresh (< 120 s), independent of the
//     ephemeral keep-alive timestamp.
//
// These tests pin both the truth table and the no-stall fast path so the
// regression cannot return silently.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('Sync.sessionReadyTimeoutMs', () {
    test('equals 750 (tightened from the old 3000 ms stall)', () {
      // The fix lowered this from 3000 -> 750 ms so that
      // waitForAgentReady's worst-case user-visible stall stays well
      // below the Jaeger p90 of 2.6 s the chat.send_message span was
      // observing before. If this ever drifts, the chat.send path
      // re-introduces the perceived hang.
      expect(Sync.sessionReadyTimeoutMs, 750);
    });
  });

  group('Sync._isSessionReady truth table', () {
    const String sid = 's-ready';
    const String offlineSid = 's-offline';

    late ProviderContainer container;
    late Sync sync;

    setUp(() {
      container = ProviderContainer();
      sync = createTestSync();
    });

    tearDown(() {
      resetTestSync(sync);
      container.dispose();
    });

    Session buildSession({
      required String id,
      required String presence,
      required String lifecycleState,
      int? lifecycleStateSince,
    }) {
      return Session(
        id: id,
        seq: 1,
        createdAt: 0,
        updatedAt: 0,
        active: true,
        activeAt: 0,
        metadataVersion: 0,
        agentStateVersion: 0,
        thinking: false,
        presence: presence,
        lifecycleStateCleartext: lifecycleState,
        metadata: lifecycleStateSince != null
            ? Metadata(
                lifecycleState: lifecycleState,
                lifecycleStateSince: lifecycleStateSince,
              )
            // Fall back to cleartext only: metadata null means
            // effectiveLifecycleState still resolves to cleartext.
            : null,
      );
    }

    test(
      'lifecycleState=running + lifecycleStateSince fresh (< 2 min) '
      '+ ephemeral stale (> 90 s) -> READY (new short-circuit)',
      () {
        fakeAsync((async) {
          final now = DateTime.now().millisecondsSinceEpoch;
          sync.testSessions[sid] = buildSession(
            id: sid,
            presence: 'online',
            lifecycleState: 'running',
            lifecycleStateSince: now - 30 * 1000, // 30 s old — fresh
          );
          // Ephemeral keep-alive timestamp far in the past: 5 minutes.
          // Under the old logic this would have forced `_isSessionReady`
          // to return false and `waitForAgentReady` would have stalled
          // for the full 3000 ms timeout.
          sync.testSetLastEphemeralAt(sid, now - 5 * 60 * 1000);

          expect(
            sync.isSessionReadyForMessages(sid),
            isTrue,
            reason:
                'lifecycleState=running with a fresh lifecycleStateSince '
                'must short-circuit to READY independent of the '
                'ephemeral keep-alive timestamp (the agent confirms '
                'Socket.IO delivery even when it stops emitting '
                'session-alive events while thinking).',
          );
          async.elapse(Duration.zero);
        });
      },
    );

    test(
      'lifecycleState=running + lifecycleStateSince stale (> 2 min) '
      '-> NOT READY (stale lifecycle metadata is untrusted)',
      () {
        fakeAsync((async) {
          final now = DateTime.now().millisecondsSinceEpoch;
          sync.testSessions[sid] = buildSession(
            id: sid,
            presence: 'online',
            lifecycleState: 'running',
            // 5 minutes old: outside the < 120 s freshness window.
            lifecycleStateSince: now - 5 * 60 * 1000,
          );
          sync.testSetLastEphemeralAt(sid, now - 5 * 60 * 1000);

          expect(sync.isSessionReadyForMessages(sid), isFalse);
          async.elapse(Duration.zero);
        });
      },
    );

    test(
      'lifecycleState=running + lifecycleStateSince=null '
      '-> NOT READY when ephemeral is also stale '
      '(cannot short-circuit without a freshness timestamp)',
      () {
        // Production guards the lifecycleState shortcut on
        // `since != null` — when the timestamp is missing the code
        // falls through to the existing ephemeral+online check rather
        // than trusting an unbounded 'running' string. With a stale
        // ephemeral this case is therefore NOT READY; the spec
        // ("lifecycleStateSince=null -> NOT READY") is satisfied
        // because the shortcut cannot rescue it.
        fakeAsync((async) {
          final now = DateTime.now().millisecondsSinceEpoch;
          sync.testSessions[sid] = buildSession(
            id: sid,
            presence: 'online',
            lifecycleState: 'running',
            lifecycleStateSince: null,
          );
          // Stale ephemeral — same shape as the regression's hang
          // scenario, but missing the lifecycleStateSince timestamp
          // that the fix needs to short-circuit.
          sync.testSetLastEphemeralAt(sid, now - 5 * 60 * 1000);

          expect(sync.isSessionReadyForMessages(sid), isFalse);
          async.elapse(Duration.zero);
        });
      },
    );

    test(
      'lifecycleState!=running + isOnline=true + ephemeral fresh '
      '(< 90 s) -> READY (existing path)',
      () {
        fakeAsync((async) {
          final now = DateTime.now().millisecondsSinceEpoch;
          sync.testSessions[sid] = buildSession(
            id: sid,
            presence: 'online',
            lifecycleState: 'starting',
            lifecycleStateSince: now - 10 * 1000,
          );
          // Recent session-alive keep-alive (10 s ago).
          sync.testSetLastEphemeralAt(sid, now - 10 * 1000);

          expect(sync.isSessionReadyForMessages(sid), isTrue);
          async.elapse(Duration.zero);
        });
      },
    );

    test(
      'lifecycleState!=running + isOnline=true + ephemeral stale '
      '(> 90 s) -> NOT READY (existing path; prevents trusting stale '
      "'online' presence after a daemon restart)",
      () {
        fakeAsync((async) {
          final now = DateTime.now().millisecondsSinceEpoch;
          sync.testSessions[sid] = buildSession(
            id: sid,
            presence: 'online',
            lifecycleState: 'starting',
            lifecycleStateSince: now - 10 * 1000,
          );
          // 5 minutes old: outside the < 90 s ephemeral window.
          sync.testSetLastEphemeralAt(sid, now - 5 * 60 * 1000);

          expect(sync.isSessionReadyForMessages(sid), isFalse);
          async.elapse(Duration.zero);
        });
      },
    );

    test(
      'lifecycleState!=running + isOnline=false -> NOT READY',
      () {
        fakeAsync((async) {
          sync.testSessions[offlineSid] = buildSession(
            id: offlineSid,
            presence: 'offline',
            lifecycleState: 'starting',
            lifecycleStateSince:
                DateTime.now().millisecondsSinceEpoch - 1000,
          );
          // Even with a brand-new ephemeral event, an offline session
          // is never ready for incoming messages.
          sync.testSetLastEphemeralAt(
            offlineSid,
            DateTime.now().millisecondsSinceEpoch - 1000,
          );

          expect(sync.isSessionReadyForMessages(offlineSid), isFalse);
          async.elapse(Duration.zero);
        });
      },
    );
  });

  group('Sync.waitForAgentReady fast path + timeout', () {
    // Per project convention we allocate a ProviderContainer per test
    // and dispose it in tearDown. waitForAgentReady itself does not
    // touch providers, but the allocation guards against the
    // production code silently introducing a provider dependency in
    // the future.
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'returns true immediately when lifecycleState=running and '
      'lifecycleStateSince is fresh, even with a stale ephemeral '
      'timestamp (no 750 ms stall)',
      () async {
        final sync = createTestSync();
        const sid = 's-running-fresh';
        final now = DateTime.now().millisecondsSinceEpoch;
        sync.testSessions[sid] = Session(
          id: sid,
          seq: 1,
          createdAt: 0,
          updatedAt: 0,
          active: true,
          activeAt: 0,
          metadataVersion: 0,
          agentStateVersion: 0,
          thinking: false,
          presence: 'online',
          lifecycleStateCleartext: 'running',
          metadata: Metadata(
            lifecycleState: 'running',
            lifecycleStateSince: now - 30 * 1000, // 30 s — fresh
          ),
        );
        // 5 minutes old — well past the 90 s ephemeral window.
        // Under the old logic this scenario stalled waitForAgentReady
        // for the full sessionReadyTimeoutMs.
        sync.testSetLastEphemeralAt(sid, now - 5 * 60 * 1000);

        final sw = Stopwatch()..start();
        final ready = await sync.waitForAgentReady(sid, 5000);
        sw.stop();

        expect(ready, isTrue,
            reason:
                'Fast path must resolve true without waiting for the '
                'sessionReadyTimeoutMs timer to fire.');
        // The fast path is synchronous (returns true before scheduling
        // any timers). It must not consume even close to the 5000 ms
        // timeout we passed. We assert well below that to absorb
        // scheduler noise on shared CI runners.
        expect(sw.elapsedMilliseconds, lessThan(100));

        resetTestSync(sync);
      },
    );

    test(
      'returns false within ~timeoutMs when lifecycleState is empty '
      'and the session is offline',
      () async {
        final sync = createTestSync();
        const sid = 's-cold';
        // Empty lifecycleState (cleartext '') and no metadata:
        // effectiveLifecycleState resolves to null, so the
        // lifecycleState short-circuit is skipped. Offline presence
        // means the ephemeral path also returns false.
        // waitForAgentReady therefore has nothing to short-circuit on
        // and must run out the timer.
        sync.testSessions[sid] = Session(
          id: sid,
          seq: 1,
          createdAt: 0,
          updatedAt: 0,
          active: true,
          activeAt: 0,
          metadataVersion: 0,
          agentStateVersion: 0,
          thinking: false,
          presence: 'offline',
          lifecycleStateCleartext: '',
          metadata: null,
        );

        // Use the production timeout value so the test exercises the
        // exact worst-case wait the user perceives (the regression
        // case reduced this from 3000 ms to 750 ms).
        final sw = Stopwatch()..start();
        final ready = await sync.waitForAgentReady(
          sid,
          Sync.sessionReadyTimeoutMs,
        );
        sw.stop();

        expect(ready, isFalse,
            reason:
                'With no ready signal available (offline presence and '
                'no lifecycle metadata), waitForAgentReady must report '
                'false after the sessionReadyTimeoutMs window.');
        // The wall-clock wait must be roughly the timeout — definitely
        // not zero (would mean we short-circuited) and definitely not
        // less than half the timeout (would mean the timer fired
        // early). We use a generous upper bound to absorb scheduler
        // noise on shared CI runners.
        expect(
          sw.elapsedMilliseconds,
          greaterThanOrEqualTo(Sync.sessionReadyTimeoutMs ~/ 2),
        );
        expect(
          sw.elapsedMilliseconds,
          lessThan(Sync.sessionReadyTimeoutMs + 1000),
        );

        resetTestSync(sync);
      },
    );
  });
}
