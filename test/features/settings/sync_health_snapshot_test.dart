import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_health_snapshot.dart';
import 'package:happy_flutter/core/sync/sync_domain.dart';

void main() {
  test('diagnostic export is metadata-only and redacted', () {
    const snapshot = SyncHealthSnapshot(
      capturedAtMs: 1000,
      initialized: true,
      ready: false,
      networkOnline: true,
      connectionStatus: 'connecting',
      socketGeneration: 4,
      lastSocketEventAtMs: 900,
      reconnectAttempt: 2,
      pendingOutboxCount: 3,
      deadLetterCount: 1,
      domains: <SyncDomainHealthSnapshot>[
        SyncDomainHealthSnapshot(
          domain: SyncDomain.sessions,
          revision: 8,
          pending: true,
          lastSuccessAtMs: 700,
          lastFailureAtMs: 800,
          lastFailureKind: 'timeout',
        ),
      ],
    );

    final export = snapshot.toRedactedText();

    expect(export, contains('"socketGeneration": 4'));
    expect(export, contains('"pendingOutboxCount": 3'));
    expect(export, contains('"lastFailureKind": "timeout"'));
    expect(export, isNot(contains('sessionId')));
    expect(export, isNot(contains('serverUrl')));
    expect(export, isNot(contains('disconnectReason')));
    expect(export, isNot(contains('localId')));
  });
}
