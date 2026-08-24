// Messaging invariant telemetry — a live runtime guard that observes the
// chat-send contract in production.
//
// The repo already PROVES these invariants in CI (see
// `test/fsm/message_state_machine_contract_test.dart` and the
// optimistic-replacement / retry-identity integration tests). This is the
// runtime counterpart: the same assertions lifted into a non-crashing tap
// that increments counters, emits one `logger.warning` breadcrumb, bumps an
// OTel counter, and forwards a typed exception to Sentry — rate-limited per
// session so a repeatedly-violating session does not spam the issue tracker.
//
// Unlike `CanaryAssert` (gated behind the build-time `kCanary` flag and
// compiled to dead code in production), this monitor runs unconditionally.
// It is intentionally cheap: a handful of set lookups and integer bumps on
// the send/merge path. It NEVER throws — observing must not crash a send.
//
// See `ROADMAP.md` "Invariant telemetry" task.

import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../services/logger_service.dart';
import '../services/opentelemetry_service.dart';
import '../services/power_diagnostics_otel_reporter.dart';

/// The four messaging invariants this monitor watches.
enum MessageInvariant {
  /// A server ack arrived for a `localId` with no optimistic placeholder.
  unmatchedOptimistic('unmatched_optimistic'),

  /// Two distinct logical messages share the same `localId`.
  duplicateLocalId('duplicate_local_id'),

  /// An ack references a `localId` the client never sent.
  unknownAckedLocalId('unknown_acked_local_id'),

  /// A retry produced a second logical message instead of preserving
  /// identity (either the `localId` changed, or a duplicate row appeared).
  retryCreatedDuplicate('retry_created_duplicate');

  const MessageInvariant(this.tag);

  /// Stable snake_case tag used for counters and the Sentry `invariant`
  /// tag. Kept identical to the names listed in ROADMAP.md.
  final String tag;
}

/// Typed exception forwarded to Sentry when an invariant is violated.
/// Carries the invariant kind and the offending identifiers so the issue
/// can be triaged without a full breadcrumb trail.
class MessageInvariantViolation implements Exception {
  const MessageInvariantViolation(
    this.invariant, {
    required this.localId,
    this.sessionId,
    this.detail,
  });

  final MessageInvariant invariant;
  final String localId;
  final String? sessionId;
  final String? detail;

  @override
  String toString() {
    final buffer = StringBuffer('MessageInvariantViolation(')
      ..write(invariant.tag)
      ..write(' localId=')
      ..write(localId);
    if (sessionId != null) {
      buffer
        ..write(' session=')
        ..write(sessionId);
    }
    if (detail != null) {
      buffer
        ..write(' detail=')
        ..write(detail);
    }
    buffer.write(')');
    return buffer.toString();
  }
}

/// Observes the chat-send contract at runtime. One instance lives on the
/// `Sync` singleton. Pure observation — call the `record*` methods from the
/// existing merge / ack / retry path without changing any send behavior.
class MessageInvariantMonitor {
  MessageInvariantMonitor({
    CaptureException? captureException,
    RecordInvariantCounter? recordCounter,
    RecordSendDuration? recordSendDuration,
  }) : _captureException = captureException ?? _defaultCapture,
       _recordCounter = recordCounter ?? _defaultRecordCounter,
       _recordSendDuration = recordSendDuration ?? _defaultRecordSendDuration {
    // Prime all four violation counters to zero (audit 2026-08-03: lazy
    // counter creation meant the three invariants that never fired had
    // no Prometheus series at all, so "no breaches" was indistinguishable
    // from "metric missing" and `> 0` alerting was impossible).
    for (final invariant in MessageInvariant.values) {
      _recordCounter(invariant, prime: true);
    }
  }

  /// Injectable Sentry capture for tests (avoids a live Sentry hub).
  final CaptureException _captureException;

  /// Injectable OTel counter hook for tests.
  final RecordInvariantCounter _recordCounter;

