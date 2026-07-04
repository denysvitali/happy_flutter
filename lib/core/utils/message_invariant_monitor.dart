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

import 'package:sentry_flutter/sentry_flutter.dart';

import '../services/logger_service.dart';
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
  }) : _captureException = captureException ?? _defaultCapture,
       _recordCounter = recordCounter ?? _defaultRecordCounter;

  /// Injectable Sentry capture for tests (avoids a live Sentry hub).
  final CaptureException _captureException;

  /// Injectable OTel counter hook for tests.
  final RecordInvariantCounter _recordCounter;

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

  static void _defaultRecordCounter(MessageInvariant invariant) {
    PowerDiagnosticsOtelReporter.instance.recordAppError(
      'app.messaging.invariant.${invariant.tag}',
    );
  }

  /// LocalIds the client has minted via the optimistic insert. Used to tell
  /// an "unknown acked" id (never sent) from an "unmatched optimistic" one
  /// (sent, but the placeholder row went missing before the ack).
  final Set<String> _sentLocalIds = <String>{};

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
    _capturedKeys.clear();
    for (final key in _counts.keys.toList()) {
      _counts[key] = 0;
    }
  }

  /// Record that the client minted [localId] for an optimistic send. Call
  /// from the optimistic insert in `sendMessage`. Records zero violations on
  /// the happy path.
  void recordOptimisticSent(String localId) {
    if (localId.isEmpty) return;
    _sentLocalIds.add(localId);
  }

  /// Record a server ack for [localId]. [optimisticRowCount] is the number
  /// of in-memory rows currently matching the id (from the merge output).
  ///
  /// Detects three invariants in one pass:
  /// - duplicate `localId` when [optimisticRowCount] > 1
  /// - unknown acked `localId` when the id was never minted locally
  /// - unmatched optimistic when a minted id has zero matching rows
  void recordAck({
    required String localId,
    required int optimisticRowCount,
    String? sessionId,
  }) {
    if (localId.isEmpty) return;
    final wasSent = _sentLocalIds.contains(localId);

    if (optimisticRowCount > 1) {
      _violation(
        MessageInvariant.duplicateLocalId,
        localId: localId,
        sessionId: sessionId,
        detail: 'rowCount=$optimisticRowCount',
      );
      return;
    }

    if (!wasSent) {
      _violation(
        MessageInvariant.unknownAckedLocalId,
        localId: localId,
        sessionId: sessionId,
        detail: 'rowCount=$optimisticRowCount',
      );
      return;
    }

    if (optimisticRowCount == 0) {
      _violation(
        MessageInvariant.unmatchedOptimistic,
        localId: localId,
        sessionId: sessionId,
      );
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
    _recordCounter(invariant);

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

/// Signature for the injectable OTel counter hook.
typedef RecordInvariantCounter = void Function(MessageInvariant invariant);
