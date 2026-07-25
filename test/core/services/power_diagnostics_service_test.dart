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

      // All records land in one 2-min bucket (test runs in milliseconds).
      expect(snapshot.activitySeries, hasLength(1));
      final sample = snapshot.activitySeries.single;
      expect(sample.socket, 3); // update + ephemeral + non-ack send
      expect(sample.rpc, 1); // ack send
      expect(sample.http, 1);
      expect(sample.sync, 1);
      expect(sample.total, 6);
    });

    test('activity series starts empty and ignores non-radio events', () {
      powerDiagnostics
        ..recordLifecycle('paused')
        ..recordSocketStatus(ConnectionStatus.connecting)
        ..recordSyncBackgroundSkip('fetchMessages')
        ..recordOutboxSchedule(localId: 'a', delayMs: 1)
        ..recordOutboxAttempt('a');

      final snapshot = powerDiagnostics.snapshot();
      expect(snapshot.activitySeries, isEmpty);
    });

    test('does not count sync lifecycle states as app transitions', () {
      powerDiagnostics
        ..recordLifecycle('paused')
        ..recordLifecycle('sync.suspend')
        ..recordLifecycle('resumed')
        ..recordLifecycle('sync.resume');

      final snapshot = powerDiagnostics.snapshot();
      expect(snapshot.lifecycleTransitions, 2);
      expect(snapshot.resumeCount, 1);
      expect(snapshot.suspendCount, 1);
      expect(snapshot.lifecycleStateCounts['paused'], 1);
      expect(snapshot.lifecycleStateCounts['resumed'], 1);
      expect(snapshot.lifecycleStateCounts['sync.suspend'], 1);
      expect(snapshot.lifecycleStateCounts['sync.resume'], 1);
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

    test('normalizes dynamic ids and caps retained endpoint maps', () {
      for (var i = 0; i < 240; i++) {
        powerDiagnostics.recordHttpRequest(
          HttpRequestEntry(
            id: i + 3,
            timestamp: DateTime(2026),
            method: 'GET',
            path: '/v1/unique/$i',
            statusCode: 200,
          ),
        );
      }
      powerDiagnostics
        ..recordHttpRequest(
          HttpRequestEntry(
            id: 300,
            timestamp: DateTime(2026),
            method: 'GET',
            path: '/v3/sessions/123e4567-e89b-12d3-a456-426614174000/messages',
            statusCode: 200,
          ),
        )
        ..recordHttpRequest(
          HttpRequestEntry(
            id: 301,
            timestamp: DateTime(2026),
            method: 'GET',
            path: '/v3/sessions/123e4567-e89b-12d3-a456-426614174111/messages',
            statusCode: 200,
          ),
        );

      final snapshot = powerDiagnostics.snapshot();
      expect(snapshot.httpEndpointCounts['GET /v3/sessions/:id/messages'], 2);
      expect(snapshot.httpEndpointCounts.length, lessThanOrEqualTo(200));
      expect(snapshot.httpEndpointStats.length, lessThanOrEqualTo(200));
    });
  });

  // Counters used to be emitted with no attributes at all, so the raw
  // `errorStr`, sync `name` and outbox `localId` the call sites already
  // carried were thrown away and no `reason` dimension existed anywhere in
  // the client. Bucketing is what makes them safe to export.
  group('PowerDiagnosticsService.classifySocketError', () {
    test('buckets transport failures into stable reasons', () {
      expect(
        PowerDiagnosticsService.classifySocketError(
          'TimeoutException after 0:00:08.000000',
        ),
        'timeout',
      );
      expect(
        PowerDiagnosticsService.classifySocketError(
          'SocketException: Failed host lookup: api.example.com',
        ),
        'dns',
      );
      expect(
        PowerDiagnosticsService.classifySocketError(
          'SocketException: Connection refused (OS Error: errno = 111)',
        ),
        'connection_refused',
      );
      expect(
        PowerDiagnosticsService.classifySocketError(
          'HandshakeException: certificate verify failed',
        ),
        'tls',
      );
      expect(
        PowerDiagnosticsService.classifySocketError('server returned 401'),
        'unauthorized',
      );
      expect(
        PowerDiagnosticsService.classifySocketError('Connection reset by peer'),
        'connection_reset',
      );
    });

    test('never returns an unbounded value', () {
      // Two distinct addresses/ports must collapse to ONE label value,
      // otherwise every reconnect creates a new Prometheus series.
      final first = PowerDiagnosticsService.classifySocketError(
        'websocket error to wss://a.example.com:443/socket abc-123',
      );
      final second = PowerDiagnosticsService.classifySocketError(
        'websocket error to wss://b.example.com:8443/socket def-456',
      );

      expect(first, second);
      expect(first, 'transport');
    });

    test('falls back to a fixed label for unrecognised text', () {
      expect(PowerDiagnosticsService.classifySocketError(''), 'empty');
      expect(
        PowerDiagnosticsService.classifySocketError('something novel'),
        'unknown',
      );
    });
  });

  group('PowerDiagnosticsService outbox failure reasons', () {
    setUp(powerDiagnostics.reset);

    test('records the reason in the event log and keeps the localId local', () {
      powerDiagnostics.recordOutboxFailure('local-abc-123', reason: 'timeout');

      final snapshot = powerDiagnostics.snapshot();
      expect(snapshot.outboxFailures, 1);
      expect(
        snapshot.recentEvents.last.message,
        'failure localId=local-abc-123 reason=timeout',
      );
    });

    test('still accepts a bare localId', () {
      powerDiagnostics.recordOutboxFailure('local-abc-123');

      final snapshot = powerDiagnostics.snapshot();
      expect(snapshot.outboxFailures, 1);
      expect(
        snapshot.recentEvents.last.message,
        'failure localId=local-abc-123',
      );
    });
  });
}
