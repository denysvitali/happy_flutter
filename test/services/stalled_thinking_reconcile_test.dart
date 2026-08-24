import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

/// Progressive-lag remediation, third pass 2026-08-24.
///
/// `thinking` is only ever cleared by a server event. A daemon that dies
/// mid-turn — while its heartbeats keep presence `online`, so the 60 s
/// presence timer never fires — leaves it true forever, and every surface
/// keyed on it (streaming caret, stop bar, running tool rows, sub-agent
/// banner) animates at full frame rate on an idle chat: the measured
/// "renderer never idles" signature. These tests pin the stall
/// reconciliation: silence past [Sync.stuckThinkingReconcileAfterMs]
/// demotes thinking locally and walks stuck running rows back to
/// canceled, with the conservative skips intact.
void main() {
  late Sync sync;
  const t0 = 1700000000000;

  Session session({
    String id = 'stalled',
    required bool thinking,
    String presence = 'online',
  }) => Session(
    id: id,
    seq: 1,
    createdAt: t0,
    updatedAt: t0,
    active: true,
    activeAt: t0,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    presence: presence,
    lastSeq: 1,
  );

  List<Map<String, dynamic>> rows() => [
    {
      'id': 'stuck-row',
      'seq': 1,
      'createdAt': 1,
      'kind': 'tool-call',
      'toolUseId': 'tool-stuck',
      'state': 'running',
    },
    {'id': 'text', 'seq': 2, 'createdAt': 2, 'role': 'agent', 'content': 'hi'},
  ];

  setUp(() {
    sync = createTestSync();
    sync.testClearAllSessionMessageState();
    sync.testIdleShrinkNowMsOverride = t0;
  });

  tearDown(() {
    sync.testIdleShrinkNowMsOverride = null;
    sync.testClearAllSessionMessageState();
    sync.testSessions.remove('stalled');
    sync.testSessions.remove('fresh');
    sync.testSetVisibleSessionId(null);
  });

  test('a session silent past the stall threshold is demoted', () {
    sync.testSessions['stalled'] = session(thinking: true);
    sync.testSetSessionMessages('stalled', rows()); // stamps clock at t0

    sync.testIdleShrinkNowMsOverride = t0 + Sync.stuckThinkingReconcileAfterMs;
    sync.testRunIdleSessionShrinkSweep();

    expect(sync.sessionById('stalled')!.thinking, isFalse);
    expect(
      sync.messagesForSession('stalled').first['state'],
      'canceled',
      reason:
          'running rows of a wedged turn walk back like the '
          'presence-offline path',
    );
  });

  test('a session with recent message traffic is never demoted', () {
    sync.testSessions['fresh'] = session(id: 'fresh', thinking: true);
    sync.testSetSessionMessages('fresh', rows());

    sync.testIdleShrinkNowMsOverride =
        t0 + Sync.stuckThinkingReconcileAfterMs - 1;
    sync.testRunIdleSessionShrinkSweep();

    expect(sync.sessionById('fresh')!.thinking, isTrue);
    expect(sync.messagesForSession('fresh').first['state'], 'running');
  });

  test('the visible session is demoted too when silent past the threshold', () {
    sync.testSetVisibleSessionId('stalled');
    sync.testSessions['stalled'] = session(thinking: true);
    sync.testSetSessionMessages('stalled', rows());

    sync.testIdleShrinkNowMsOverride = t0 + Sync.stuckThinkingReconcileAfterMs;
    sync.testRunIdleSessionShrinkSweep();

    expect(sync.sessionById('stalled')!.thinking, isFalse);
  });

  test('a session without a resident window is conservatively skipped', () {
    sync.testSessions['stalled'] = session(thinking: true);

    sync.testIdleShrinkNowMsOverride =
        t0 + Sync.stuckThinkingReconcileAfterMs * 10;
    sync.testRunIdleSessionShrinkSweep();

    expect(sync.sessionById('stalled')!.thinking, isTrue);
  });
}
