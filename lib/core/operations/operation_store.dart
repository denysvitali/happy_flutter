/// App-local state machine for user operations that sync to a remote owner
/// (server or daemon) in the background.
///
/// An operation is recorded the moment the user asks for it and performed
/// asynchronously; screens render the record over the last authoritative
/// state, so no UI waits on the network:
///
/// ```text
/// submit ──▶ pending ──▶ succeeded ──(authoritative state confirms | TTL)──▶ gone
///                   └──▶ failed ──(retry)──▶ pending
///                               └─(dismiss)──▶ gone
/// ```
///
/// Stores are app-scoped Riverpod notifiers keyed by the operation's target,
/// so leaving a screen neither cancels an operation nor loses its outcome.
/// One operation per key is in flight; a newer submission supersedes a
/// settled record, and a late completion only applies to its own record.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show immutable, visibleForTesting;
import 'package:riverpod/riverpod.dart';

import '../services/logger_service.dart' show logger;

/// Lifecycle of one recorded operation.
enum OperationPhase { pending, succeeded, failed }

/// One recorded operation on a target, and its sync outcome.
@immutable
class Operation<R> {
  const Operation({
    required this.id,
    required this.key,
    required this.request,
    required this.phase,
    required this.submittedAtMs,
    this.settledAtMs,
    this.error,
    this.cause,
    this.result,
  });

  /// Monotonic per-store id; a completion only applies to its own record.
  final int id;

  /// Target identity, e.g. a session id.
  final String key;

  /// What was asked for; retried verbatim.
  final R request;
  final OperationPhase phase;
  final int submittedAtMs;
  final int? settledAtMs;

  /// User-presentable failure reason for [OperationPhase.failed].
  final String? error;

  /// The original failure, for callers that classify errors.
  final Object? cause;

  /// Value the remote returned with a success, if any.
  final Object? result;

  bool get isPending => phase == OperationPhase.pending;
  bool get isFailed => phase == OperationPhase.failed;
  bool get isSucceeded => phase == OperationPhase.succeeded;

  /// Whether the operation's effect should be drawn over authoritative
  /// state: while in flight and after success until confirmed. A failed
  /// operation leaves the authoritative state untouched.
  bool get overlays => !isFailed;

  Operation<R> settle(
    OperationPhase phase,
    int nowMs, {
    String? error,
    Object? cause,
    Object? result,
  }) => Operation<R>(
    id: id,
    key: key,
    request: request,
    phase: phase,
    submittedAtMs: submittedAtMs,
    settledAtMs: nowMs,
    error: error,
    cause: cause,
    result: result,
  );
}

/// Thrown by [OperationStore.perform] when the remote refused the request;
/// its [message] is shown to the user verbatim.
class OperationRejected implements Exception {
  const OperationRejected(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Base store: records operations and performs them in the background.
///
/// Subclasses name the target ([keyOf]), perform the request ([perform],
/// throwing on failure), and may apply/revert a local optimistic patch
/// ([onSubmitted], [onFailed]).
abstract class OperationStore<R> extends Notifier<Map<String, Operation<R>>> {
  /// Shared clock; override in tests.
  @visibleForTesting
  static int Function() clock = () => DateTime.now().millisecondsSinceEpoch;

  /// How long a success keeps overlaying when nothing confirms it.
  Duration get confirmationTimeout => const Duration(seconds: 60);

  /// Bounded label for logs. Never include ids or payloads.
  String get logName;

  String keyOf(R request);

  /// Performs [request] remotely. Throw (preferably [OperationRejected])
  /// on failure; the return value is kept as [Operation.result].
  Future<Object?> perform(R request);

  /// Applies a local optimistic patch when [operation] is submitted.
  void onSubmitted(Operation<R> operation) {}

  /// Reverts the optimistic patch of a failed [operation].
  void onFailed(Operation<R> operation) {}

  /// Called once [operation] succeeded.
  void onSucceeded(Operation<R> operation) {}

  int _nextId = 0;
  final Map<String, Timer> _expiry = {};
  final Map<int, Completer<Operation<R>>> _settled = {};

  @override
  Map<String, Operation<R>> build() {
    ref.onDispose(() {
      for (final timer in _expiry.values) {
        timer.cancel();
      }
      _expiry.clear();
    });
    return <String, Operation<R>>{};
  }

  /// Records [request] and performs it in the background. Returns
  /// immediately; false (and nothing happens) while an operation on the
  /// same target is still pending.
  bool submit(R request) {
    final key = keyOf(request);
    if (state[key]?.isPending ?? false) return false;
    _expiry.remove(key)?.cancel();
    final operation = Operation<R>(
      id: ++_nextId,
      key: key,
      request: request,
      phase: OperationPhase.pending,
      submittedAtMs: clock(),
    );
    state = {...state, key: operation};
    onSubmitted(operation);
    unawaited(_run(operation));
    return true;
  }

  /// Completes with the settled record of the operation currently recorded
  /// for [key] (immediately if it already settled); null if none.
  Future<Operation<R>?> whenSettled(String key) {
    final operation = state[key];
    if (operation == null) return Future.value();
    if (!operation.isPending) return Future.value(operation);
    return (_settled[operation.id] ??= Completer<Operation<R>>()).future;
  }

  /// Resubmits a failed operation with the same request.
  bool retry(String key) {
    final operation = state[key];
    if (operation == null || !operation.isFailed) return false;
    return submit(operation.request);
  }

  /// Forgets a settled operation. Pending ones cannot be dismissed: their
  /// outcome is still on its way.
  void dismiss(String key) {
    final operation = state[key];
    if (operation == null || operation.isPending) return;
    _remove(key);
  }

  /// Drops succeeded operations that [isConfirmed] by authoritative state.
  void confirmWhere(bool Function(Operation<R> operation) isConfirmed) {
    final confirmed = [
      for (final operation in state.values)
        if (operation.isSucceeded && isConfirmed(operation)) operation.key,
    ];
    if (confirmed.isEmpty) return;
    final next = Map<String, Operation<R>>.of(state);
    for (final key in confirmed) {
      next.remove(key);
      _expiry.remove(key)?.cancel();
    }
    state = next;
  }

  Future<void> _run(Operation<R> operation) async {
    Operation<R> settled;
    try {
      final result = await perform(operation.request);
      settled = operation.settle(
        OperationPhase.succeeded,
        clock(),
        result: result,
      );
    } catch (error, stack) {
      logger.warning('$logName operation failed', error, stack);
      settled = operation.settle(
        OperationPhase.failed,
        clock(),
        error: error is OperationRejected ? error.message : '$error',
        cause: error,
      );
    }
    _settled.remove(operation.id)?.complete(settled);
    if (!ref.mounted) return;
    // A newer submission or a dismissal replaced this record.
    if (state[operation.key]?.id != operation.id) return;
    state = {...state, operation.key: settled};
    if (settled.isFailed) {
      onFailed(settled);
      return;
    }
    onSucceeded(settled);
    if (state[operation.key]?.id != operation.id) return;
    _expiry[operation.key] = Timer(confirmationTimeout, () {
      _expiry.remove(operation.key);
      if (state[operation.key]?.id == operation.id) _remove(operation.key);
    });
  }

  void _remove(String key) {
    _expiry.remove(key)?.cancel();
    if (!state.containsKey(key)) return;
    state = Map<String, Operation<R>>.of(state)..remove(key);
  }
}
