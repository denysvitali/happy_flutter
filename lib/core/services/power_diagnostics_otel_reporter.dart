import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' show Counter;
import 'package:flutterrific_opentelemetry/flutterrific_opentelemetry.dart';

/// Forwards [PowerDiagnosticsService] counter increments to OpenTelemetry
/// metrics.
///
/// This is intentionally decoupled from the service so the service does not
/// depend directly on the OTel package.
///
/// **Every method here is best-effort and never throws.** OTel counter
/// creation can fail (uninitialized SDK, no exporter, misconfigured meter) and
/// such a failure must never break local diagnostics or the host flow that is
/// merely trying to record a metric. All swallowing happens in exactly one
/// place — [_bump] — so there is a single documented failure policy rather
/// than eleven bare `catch (_) {}` blocks.
class PowerDiagnosticsOtelReporter {
  PowerDiagnosticsOtelReporter._();

  static final PowerDiagnosticsOtelReporter _instance =
      PowerDiagnosticsOtelReporter._();

  static PowerDiagnosticsOtelReporter get instance => _instance;

  /// Counters, created on first bump and keyed by full metric name, so a
  /// counter that is never bumped is never created.
  final Map<String, Counter<int>> _counters = {};

  UIMeter get _meter {
    return FlutterOTel.meter(name: 'happy_flutter.power_diagnostics');
  }

  /// Adds [delta] to the counter named [name], creating it on first use.
  ///
  /// Swallows every error: see the class doc. This is the only place in the
  /// class that catches.
  void _bump(
    String name, {
    required String description,
    required String unit,
    int delta = 1,
  }) {
    try {
      _counters
          .putIfAbsent(
            name,
            () => _meter.createCounter<int>(
              name: name,
              description: description,
              unit: unit,
            ),
          )
          .add(delta);
    } catch (_) {
      // Best-effort: OTel failures must not break local diagnostics.
    }
  }

  void recordHttpBytes({
    required int requestBytes,
    required int responseBytes,
  }) {
    _bump(
      'happy_flutter.http.request_bytes',
      description: 'Total HTTP request bytes sent',
      unit: 'By',
      delta: requestBytes,
    );
    _bump(
      'happy_flutter.http.response_bytes',
      description: 'Total HTTP response bytes received',
      unit: 'By',
      delta: responseBytes,
    );
  }

  void recordSocketConnect() => _bump(
    'happy_flutter.socket.connects',
    description: 'Socket connection events',
    unit: '{connections}',
  );

  void recordSocketDisconnect() => _bump(
    'happy_flutter.socket.disconnects',
    description: 'Socket disconnect events',
    unit: '{connections}',
  );

  void recordSocketError() => _bump(
    'happy_flutter.socket.errors',
    description: 'Socket errors',
    unit: '{errors}',
  );

  void recordSyncInvalidation() => _bump(
    'happy_flutter.sync.invalidations',
    description: 'Sync invalidation calls',
    unit: '{invalidations}',
  );

  void recordGlobalSyncInvalidation() => _bump(
    'happy_flutter.sync.global_invalidations',
    description: 'Global sync invalidation calls',
    unit: '{invalidations}',
  );

  void recordSyncBackgroundSkip() => _bump(
    'happy_flutter.sync.background_skips',
    description: 'Sync invalidations skipped while backgrounded',
    unit: '{invalidations}',
  );

  void recordOutboxSchedule() => _bump(
    'happy_flutter.outbox.schedules',
    description: 'Message outbox schedule events',
    unit: '{events}',
  );

  void recordOutboxAttempt() => _bump(
    'happy_flutter.outbox.attempts',
    description: 'Message outbox delivery attempts',
    unit: '{events}',
  );

  void recordOutboxFailure() => _bump(
    'happy_flutter.outbox.failures',
    description: 'Message outbox delivery failures',
    unit: '{events}',
  );

  /// Bumps an app-level error counter.
  ///
  /// [name] is a short, dotted identifier such as `app.auto_restore.failed`;
  /// it is emitted as `happy_flutter.<name>`.
  void recordAppError(String name) => _bump(
    'happy_flutter.$name',
    description: 'App-level error event: $name',
    unit: '{events}',
  );
}
