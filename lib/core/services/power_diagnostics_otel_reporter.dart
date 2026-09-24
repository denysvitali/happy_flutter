import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;

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
/// merely trying to record a metric. SDK failures are handled by the common
/// [OpenTelemetryService.recordCount] path, which also attaches build identity
/// and reports pipeline failures.
class PowerDiagnosticsOtelReporter {
  PowerDiagnosticsOtelReporter._();

  static final PowerDiagnosticsOtelReporter _instance =
      PowerDiagnosticsOtelReporter._();

  static PowerDiagnosticsOtelReporter get instance => _instance;

  // Aggregate rather than retain individual events during SDK startup.
  // The cap also bounds memory on web, where OTel is never initialized.
  final Map<String, _PendingCounter> _pending = {};
  static const _maxPendingSeries = 256;

  /// Called after the common metric identity and SDK are ready. Zero-valued
  /// entries are retained: absence of violations must be an exported series.
  void flushPendingCounters() {
    if (!OpenTelemetryService().isInitialized) return;
    final pending = _pending.values.toList();
    _pending.clear();
    for (final entry in pending) {
      OpenTelemetryService().recordCount(
        entry.name,
        value: entry.value,
        unit: entry.unit,
        description: entry.description,
        attributes: entry.attributes,
      );
    }
  }

  // Reserve the four fixed invariant series independently of the general cap.
  static const _invariantTags = {
    'unmatched_optimistic',
    'duplicate_local_id',
    'unknown_acked_local_id',
    'retry_created_duplicate',
  };

  /// Every bump this process has attempted, keyed by metric name, tallied
  /// *before* the OTel gate below.
  ///
  /// OTel is never initialized under `flutter test`, so without this a metric
  /// that only matters in production — a drop counter, an invariant violation
  /// — would be unobservable in exactly the tests written to pin it. This
  /// records intent, not export success; it is not a substitute for reading
  /// the real series.
  @visibleForTesting
  final Map<String, int> debugBumpTotals = {};

  @visibleForTesting
  void resetDebugBumpTotals() => debugBumpTotals.clear();

  /// Adds [delta] to the counter named [name], creating it on first use.
  ///
  /// [attributes] must be low-cardinality: a value that can take an unbounded
  /// number of forms (a localId, a session id, a raw error string) creates one
  /// Prometheus series per value and will take the collector down. Callers are
  /// responsible for bucketing before they get here.
  ///
  /// SDK failures are handled by the common metric recording path.
  void _bump(
    String name, {
    required String description,
    required String unit,
    int delta = 1,
    Map<String, String> attributes = const {},
  }) {
    debugBumpTotals.update(
      name,
      (value) => value + delta,
      ifAbsent: () => delta,
    );
    if (delta < 0) return;
    if (!OpenTelemetryService().isInitialized) {
      final keys = attributes.keys.toList()..sort();
      final key = jsonEncode([
        name,
        for (final key in keys) [key, attributes[key]],
      ]);
      final existing = _pending[key];
      if (existing != null) {
        existing.value += delta;
      } else if (_pending.length < _maxPendingSeries ||
          _invariantTags.any(
            (tag) => name == 'happy_flutter.app.messaging.invariant.$tag',
          )) {
        _pending[key] = _PendingCounter(
          name,
          description,
          unit,
          delta,
          Map.of(attributes),
        );
      }
      return;
    }
    OpenTelemetryService().recordCount(
      name,
      value: delta,
      unit: unit,
      description: description,
      attributes: attributes,
    );
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

  /// One completed HTTP attempt, including transport failures with no status.
  /// [result] is a fixed cause bucket from the HTTP tracker.
  void recordHttpResult({
    required String result,
    required bool cached,
    required int attempt,
  }) => _bump(
    'happy_flutter.http.attempts',
    description: 'HTTP attempts by outcome, cache and retry',
    unit: '{attempts}',
    attributes: {
      'result': result,
      'cache': cached ? 'hit' : 'miss',
      'attempt': attempt > 1 ? 'retry' : 'first',
    },
  );

  void recordNetworkLinkChange({required bool online}) => _bump(
    'happy_flutter.network.link_changes',
    description: 'Device network link availability transitions',
    unit: '{changes}',
    attributes: {'state': online ? 'available' : 'unavailable'},
  );

  void recordSocketDial({required String reason}) => _bump(
    'happy_flutter.socket.dials',
    description: 'Socket dial attempts by bounded caller reason',
    unit: '{attempts}',
    attributes: {
      'reason':
          const {
            'cold_start',
            'lifecycle_resume',
            'network_restored',
            'watchdog',
            'user_manual',
            'token_refresh',
            'zombie_detected',
            'server_url_changed',
            'library_retry',
            'unspecified',
          }.contains(reason)
          ? reason
          : 'other',
    },
  );

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
    description:
        'Messages dead-lettered after exhausting the outbox '
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

  /// Unmatched tool results discarded because a session's pending queue hit
  /// [Sync.maxPendingToolResultsPerSession].
  ///
  /// A dropped result can no longer be matched to its tool call, so the row
  /// renders without its output. This was an INFO log with no counter, which
  /// made the loss invisible to any `> 0` alert — the 2026-09-14 audit found
  /// six drops in 3.4 s on a single live session.
  void recordToolResultDropped({required int count}) => _bump(
    'happy_flutter.tool_results.dropped',
    description: 'Unmatched tool results dropped at the pending-queue cap',
    unit: '{results}',
    delta: count,
  );

  /// Server-reported terminal message drops.
  ///
  /// The server emits `{code: "message-failed", sid, localId}` from its
  /// store-failure path: the row could not be persisted, so no sequence was
  /// allocated and the client's gap recovery cannot detect it. Before
  /// 2026-09-14 the client ignored the code entirely (zero references in
  /// `lib/`), which left this class of loss invisible to the UI, to the
  /// logs, and to any alert.
  void recordServerDroppedMessage() => _bump(
    'happy_flutter.app.messaging.server_dropped',
    description: 'Server reported a message it could not persist',
    unit: '{messages}',
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

class _PendingCounter {
  _PendingCounter(
    this.name,
    this.description,
    this.unit,
    this.value,
    this.attributes,
  );

  final String name;
  final String description;
  final String unit;
  int value;
  final Map<String, String> attributes;
}
