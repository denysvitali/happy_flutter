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
}