  /// Injectable tap→ack duration sink for tests.
  final RecordSendDuration _recordSendDuration;

  static Future<void> _defaultCapture(
    Object error, {
    required MessageInvariant invariant,
    String? sessionId,
    String? localId,
    String? detail,
  }) async {
    await Sentry.captureException(
      error,
      withScope: (scope) {
        scope.setTag('invariant', invariant.tag);
        if (sessionId != null) {
          scope.setTag('invariant_session', sessionId);
        }
        if (localId != null) {
          scope.setTag('invariant_local_id', localId);
        }
        if (detail != null) {
          scope.setContexts('invariant_detail', detail);
        }
      },
    );
  }

  static void _defaultRecordCounter(
    MessageInvariant invariant, {
    bool prime = false,
  }) {
    PowerDiagnosticsOtelReporter.instance.recordMessagingInvariant(
      invariant.tag,
      delta: prime ? 0 : 1,
    );
  }

  static void _defaultRecordSendDuration(
    Duration elapsed, {
    required String outcome,
  }) {
    OpenTelemetryService().recordDuration(
      'app.message_send',
      elapsed,
      attributes: {'outcome': outcome},
      description: 'User-perceived message send latency (tap to ack)',
    );
  }

  /// Upper bound for the id-tracking sets below. They are seeded with EVERY
  /// observed message id (cache restore, history fetch, socket delivery),
  /// so without a cap they grow monotonically with all traffic for the
  /// whole process lifetime — tens of thousands of retained strings on the
  /// Sync singleton after a heavy day (progressive-lag audit 2026-08-24).
  /// Mirrors `Sync._maxRecentInlineKeys`. Trade-off: an ack arriving for an
  /// id evicted 10k additions ago reads as `unknown_acked_local_id`; live
  /// sends ack within seconds, so only ancient ids are ever evicted.
  static const int _maxTrackedLocalIds = 10000;

  /// LocalIds the client has minted via the optimistic insert — in THIS
  /// process or an earlier one (seeded from persisted rows on restore /
  /// fetch, see [seedSentLocalId]). Used to tell an "unknown acked" id
  /// (never sent) from an "unmatched optimistic" one (sent, but the
  /// placeholder row went missing before the ack). Bounded FIFO.
  final Set<String> _sentLocalIds = <String>{};
  final Queue<String> _sentLocalIdOrder = Queue<String>();

  /// Mint timestamps (epoch ms) for ids sent in THIS process, keyed by
  /// localId. Powers the `app.message_send` tap→ack histogram. Seeded ids
  /// from older lifetimes carry no timestamp and skip the sample. Drained
  /// per ack; bounded FIFO for sends that never get one.
  final Map<String, int> _sentAtMs = <String, int>{};

  /// LocalIds whose ack has already been observed this process. The
  /// REST-ack path and the send-status path both tap the same server ack;
  /// without this set every ack double-counted (audit 2026-08-03).
  /// Bounded FIFO: re-processing an ack after eviction would re-bump the
  /// ack denominator, which needs 10k newer acks to reach — accepted over
  /// unbounded growth.
  final Set<String> _ackedLocalIds = <String>{};
  final Queue<String> _ackedLocalIdOrder = Queue<String>();

  /// Per-invariant violation counts since process start.
  final Map<MessageInvariant, int> _counts = <MessageInvariant, int>{
    for (final i in MessageInvariant.values) i: 0,
  };

  /// Rate-limit key: `invariant.tag:sessionId`. Once a violation of a given
  /// kind has been captured for a session, further captures for that pair
  /// are suppressed (counters still increment). Mirrors the existing
  /// `dek_fallback_session` once-per-session pattern.
  final Set<String> _capturedKeys = <String>{};

  /// Read-only snapshot of per-invariant counters, keyed by stable tag.
  /// Exposed for future surfacing (dev tools / diagnostics). No UI required.
  Map<String, int> get counters => <String, int>{
    for (final entry in _counts.entries) entry.key.tag: entry.value,
  };

