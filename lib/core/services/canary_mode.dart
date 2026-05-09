// Canary mode — runtime invariant assertions for messaging code.
//
// `kCanary` is a build-time flag (`--dart-define=kCanary=true`).
// When on, every transition in the messaging pipeline calls into
// [CanaryAssert] which logs and forwards to Sentry on violation.
// When off, the assertions are no-ops and the call sites compile to
// dead code (Dart's tree-shaker eliminates them when the flag is
// const-false).
//
// Why not `assert()`?  Because `assert()` is stripped in release
// builds — but we want the canary track to run in production
// release builds for a small fraction of users.  See
// `ROADMAP.md` "Invariant telemetry" task.

import 'package:sentry_flutter/sentry_flutter.dart';

import 'logger_service.dart';

/// Build-time canary flag.  Defaults to `false` so production builds
/// pay zero overhead.  Set via `--dart-define=kCanary=true` on the
/// canary track.
const bool kCanary = bool.fromEnvironment(
  'kCanary',
  defaultValue: false,
);

/// Runtime invariant violations get logged here.  In production
/// (canary off) the entire class compiles to a constant-false branch
/// so calls become dead code.
class CanaryAssert {
  CanaryAssert._();

  /// Total number of violations observed since process start.
  /// Exposed for diagnostics and tests.
  static int violationCount = 0;

  /// Last violation message — useful for snackbar display in dev
  /// builds.
  static String? lastViolation;

  /// Reset the counters — used by tests.
  static void reset() {
    violationCount = 0;
    lastViolation = null;
  }

  /// Generic assertion.  When [condition] is `false` the violation is
  /// logged, counted, and forwarded to Sentry.  Crucially we do NOT
  /// throw — the goal is to observe in production, not to crash a
  /// session that might still be salvageable.
  static void check(
    bool condition, {
    required String invariant,
    String? context,
    Map<String, Object?>? state,
  }) {
    if (!kCanary) return;
    if (condition) return;
    _record(invariant: invariant, context: context, state: state);
  }

  /// Specialised invariant: "one canonical LocalId" — every row in
  /// the merge output should map back to exactly one logical message.
  /// Pass the count of duplicates and the offending id.
  static void noDuplicateLocalId({
    required String localId,
    required int rowCount,
    String? sessionId,
  }) {
    if (!kCanary) return;
    if (rowCount <= 1) return;
    _record(
      invariant: 'no_duplicate_localId',
      context: 'session=$sessionId',
      state: {
        'localId': localId,
        'rowCount': rowCount,
        'sessionId': sessionId,
      },
    );
  }

  /// Specialised invariant: a server-acked message must have replaced
  /// the original optimistic placeholder.  Violations indicate the
  /// merge code lost the localId↔id mapping.
  static void ackMatchedOptimistic({
    required String localId,
    required bool optimisticFound,
    String? sessionId,
  }) {
    if (!kCanary) return;
    if (optimisticFound) return;
    _record(
      invariant: 'ack_without_optimistic',
      context: 'session=$sessionId',
      state: {
        'localId': localId,
        'sessionId': sessionId,
      },
    );
  }

  /// Specialised invariant: a retry must reuse the original [LocalId]
  /// that was minted at the first send.  Violations indicate the
  /// retry path is regenerating identifiers.
  static void retryPreservesLocalId({
    required String expected,
    required String observed,
  }) {
    if (!kCanary) return;
    if (expected == observed) return;
    _record(
      invariant: 'retry_preserves_localId',
      context: 'expected=$expected observed=$observed',
      state: {'expected': expected, 'observed': observed},
    );
  }

  static void _record({
    required String invariant,
    String? context,
    Map<String, Object?>? state,
  }) {
    violationCount++;
    final message =
        '[canary] INVARIANT VIOLATION: $invariant'
        '${context != null ? ' ($context)' : ''}';
    lastViolation = message;
    logger.warning(message);
    try {
      Sentry.captureMessage(
        message,
        level: SentryLevel.warning,
        withScope: (scope) {
          scope.setTag('canary.invariant', invariant);
          if (state != null) {
            for (final entry in state.entries) {
              final value = entry.value;
              if (value != null) {
                scope.setContexts('canary.state.${entry.key}', value);
              }
            }
          }
        },
      );
    } catch (_) {
      // Sentry failures must not interfere with the running session;
      // the local log entry above is the primary record.
    }
  }
}
