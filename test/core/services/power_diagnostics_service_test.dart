import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/services/http_request_logger.dart';
import 'package:happy_flutter/core/services/power_diagnostics_service.dart';

void main() {
  group('PowerDiagnosticsService', () {
    setUp(() {
      powerDiagnostics.reset();
    });

    test('records lifecycle, socket, http, sync, and outbox counters', () {
      powerDiagnostics
        ..recordLifecycle('resumed')
        ..recordLifecycle('paused', rapidCycle: true)
        ..recordSocketStatus(ConnectionStatus.connected)
        ..recordSocketError('timeout')
        ..recordSocketEvent('update', updateType: 'new-message')
        ..recordSocketEvent('ephemeral')
        ..recordSocketSend('rpc')
        ..recordSocketSend('rpc', ack: true)
        ..recordHttpRequest(
          HttpRequestEntry(
            id: 1,
            timestamp: DateTime(2026),
            method: 'GET',
            path: '/v1/sessions',
            statusCode: 500,
            requestBytes: 10,
            responseBytes: 20,
            durationMs: 1200,
          ),
        )
        ..recordSyncInvalidation('all', global: true)
        ..recordSyncBackgroundSkip('fetchSessions')
        ..recordOutboxSchedule(localId: 'local-1', delayMs: 1000)
        ..recordOutboxAttempt('local-1')
        ..recordOutboxFailure('local-1');

      final snapshot = powerDiagnostics.snapshot();
      expect(snapshot.lifecycleTransitions, 2);
      expect(snapshot.resumeCount, 1);
      expect(snapshot.suspendCount, 1);
      expect(snapshot.rapidLifecycleWarnings, 1);
      expect(snapshot.socketConnects, 1);
      expect(snapshot.socketErrors, 1);
      expect(snapshot.socketEvents, 2);
      expect(snapshot.socketEventCounts['update'], 1);
      expect(snapshot.socketEventCounts['ephemeral'], 1);
      expect(snapshot.socketUpdateTypeCounts['new-message'], 1);
      expect(snapshot.socketSends, 1);
      expect(snapshot.socketAckCalls, 1);
      expect(snapshot.socketSendCounts['rpc'], 1);
      expect(snapshot.socketAckCounts['rpc'], 1);
      expect(snapshot.httpRequests, 1);
      expect(snapshot.httpFailures, 1);
      expect(snapshot.httpSlowRequests, 1);
      expect(snapshot.httpRequestBytes, 10);
      expect(snapshot.httpResponseBytes, 20);
      expect(snapshot.httpEndpointCounts['GET /v1/sessions'], 1);
      expect(snapshot.httpEndpointStats['GET /v1/sessions']?.count, 1);
      expect(
        snapshot.httpEndpointStats['GET /v1/sessions']?.averageDurationMs,
        1200,
      );
      expect(snapshot.syncInvalidations, 1);
      expect(snapshot.globalSyncInvalidations, 1);
      expect(snapshot.syncInvalidationCounts['all'], 1);
      expect(snapshot.syncBackgroundSkips, 1);
      expect(snapshot.syncBackgroundSkipCounts['fetchSessions'], 1);
      expect(snapshot.lifecycleStateCounts['resumed'], 1);
      expect(snapshot.lifecycleStateCounts['paused'], 1);
      expect(snapshot.outboxSchedules, 1);
      expect(snapshot.outboxAttempts, 1);
      expect(snapshot.outboxFailures, 1);
      expect(snapshot.recentEvents, hasLength(14));
    });

    test('exports a readable report', () {
      powerDiagnostics.recordHttpRequest(
        HttpRequestEntry(
          id: 1,
          timestamp: DateTime(2026),
          method: 'POST',
          path: '/v1/messages',
          statusCode: 200,
          requestBytes: 256,
          responseBytes: 512,
          durationMs: 80,
        ),
      );

      final report = powerDiagnostics.exportText();
      expect(report, contains('Power Diagnostics'));
      expect(report, contains('requests: 1'));
      expect(report, contains('POST 200 80ms /v1/messages'));
      expect(report, contains('endpoints'));
      expect(report, contains('POST /v1/messages: count=1'));
    });
  });
}