  /// Total violations across all invariant kinds.
  int get totalViolations =>
      _counts.values.fold(0, (sum, count) => sum + count);

  /// Clears all state — used by tests.
  void reset() {
    _sentLocalIds.clear();
    _sentLocalIdOrder.clear();
    _sentAtMs.clear();
    _ackedLocalIds.clear();
    _ackedLocalIdOrder.clear();
    _capturedKeys.clear();
    for (final key in _counts.keys.toList()) {
      _counts[key] = 0;
    }
  }

  /// Bounded FIFO insert shared by the id-tracking sets: Set gives O(1)
  /// membership, Queue gives O(1) oldest eviction (same shape as
  /// `Sync._recentInlineMessageKeys`).
  void _addBounded(Set<String> set, Queue<String> order, String id) {
    if (!set.add(id)) return;
    order.addLast(id);
    while (order.length > _maxTrackedLocalIds) {
      set.remove(order.removeFirst());
    }
  }

  /// Number of tracked sent ids — exposed for tests pinning the bound.
  @visibleForTesting
  int get trackedSentLocalIdCount => _sentLocalIds.length;

  /// Number of tracked acked ids — exposed for tests pinning the bound.
  @visibleForTesting
  int get trackedAckedLocalIdCount => _ackedLocalIds.length;

  /// Record that the client minted [localId] for an optimistic send. Call
  /// from the optimistic insert in `sendMessage`. Records zero violations on
  /// the happy path.
  void recordOptimisticSent(String localId) {
    if (localId.isEmpty) return;
    _addBounded(_sentLocalIds, _sentLocalIdOrder, localId);
    _sentAtMs[localId] = DateTime.now().millisecondsSinceEpoch;
    // Sends that never get an ack (permanent failures) would otherwise
    // pin their timestamps forever; FIFO-drain the oldest.
    while (_sentAtMs.length > _maxTrackedLocalIds) {
      _sentAtMs.remove(_sentAtMs.keys.first);
    }
    PowerDiagnosticsOtelReporter.instance.recordMessageSend();
  }

  /// Seed a [localId] minted in an EARLIER process lifetime, recovered
  /// from a persisted row (MMKV cache restore, history fetch, socket
  /// delivery). Without this every app restart re-delivering an acked
  /// row read as an `unknown_acked_local_id` violation — the audit's
  /// false positive. Seeded ids carry no mint timestamp, so they never
  /// contribute a latency sample.
  void seedSentLocalId(String localId) {
    if (localId.isEmpty) return;
    _addBounded(_sentLocalIds, _sentLocalIdOrder, localId);
  }

