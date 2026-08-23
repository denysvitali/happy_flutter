import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart'
    show Counter;
import 'package:flutterrific_opentelemetry/flutterrific_opentelemetry.dart';

import 'logger_service.dart';
import 'opentelemetry_service.dart';

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
///
/// Swallowed is not the same as invisible: [_bump] logs the first failure per
/// counter name. The previous bare `catch (_) {}` is why the empty-resource
/// export bug (see `OpenTelemetryService._applyResourceToMeterProvider`) ran
/// unnoticed for the lifetime of the metric pipeline.
class PowerDiagnosticsOtelReporter {
  PowerDiagnosticsOtelReporter._();

  static final PowerDiagnosticsOtelReporter _instance =
      PowerDiagnosticsOtelReporter._();

  static PowerDiagnosticsOtelReporter get instance => _instance;

  /// Counters, created on first bump and keyed by full metric name, so a
  /// counter that is never bumped is never created.
  final Map<String, Counter<int>> _counters = {};

  /// Metric names whose failure has already been logged, so a counter that
  /// fails on every call logs once per process instead of once per event.
  final Set<String> _reportedFailures = {};

  UIMeter get _meter {
    return FlutterOTel.meter(name: 'happy_flutter.power_diagnostics');
  }

  /// Adds [delta] to the counter named [name], creating it on first use.
  ///
  /// [attributes] must be low-cardinality: a value that can take an unbounded
  /// number of forms (a localId, a session id, a raw error string) creates one
  /// Prometheus series per value and will take the collector down. Callers are
  /// responsible for bucketing before they get here.
  ///
  /// Swallows every error: see the class doc. This is the only place in the
  /// class that catches, and it logs the first failure per [name].
  void _bump(
    String name, {
    required String description,
    required String unit,
    int delta = 1,
    Map<String, String> attributes = const {},
  }) {
    // Web builds never initialize OTel (see OpenTelemetryService.initialize);
    // bail before the uninitialized SDK raises per call. Pre-init bumps on
    // native already failed inside the try below, so nothing new is dropped.
    if (!OpenTelemetryService().isInitialized) return;
    try {
      final counter = _counters.putIfAbsent(
        name,
        () => _meter.createCounter<int>(
          name: name,
          description: description,
          unit: unit,
        ),
      );
      if (attributes.isEmpty) {
        counter.add(delta);
      } else {
        counter.addWithMap(delta, attributes);
      }
    } catch (e, stack) {
      // Best-effort: OTel failures must not break local diagnostics — but
      // they must not be invisible either.
      //
      // Counters recorded before `OpenTelemetryService.initialize()` finishes
      // are expected to fail and are not worth reporting; anything after it
      // is a real pipeline defect.
      if (OpenTelemetryService().isInitialized && _reportedFailures.add(name)) {
        logger.warning(
          '[PowerDiagnosticsOtel] counter $name unavailable: $e',
          e,
          stack,
        );
      }
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

  /// [reason] must come from [PowerDiagnosticsService.classifySocketError] —
  /// never a raw exception string.
  void recordSocketError({String reason = 'unknown'}) => _bump(
    'happy_flutter.socket.errors',
    description: 'Socket errors',
    unit: '{errors}',
    attributes: {'reason': reason},
  );

  /// [domain] is the `InvalidateSync` name (`fetchMessages`, `fetchSessions`,
  /// …) — a fixed set defined in code, so it is safe as a label.
  void recordSyncInvalidation({String domain = 'unknown'}) => _bump(
    'happy_flutter.sync.invalidations',
    description: 'Sync invalidation calls',
    unit: '{invalidations}',
    attributes: {'domain': domain},
  );

  void recordGlobalSyncInvalidation({String domain = 'unknown'}) => _bump(
    'happy_flutter.sync.global_invalidations',
    description: 'Global sync invalidation calls',
    unit: '{invalidations}',
    attributes: {'domain': domain},
  );

  void recordSyncBackgroundSkip({String domain = 'unknown'}) => _bump(
    'happy_flutter.sync.background_skips',
    description: 'Sync invalidations skipped while backgrounded',
    unit: '{invalidations}',
    attributes: {'domain': domain},
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

  /// [reason] is a bucketed failure class, never the `localId` — that is a
  /// per-message value and would create one series per sent message.
  void recordOutboxFailure({String reason = 'unknown'}) => _bump(
    'happy_flutter.outbox.failures',
    description: 'Message outbox delivery failures',
    unit: '{events}',
    attributes: {'reason': reason},
  );

  /// A message exhausted its retry budget and was dead-lettered — any
  /// value above zero is a P0 signal (potential permanent message loss).
  /// [reason] follows the same bucketing rule as [recordOutboxFailure].
  void recordOutboxDeadLetter({String reason = 'unknown'}) => _bump(
    'happy_flutter.outbox.dead_lettered',
    description: 'Messages dead-lettered after exhausting the outbox '
        'retry budget (potential permanent loss)',
    unit: '{messages}',
    attributes: {'reason': reason},
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

  /// Messaging-invariant violation counters. [tag] is one of the four
  /// `MessageInvariant` tags. Primed with `delta: 0` at monitor
  /// construction so ALL four series exist from app start (audit
  /// 2026-08-03: lazy creation left three of the four nonexistent, making
  /// "no breaches" indistinguishable from "metric missing" and blocking
  /// `> 0` alerting).
  void recordMessagingInvariant(String tag, {int delta = 1}) => _bump(
    'happy_flutter.app.messaging.invariant.$tag',
    description: 'Messaging invariant violation: $tag',
    unit: '{violations}',
    delta: delta,
  );

  /// Denominator for the invariant violation rate: user message sends
  /// (optimistic mints) observed this process.
  void recordMessageSend() => _bump(
    'happy_flutter.app.messaging.sends',
    description: 'User message sends (optimistic mints)',
    unit: '{sends}',
  );

  /// Denominator for the invariant violation rate: server acks observed
  /// this process (deduped per localId by the monitor).
  void recordMessageAck() => _bump(
    'happy_flutter.app.messaging.acks',
    description: 'Server acks for user messages',
    unit: '{acks}',
  );
}
