import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

/// Tests that the resume "Fetching conversations" progress indicator
/// always resolves to either complete or hidden, regardless of whether
/// the underlying `sessionsSync.awaitQueue()` or batched
/// `messagesSync.invalidate()` calls succeed.
///
/// Production bug: when `fetchSessions` threw (e.g. the null-check
/// fatal currently producing ~2,500 events/day), the `.then(...)`
/// continuation that called `_advanceResumeConversationProgress`
/// never ran, leaving the bar stuck at "0 of 1 complete" forever.
void main() {
  late Sync instance;

  setUp(() {
    instance = Sync();
    instance.sessionsSync = InvalidateSync(() async {});
    instance.settingsSync = InvalidateSync(() async {});
    instance.profileSync = InvalidateSync(() async {});
    instance.purchasesSync = InvalidateSync(() async {});
    instance.machinesSync = InvalidateSync(() async {});
    instance.pushTokenSync = InvalidateSync(() async {});
    instance.nativeUpdateSync = InvalidateSync(() async {});
    instance.artifactsSync = InvalidateSync(() async {});
    instance.sessionGitStatusSync = InvalidateSync(() async {});
    instance.messagesSync.clear();
  });

  tearDown(() {
    // Cancel any leftover safety timer between tests.
    instance.testStartResumeConversationProgress(0);
  });

  group('resume conversation progress safety', () {
    test('safety timeout force-clears progress if fetch never completes', () {
      fakeAsync((async) {
        instance.testStartResumeConversationProgress(3);

        // Bar is shown at 0 of 3.
        expect(instance.testResumeConversationProgress, equals((0, 3)));
        expect(instance.testSyncProgress, isNotNull);
        expect(instance.testSyncProgress!.completed, equals(0));
        expect(instance.testSyncProgress!.total, equals(3));
        expect(
          instance.testResumeConversationProgressSafetyTimerActive,
          isTrue,
          reason: 'safety timer must be armed when progress starts',
        );

        // Simulate a fetch failure: no advance is called, time passes.
        // 29s — still hanging.
        async.elapse(const Duration(seconds: 29));
        expect(
          instance.testResumeConversationProgress,
          equals((0, 3)),
          reason: 'progress should still be visible just before timeout',
        );

        // At 30s the safety timer fires and clears the indicator.
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(
          instance.testResumeConversationProgress,
          equals((0, 0)),
          reason:
              'safety timeout must reset internal counters so future '
              'advance() calls become no-ops',
        );
        expect(
          instance.testSyncProgress,
          isNull,
          reason:
              'safety timeout must clear _syncProgress so the UI bar '
              'disappears',
        );
        expect(
          instance.testResumeConversationProgressSafetyTimerActive,
          isFalse,
          reason:
              'safety timer slot must be reset after firing so the '
              'next resume cycle can re-arm it',
        );
      });
    });

    test('starting a new progress cycle cancels the previous safety timer', () {
      fakeAsync((async) {
        instance.testStartResumeConversationProgress(2);
        expect(
          instance.testResumeConversationProgressSafetyTimerActive,
          isTrue,
        );

        // 10s in, a new resume cycle begins.
        async.elapse(const Duration(seconds: 10));
        instance.testStartResumeConversationProgress(5);

        // The new total should be 5, not 2 + 5.
        expect(instance.testResumeConversationProgress, equals((0, 5)));
        expect(
          instance.testResumeConversationProgressSafetyTimerActive,
          isTrue,
        );

        // The OLD safety timer would have fired at t=30s (counted
        // from the first start), i.e. 20s from now. If it weren't
        // cancelled, advancing 25s would clear the new progress
        // prematurely.
        async.elapse(const Duration(seconds: 25));
        expect(
          instance.testResumeConversationProgress,
          equals((0, 5)),
          reason:
              'first-cycle safety timer must have been cancelled when '
              'the second cycle started — otherwise it would clear '
              'progress prematurely',
        );

        // 35s from the second start, the new timer should fire.
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();
        expect(instance.testResumeConversationProgress, equals((0, 0)));
        expect(instance.testSyncProgress, isNull);
      });
    });

    test('advance completes progress and cancels the safety timer', () {
      fakeAsync((async) {
        instance.testStartResumeConversationProgress(3);
        expect(
          instance.testResumeConversationProgressSafetyTimerActive,
          isTrue,
        );

        // Two batches complete: 2 then 1. After the second, total is
        // reached and the safety timer must be cancelled.
        instance.testAdvanceResumeConversationProgress(2);
        expect(instance.testResumeConversationProgress, equals((2, 3)));
        expect(
          instance.testResumeConversationProgressSafetyTimerActive,
          isTrue,
        );

        instance.testAdvanceResumeConversationProgress(1);
        expect(
          instance.testResumeConversationProgress,
          equals((0, 0)),
          reason:
              'completion must reset internal counters so a second '
              'resume cycle starts cleanly',
        );
        expect(
          instance.testResumeConversationProgressSafetyTimerActive,
          isFalse,
          reason: 'completion must cancel the safety timer',
        );

        // No timer should fire even if we elapse past the original
        // 30s window.
        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();
        // Still 0/0 — nothing changed.
        expect(instance.testResumeConversationProgress, equals((0, 0)));
      });
    });

    test('overshoot is impossible once total is reached', () {
      fakeAsync((async) {
        instance.testStartResumeConversationProgress(2);

        // Advance by 5 when total is 2 — must clamp via min().
        instance.testAdvanceResumeConversationProgress(5);
        // Reset to (0, 0) because completion >= total.
        expect(instance.testResumeConversationProgress, equals((0, 0)));

        // Further advance calls are no-ops.
        instance.testAdvanceResumeConversationProgress(10);
        expect(instance.testResumeConversationProgress, equals((0, 0)));
        async.flushMicrotasks();
      });
    });

    test('starting with total <= 0 is a no-op but still cancels '
        'pending safety timer', () {
      fakeAsync((async) {
        instance.testStartResumeConversationProgress(4);
        expect(
          instance.testResumeConversationProgressSafetyTimerActive,
          isTrue,
        );

        // Some resume cycles compute resumeConversationIds.length == 0
        // when nothing needs refreshing. Starting with 0 must still
        // cancel a stale timer from a previous cycle.
        instance.testStartResumeConversationProgress(0);
        expect(
          instance.testResumeConversationProgressSafetyTimerActive,
          isFalse,
        );

        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();
        expect(instance.testResumeConversationProgress, equals((0, 0)));
      });
    });

    test('resume clears progress when sessions sync wait times out', () {
      fakeAsync((async) {
        final sessionsBlocker = Completer<void>();
        var messageFetches = 0;

        instance.testIsInitialized = true;
        instance.testResetLastResumeAtMs();
        instance.testLastInvalidateAllSyncsAtMs = null;
        instance.testSetPendingSocketMessages({'slow-session'});
        instance.sessionsSync = InvalidateSync(() => sessionsBlocker.future);
        instance.messagesSync['slow-session'] = InvalidateSync(() async {
          messageFetches++;
        });

        instance.resume();
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(
          instance.testResumeConversationProgress,
          equals((0, 1)),
          reason: 'resume should show pending conversation progress',
        );

        async.elapse(
          Sync.resumeSessionsAwaitTimeoutForTesting +
              const Duration(seconds: 1),
        );
        async.flushMicrotasks();

        expect(
          instance.testResumeConversationProgress,
          equals((0, 0)),
          reason:
              'resume progress should clear on the bounded sessions wait '
              'instead of reaching the 30s safety timeout',
        );
        expect(instance.testSyncProgress, isNull);
        expect(
          messageFetches,
          equals(0),
          reason:
              'message fetches should not fan out while the prerequisite '
              'sessions refresh is still stuck',
        );

        sessionsBlocker.complete();
      });
    });

    test('resume swallows sessionsSync timeout without throwing and '
        'continues processing once the underlying sync finally settles', () {
      fakeAsync((async) {
        // Block sessionsSync long enough to trigger the 6-second
        // resume timeout, then release it so the in-flight call
        // can finish "in the background" — exactly the scenario
        // GlitchTip HAPPY_FLUTTER-3CD captured.
        final sessionsBlocker = Completer<void>();
        var sessionsFetches = 0;
        var messageFetches = 0;
        final unexpectedErrors = <Object>[];

        // Capture any zone-escaped error (including TimeoutException
        // re-throws) — if our fix regresses and the timeout escapes
        // the catchError, it would surface here.
        runZonedGuarded(() {
          instance.testIsInitialized = true;
          instance.testResetLastResumeAtMs();
          instance.testLastInvalidateAllSyncsAtMs = null;
          instance.testSetPendingSocketMessages({'slow-session'});
          instance.sessionsSync = InvalidateSync(() async {
            sessionsFetches++;
            await sessionsBlocker.future;
          });
          instance.messagesSync['slow-session'] = InvalidateSync(() async {
            messageFetches++;
          });

          instance.resume();
        }, (e, _) => unexpectedErrors.add(e));

        // Let the deferred resume invalidation kick off.
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(
          sessionsFetches,
          equals(1),
          reason: 'resume must still invoke sessionsSync',
        );
        expect(
          instance.testResumeConversationProgress,
          equals((0, 1)),
          reason: 'progress should show pending while sessionsSync stalls',
        );

        // The bounded wait elapses while the sessionsSync future is still
        // pending — this is the exact "TimeoutException after
        // <_resumeSessionsAwaitTimeout>" path from the production crash.
        async.elapse(
          Sync.resumeSessionsAwaitTimeoutForTesting +
              const Duration(seconds: 1),
        );
        async.flushMicrotasks();

        expect(
          unexpectedErrors,
          isEmpty,
          reason:
              'TimeoutException from the bounded sessions wait must be '
              'swallowed — never bubble up as an uncaught error',
        );
        expect(
          instance.testResumeConversationProgress,
          equals((0, 0)),
          reason:
              'progress should be force-advanced to clear even though '
              'the sessions await timed out',
        );

        // Now the underlying sessionsSync work actually finishes in
        // the background. This must not throw and the messagesSync
        // for the pending session must NOT fire — the .then() chain
        // was already cleared by the timeout path.
        sessionsBlocker.complete();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        expect(unexpectedErrors, isEmpty);
        expect(
          messageFetches,
          equals(0),
          reason:
              'late completion of the timed-out awaitQueue() must not '
              're-fire the deferred messagesSync.invalidate() chain',
        );
      });
    });

    test('resume reuses an already pending sessions sync', () {
      fakeAsync((async) {
        final sessionsBlocker = Completer<void>();
        var sessionsFetches = 0;
        var messageFetches = 0;
        instance.testIsInitialized = true;
        instance.testResetLastResumeAtMs();
        instance.testSetVisibleSessionId('visible-session');
        instance.sessionsSync = InvalidateSync(() async {
          sessionsFetches++;
          await sessionsBlocker.future;
        });
        instance.messagesSync['visible-session'] = InvalidateSync(() async {
          messageFetches++;
        });

        instance.sessionsSync.invalidate();
        async.flushMicrotasks();
        expect(sessionsFetches, 1);

        instance.resume();
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(
          sessionsFetches,
          1,
          reason:
              'deferred resume should await the socket/global sessions fetch '
              'instead of marking it dirty for a second run',
        );

        sessionsBlocker.complete();
        async.flushMicrotasks();

        expect(sessionsFetches, 1);
        expect(messageFetches, 1);
      });
    });

    test('resume reuses a just-completed recovery sessions sync', () {
      fakeAsync((async) {
        var sessionsFetches = 0;
        var messageFetches = 0;
        instance.testIsInitialized = true;
        instance.testResetLastResumeAtMs();
        instance.testLastInvalidateAllSyncsAtMs =
            DateTime.now().millisecondsSinceEpoch;
        instance.testSetVisibleSessionId('visible-session');
        instance.sessionsSync = InvalidateSync(() async {
          sessionsFetches++;
        }, minInterval: const Duration(seconds: 2));
        instance.messagesSync['visible-session'] = InvalidateSync(() async {
          messageFetches++;
        });

        instance.sessionsSync.invalidate();
        async.flushMicrotasks();
        expect(sessionsFetches, 1);
        expect(instance.sessionsSync.lastRunEndMs, isNotNull);

        instance.resume();
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(
          sessionsFetches,
          1,
          reason:
              'deferred resume should not queue another sessions fetch when '
              'a recovery/global sessions refresh just completed',
        );
        expect(
          messageFetches,
          1,
          reason:
              'visible session messages still refresh after the recent '
              'sessions sync settles',
        );
      });
    });

    test('resume conversation progress safety timeout does NOT capture to '
        'Sentry — it is informational', () {
      fakeAsync((async) {
        // The safety timer fires when an upstream invalidation
        // silently fails to advance progress. Production telemetry
        // showed this as a noisy "Sync resume conversation progress
        // timeout (completed 0 of N)" Sentry warning even though the
        // app was working fine. The fix demotes it to a local log;
        // this test guards that contract by exercising the path and
        // asserting nothing throws or escapes.
        final escaped = <Object>[];
        runZonedGuarded(() {
          instance.testStartResumeConversationProgress(1);
          expect(
            instance.testResumeConversationProgressSafetyTimerActive,
            isTrue,
          );

          // Let the 30s safety timer fire without any advance().
          async.elapse(const Duration(seconds: 31));
          async.flushMicrotasks();
        }, (e, _) => escaped.add(e));

        expect(escaped, isEmpty);
        expect(instance.testResumeConversationProgress, equals((0, 0)));
        expect(instance.testSyncProgress, isNull);
        expect(
          instance.testResumeConversationProgressSafetyTimerActive,
          isFalse,
        );
      });
    });
  });
}