  /// Record a server ack for [localId]. [optimisticRowCount] is the number
  /// of in-memory rows currently matching the id (from the merge output).
  ///
  /// Detects three invariants in one pass:
  /// - duplicate `localId` when [optimisticRowCount] > 1
  /// - unknown acked `localId` when the id was never minted locally
  /// - unmatched optimistic when a minted id has zero matching rows
  ///
  /// Observed at most once per [localId] per process: both the REST-ack
  /// path and the send-status path tap the same server ack.
  void recordAck({
    required String localId,
    required int optimisticRowCount,
    String? sessionId,
  }) {
    if (localId.isEmpty) return;
    final firstAckForId = _ackedLocalIds.add(localId);
    if (!firstAckForId) return;
    _ackedLocalIdOrder.addLast(localId);
    while (_ackedLocalIdOrder.length > _maxTrackedLocalIds) {
      _ackedLocalIds.remove(_ackedLocalIdOrder.removeFirst());
    }
    PowerDiagnosticsOtelReporter.instance.recordMessageAck();

    final wasSent = _sentLocalIds.contains(localId);
    final String outcome;

    if (optimisticRowCount > 1) {
      outcome = MessageInvariant.duplicateLocalId.tag;
      _violation(
        MessageInvariant.duplicateLocalId,
        localId: localId,
        sessionId: sessionId,
        detail: 'rowCount=$optimisticRowCount',
      );
    } else if (!wasSent) {
      outcome = MessageInvariant.unknownAckedLocalId.tag;
      _violation(
        MessageInvariant.unknownAckedLocalId,
        localId: localId,
        sessionId: sessionId,
        detail: 'rowCount=$optimisticRowCount',
      );
    } else if (optimisticRowCount == 0) {
      outcome = MessageInvariant.unmatchedOptimistic.tag;
      _violation(
        MessageInvariant.unmatchedOptimistic,
        localId: localId,
        sessionId: sessionId,
      );
    } else {
      outcome = 'ok';
    }

    // Tap→ack latency (`app.message_send`, audit 2026-08-03). Only ids
    // minted in this process have a mint timestamp.
    final sentAtMs = _sentAtMs.remove(localId);
    if (sentAtMs != null) {
      final elapsedMs = DateTime.now().millisecondsSinceEpoch - sentAtMs;
      if (elapsedMs >= 0) {
        _recordSendDuration(
          Duration(milliseconds: elapsedMs),
          outcome: outcome,
        );
      }
    }
  }

  /// Record a retry. [expected] is the original minted id; [observed] is the
  /// id carried by the retried row. [rowCount] is the number of rows
  /// matching [expected] after the retry was queued. A changed id OR a
  /// duplicate row means the retry minted a second logical message instead
  /// of preserving identity.
  void recordRetry({
    required String expected,
    required String observed,
    required int rowCount,
    String? sessionId,
  }) {
    if (expected.isEmpty) return;
    if (observed != expected) {
      _violation(
        MessageInvariant.retryCreatedDuplicate,
        localId: expected,
        sessionId: sessionId,
        detail: 'observed=$observed',
      );
      return;
    }
    if (rowCount > 1) {
      _violation(
        MessageInvariant.retryCreatedDuplicate,
        localId: expected,
        sessionId: sessionId,
        detail: 'rowCount=$rowCount',
      );
    }
  }

  void _violation(
    MessageInvariant invariant, {
    required String localId,
    String? sessionId,
    String? detail,
  }) {
    _counts[invariant] = (_counts[invariant] ?? 0) + 1;
    _recordCounter(invariant, prime: false);

    final message =
        '[invariant] VIOLATION ${invariant.tag} localId=$localId'
        '${sessionId != null ? ' session=$sessionId' : ''}'
        '${detail != null ? ' $detail' : ''}';
    logger.warning(message);

    // Rate-limit Sentry captures per (invariant, session) pair.
    final key = '${invariant.tag}:${sessionId ?? '-'}';
    if (!_capturedKeys.add(key)) return;

    final violation = MessageInvariantViolation(
      invariant,
      localId: localId,
      sessionId: sessionId,
      detail: detail,
    );
    // Fire-and-forget. Sentry failures must never disturb the send path.
    unawaited(
      _captureException(
        violation,
        invariant: invariant,
        sessionId: sessionId,
        localId: localId,
        detail: detail,
      ).catchError((Object _) {}),
    );
  }
}

/// Signature for the injectable Sentry capture hook.
typedef CaptureException =
    Future<void> Function(
      Object error, {
      required MessageInvariant invariant,
      String? sessionId,
      String? localId,
      String? detail,
    });

/// Signature for the injectable OTel counter hook. [prime] is true when
/// the monitor is creating the series at zero during construction — test
/// fakes should usually ignore primed (delta-0) bumps.
typedef RecordInvariantCounter =
    void Function(MessageInvariant invariant, {bool prime});

/// Signature for the injectable tap→ack duration sink. [outcome] is `ok`
/// on the happy path or the violated invariant's tag.
typedef RecordSendDuration =
    void Function(Duration elapsed, {required String outcome});
