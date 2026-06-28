import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' show Counter;
import 'package:flutterrific_opentelemetry/flutterrific_opentelemetry.dart';

/// Forwards [PowerDiagnosticsService] counter increments to OpenTelemetry
/// metrics.
///
/// This is intentionally decoupled from the service so the service does not
/// depend directly on the OTel package. All calls are best-effort and wrapped
/// in try/catch: OTel initialization failures must never break local
/// diagnostics or the rest of the app.
class PowerDiagnosticsOtelReporter {
  PowerDiagnosticsOtelReporter._();

  static final PowerDiagnosticsOtelReporter _instance =
      PowerDiagnosticsOtelReporter._();

  static PowerDiagnosticsOtelReporter get instance => _instance;

  Counter<int>? _httpRequestBytesCounter;
  Counter<int>? _httpResponseBytesCounter;
  Counter<int>? _socketConnectCounter;
  Counter<int>? _socketDisconnectCounter;
  Counter<int>? _socketErrorCounter;
  Counter<int>? _syncInvalidationCounter;
  Counter<int>? _syncGlobalInvalidationCounter;
  Counter<int>? _syncBackgroundSkipCounter;
  Counter<int>? _outboxScheduleCounter;
  Counter<int>? _outboxAttemptCounter;
  Counter<int>? _outboxFailureCounter;

  UIMeter get _meter {
    return FlutterOTel.meter(name: 'happy_flutter.power_diagnostics');
  }

  void recordHttpBytes({
    required int requestBytes,
    required int responseBytes,
  }) {
    try {
      _httpRequestBytesCounter ??= _meter.createCounter<int>(
        name: 'happy_flutter.http.request_bytes',
        description: 'Total HTTP request bytes sent',
        unit: 'By',
      );
      _httpResponseBytesCounter ??= _meter.createCounter<int>(
        name: 'happy_flutter.http.response_bytes',
        description: 'Total HTTP response bytes received',
        unit: 'By',
      );
      _httpRequestBytesCounter!.add(requestBytes);
      _httpResponseBytesCounter!.add(responseBytes);
    } catch (_) {
      // Best-effort: OTel failures must not break local diagnostics.
    }
  }

  void recordSocketConnect() {
    try {
      _socketConnectCounter ??= _meter.createCounter<int>(
        name: 'happy_flutter.socket.connects',
        description: 'Socket connection events',
        unit: '{connections}',
      );
      _socketConnectCounter!.add(1);
    } catch (_) {}
  }

  void recordSocketDisconnect() {
    try {
      _socketDisconnectCounter ??= _meter.createCounter<int>(
        name: 'happy_flutter.socket.disconnects',
        description: 'Socket disconnect events',
        unit: '{connections}',
      );
      _socketDisconnectCounter!.add(1);
    } catch (_) {}
  }

  void recordSocketError() {
    try {
      _socketErrorCounter ??= _meter.createCounter<int>(
        name: 'happy_flutter.socket.errors',
        description: 'Socket errors',
        unit: '{errors}',
      );
      _socketErrorCounter!.add(1);
    } catch (_) {}
  }

  void recordSyncInvalidation() {
    try {
      _syncInvalidationCounter ??= _meter.createCounter<int>(
        name: 'happy_flutter.sync.invalidations',
        description: 'Sync invalidation calls',
        unit: '{invalidations}',
      );
      _syncInvalidationCounter!.add(1);
    } catch (_) {}
  }

  void recordGlobalSyncInvalidation() {
    try {
      _syncGlobalInvalidationCounter ??= _meter.createCounter<int>(
        name: 'happy_flutter.sync.global_invalidations',
        description: 'Global sync invalidation calls',
        unit: '{invalidations}',
      );
      _syncGlobalInvalidationCounter!.add(1);
    } catch (_) {}
  }

  void recordSyncBackgroundSkip() {
    try {
      _syncBackgroundSkipCounter ??= _meter.createCounter<int>(
        name: 'happy_flutter.sync.background_skips',
        description: 'Sync invalidations skipped while backgrounded',
        unit: '{invalidations}',
      );
      _syncBackgroundSkipCounter!.add(1);
    } catch (_) {}
  }

  void recordOutboxSchedule() {
    try {
      _outboxScheduleCounter ??= _meter.createCounter<int>(
        name: 'happy_flutter.outbox.schedules',
        description: 'Message outbox schedule events',
        unit: '{events}',
      );
      _outboxScheduleCounter!.add(1);
    } catch (_) {}
  }

  void recordOutboxAttempt() {
    try {
      _outboxAttemptCounter ??= _meter.createCounter<int>(
        name: 'happy_flutter.outbox.attempts',
        description: 'Message outbox delivery attempts',
        unit: '{events}',
      );
      _outboxAttemptCounter!.add(1);
    } catch (_) {}
  }

  void recordOutboxFailure() {
    try {
      _outboxFailureCounter ??= _meter.createCounter<int>(
        name: 'happy_flutter.outbox.failures',
        description: 'Message outbox delivery failures',
        unit: '{events}',
      );
      _outboxFailureCounter!.add(1);
    } catch (_) {}
  }
}
