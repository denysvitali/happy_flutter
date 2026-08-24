import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

/// Progressive-lag remediation, 2026-08-24 (second pass).
///
/// Per-session message windows were bounded but never evicted across
/// sessions: every session that ever received traffic kept its full window
/// (decrypted tool outputs included) for the process lifetime. These tests
/// pin the idle-window shrink sweep: eligibility, the rows it keeps, the
/// scroll-back re-arm, and every skip condition.
void main() {
  late Sync sync;
  const t0 = 1700000000000;
  const idleGap = Sync.idleSessionShrinkAfterMs + 1;

  List<Map<String, dynamic>> rows(int count) =>
      List<Map<String, dynamic>>.generate(
        count,
        (i) => {
          'id': 'm-$i',
          'seq': i + 1,
          'createdAt': i + 1,
          'role': 'assistant',
          'content': 'row $i',
        },
      );

  setUp(() {
    sync = createTestSync();
    sync.testClearAllSessionMessageState();
    sync.testSetVisibleSessionId(null);
    sync.testIdleShrinkNowMsOverride = t0;
  });

  tearDown(() {
    sync.testIdleShrinkNowMsOverride = null;
    sync.testClearAllSessionMessageState();
    sync.testSetVisibleSessionId(null);
  });

  test('an idle background session shrinks to the newest keep-rows and '
      're-arms scroll-back', () {
    sync.testSetSessionMessages('idle', rows(120));

    sync.testIdleShrinkNowMsOverride = t0 + idleGap;
    sync.testRunIdleSessionShrinkSweep();

    final retained = sync.messagesForSession('idle');
    expect(retained, hasLength(Sync.idleSessionShrinkKeepRows));
    expect(
      retained.first['id'],
      'm-${120 - Sync.idleSessionShrinkKeepRows}',
      reason: 'newest rows are kept — the session-card preview must survive',
    );
    expect(retained.last['id'], 'm-119');
    expect(
      sync.hasOlderMessages('idle'),
      isTrue,
      reason:
          'the boundary must re-arm to the oldest retained seq so '
          'reopening pages history back in — never a false "beginning of '
          'conversation" over a shrunk window',
    );
  });

  test('a recently touched session is not shrunk', () {
    sync.testSetSessionMessages('fresh', rows(120));

    sync.testIdleShrinkNowMsOverride = t0 + Sync.idleSessionShrinkAfterMs - 1;
    sync.testRunIdleSessionShrinkSweep();

    expect(sync.messagesForSession('fresh'), hasLength(120));
  });

  test('the visible session is never shrunk regardless of idle time', () {
    sync.testSetVisibleSessionId('visible');
    sync.testSetSessionMessages('visible', rows(120));

    sync.testIdleShrinkNowMsOverride = t0 + idleGap;
    sync.testRunIdleSessionShrinkSweep();

    expect(sync.messagesForSession('visible'), hasLength(120));
  });

  test('a session with an unsettled send is not shrunk', () {
    final withFailed = rows(120);
    withFailed[3] = {
      ...withFailed[3],
      'role': 'user',
      'localId': 'local-3',
      'sendStatus': 'failed',
    };
    sync.testSetSessionMessages('unsettled', withFailed);

    sync.testIdleShrinkNowMsOverride = t0 + idleGap;
    sync.testRunIdleSessionShrinkSweep();

    expect(
      sync.messagesForSession('unsettled'),
      hasLength(120),
      reason:
          'a failed row must stay resident for retry identity and '
          'tap-to-retry',
    );
  });

  test('sessions at or under the keep threshold are untouched', () {
    sync.testSetSessionMessages('small', rows(Sync.idleSessionShrinkKeepRows));

    sync.testIdleShrinkNowMsOverride = t0 + idleGap;
    sync.testRunIdleSessionShrinkSweep();

    expect(
      sync.messagesForSession('small'),
      hasLength(Sync.idleSessionShrinkKeepRows),
    );
  });

  test('every message-window mutation stamps the idle clock', () {
    sync.testSetSessionMessages('stamped', rows(3));
    expect(
      sync.testSessionTouchedAtMs('stamped'),
      t0,
      reason:
          'the _invalidateMessageCaches choke point is what keeps the '
          'sweep away from live sessions — if it stops stamping, every '
          'session becomes eligible',
    );
  });

  test('new traffic after a shrink appends normally and re-arms the idle '
      'clock', () {
    sync.testSetSessionMessages('idle', rows(120));
    sync.testIdleShrinkNowMsOverride = t0 + idleGap;
    sync.testRunIdleSessionShrinkSweep();
    expect(
      sync.messagesForSession('idle'),
      hasLength(Sync.idleSessionShrinkKeepRows),
    );

    sync.testUpsertSessionMessages('idle', [
      {
        'id': 'm-new',
        'seq': 500,
        'createdAt': 500,
        'role': 'assistant',
        'content': 'fresh traffic',
      },
    ]);

    final retained = sync.messagesForSession('idle');
    expect(retained.last['id'], 'm-new');
    expect(retained, hasLength(Sync.idleSessionShrinkKeepRows + 1));
    expect(
      sync.testSessionTouchedAtMs('idle'),
      t0 + idleGap,
      reason: 'the upsert must re-stamp the idle clock',
    );
  });

  group('residency budget (LRU cap on full transcripts)', () {
    // Populate `count` sessions, all touched within the idle grace window so
    // the time-based pass never fires. Recency is encoded in the touch stamp:
    // s0 is newest (t0-1), s{count-1} is oldest (t0-count).
    void seedRecentSessions(int count, {int rowsEach = 120}) {
      for (var i = 0; i < count; i++) {
        final id = 's$i';
        sync.testSetSessionMessages(id, rows(rowsEach));
        sync.testSetSessionTouchedAtMs(id, t0 - (i + 1));
      }
    }

    test('only the most-recently-touched maxFullResidentSessions keep full '
        'transcripts; older ones shrink immediately without the idle wait', () {
      final total = Sync.maxFullResidentSessions + 4;
      seedRecentSessions(total);

      sync.testRunIdleSessionShrinkSweep();

      for (var i = 0; i < Sync.maxFullResidentSessions; i++) {
        expect(
          sync.messagesForSession('s$i'),
          hasLength(120),
          reason:
              's$i is within the ${Sync.maxFullResidentSessions} most-recent '
              'and must keep its full transcript',
        );
      }
      for (var i = Sync.maxFullResidentSessions; i < total; i++) {
        expect(
          sync.messagesForSession('s$i'),
          hasLength(Sync.idleSessionShrinkKeepRows),
          reason:
              's$i is beyond the residency budget and must shrink to the '
              'preview window even though it was touched within the grace '
              'window',
        );
        expect(
          sync.hasOlderMessages('s$i'),
          isTrue,
          reason: 'a budget-shrunk session pages history back in on reopen',
        );
      }
    });

    test('within-budget catalogs are never shrunk', () {
      seedRecentSessions(Sync.maxFullResidentSessions);

      sync.testRunIdleSessionShrinkSweep();

      for (var i = 0; i < Sync.maxFullResidentSessions; i++) {
        expect(sync.messagesForSession('s$i'), hasLength(120));
      }
    });

    test('the visible session never counts against or is evicted by the '
        'budget', () {
      // Fill the budget with newer sessions, then make an older session
      // visible — it must stay full even though it ranks last by recency.
      seedRecentSessions(Sync.maxFullResidentSessions);
      sync.testSetSessionMessages('visible', rows(120));
      sync.testSetSessionTouchedAtMs('visible', t0 - 10000);
      sync.testSetVisibleSessionId('visible');

      sync.testRunIdleSessionShrinkSweep();

      expect(
        sync.messagesForSession('visible'),
        hasLength(120),
        reason: 'the visible session is exempt from the residency budget',
      );
      for (var i = 0; i < Sync.maxFullResidentSessions; i++) {
        expect(
          sync.messagesForSession('s$i'),
          hasLength(120),
          reason:
              'the visible session does not consume a budget slot, so all '
              '${Sync.maxFullResidentSessions} others stay full',
        );
      }
    });

    test('a session with an unsettled send stays full even beyond the '
        'budget', () {
      final total = Sync.maxFullResidentSessions + 1;
      seedRecentSessions(total);
      // Make the oldest (over-budget) session hold a failed send.
      final oldest = 's${total - 1}';
      final withFailed = rows(120);
      withFailed[3] = {...withFailed[3], 'sendStatus': 'failed'};
      sync.testSetSessionMessages(oldest, withFailed);
      sync.testSetSessionTouchedAtMs(oldest, t0 - total);

      sync.testRunIdleSessionShrinkSweep();

      expect(
        sync.messagesForSession(oldest),
        hasLength(120),
        reason:
            'retry identity outranks the residency budget — an unsettled '
            'send keeps the whole window resident',
      );
    });
  });
}
