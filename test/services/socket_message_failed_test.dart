import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/power_diagnostics_otel_reporter.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

/// 2026-09-14 audit: the server emits `{code: "message-failed", sid,
/// localId}` from its message-store failure path. The row never got a
/// sequence, so the client's gap recovery cannot detect it — this event is
/// the only signal that a message was lost. The client had **zero**
/// references to `message-failed` anywhere in `lib/`, so it was ignored.
void main() {
  late Sync sync;

  const localId = 'f5d31772-3889-423d-ae71-8e078dfedb82';

  setUp(() {
    sync = createTestSync();
    sync.testClearAllSessionMessageState();
    PowerDiagnosticsOtelReporter.instance.resetDebugBumpTotals();
  });

  tearDown(() {
    sync.testClearAllSessionMessageState();
  });

  test('a message-failed event marks the pending optimistic row failed', () {
    sync.testSetSessionMessages('s1', [
      {'localId': localId, 'sendStatus': 'sending', 'content': 'hello'},
    ]);

    sync.testHandleServerErrorEvent({
      'code': 'message-failed',
      'sid': 's1',
      'localId': localId,
    });

    final messages = sync.testSessionMessages('s1')!;
    expect(messages.single['sendStatus'], 'failed');
    expect(
      messages.single['localId'],
      localId,
      reason: 'the retry affordance must keep the canonical localId',
    );
  });

  test('a message-failed event is counted even with no row to mark', () {
    // The common production case: a daemon-originated frame has no
    // optimistic row on this client, so there is nothing to mark — but the
    // loss still has to be visible.
    sync.testHandleServerErrorEvent({
      'code': 'message-failed',
      'sid': 's1',
      'localId': localId,
    });

    expect(
      PowerDiagnosticsOtelReporter
          .instance
          .debugBumpTotals['happy_flutter.app.messaging.server_dropped'],
      1,
    );
  });

  test('an unrelated error code is ignored', () {
    sync.testSetSessionMessages('s1', [
      {'localId': localId, 'sendStatus': 'sending'},
    ]);

    sync.testHandleServerErrorEvent({'code': 'something-else', 'sid': 's1'});

    final messages = sync.testSessionMessages('s1')!;
    expect(messages.single['sendStatus'], 'sending');
    expect(
      PowerDiagnosticsOtelReporter
          .instance
          .debugBumpTotals['happy_flutter.app.messaging.server_dropped'],
      isNull,
    );
  });
}
