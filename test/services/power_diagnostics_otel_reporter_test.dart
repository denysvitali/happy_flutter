import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/services/http_request_logger.dart';
import 'package:happy_flutter/core/services/power_diagnostics_otel_reporter.dart';
import 'package:happy_flutter/core/services/power_diagnostics_service.dart';

/// Guards that the OTel metrics bridge never throws when OpenTelemetry is not
/// initialized (the normal flutter test environment), and that local counters
/// are still updated.
void main() {
  test('OTel reporter does not break local counters when OTel is off', () {
    final power = PowerDiagnosticsService();

    expect(
      () {
        PowerDiagnosticsOtelReporter.instance.recordSocketConnect();
        PowerDiagnosticsOtelReporter.instance.recordSocketDisconnect();
        PowerDiagnosticsOtelReporter.instance.recordSocketError();
        PowerDiagnosticsOtelReporter.instance.recordSyncInvalidation();
        PowerDiagnosticsOtelReporter.instance.recordGlobalSyncInvalidation();
        PowerDiagnosticsOtelReporter.instance.recordSyncBackgroundSkip();
        PowerDiagnosticsOtelReporter.instance.recordOutboxSchedule();
        PowerDiagnosticsOtelReporter.instance.recordOutboxAttempt();
        PowerDiagnosticsOtelReporter.instance.recordOutboxFailure();
        PowerDiagnosticsOtelReporter.instance.recordHttpBytes(
          requestBytes: 1024,
          responseBytes: 2048,
        );
      },
      returnsNormally,
    );

    power.recordSocketStatus(ConnectionStatus.connected);
    power.recordSocketStatus(ConnectionStatus.disconnected);
    power.recordSocketStatus(ConnectionStatus.error);
    power.recordSocketError('test');
    power.recordSyncInvalidation('a');
    power.recordSyncInvalidation('b', global: true);
    power.recordSyncBackgroundSkip('c');
    power.recordOutboxSchedule(localId: 'x', delayMs: 100);
    power.recordOutboxAttempt('x');
    power.recordOutboxFailure('x');
    power.recordHttpRequest(
      HttpRequestEntry(
        id: 1,
        timestamp: DateTime.now(),
        method: 'GET',
        path: '/test',
        requestBytes: 100,
        responseBytes: 200,
        durationMs: 50,
        statusCode: 200,
      ),
    );

    final snapshot = power.snapshot();
    expect(snapshot.socketConnects, equals(1));
    expect(snapshot.socketDisconnects, equals(1));
    expect(snapshot.socketErrors, equals(2)); // status error + explicit error
    expect(snapshot.syncInvalidations, equals(2));
    expect(snapshot.globalSyncInvalidations, equals(1));
    expect(snapshot.syncBackgroundSkips, equals(1));
    expect(snapshot.outboxSchedules, equals(1));
    expect(snapshot.outboxAttempts, equals(1));
    expect(snapshot.outboxFailures, equals(1));
    expect(snapshot.httpRequestBytes, equals(100));
    expect(snapshot.httpResponseBytes, equals(200));
  });
}
