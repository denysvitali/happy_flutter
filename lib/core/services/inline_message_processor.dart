import 'dart:async';

import 'package:flutter/foundation.dart';

/// Per-session serial queue for inline message processing.
///
/// Sidechain messages form a linked list via `parentUuid`.
/// If two messages decrypt concurrently and the second
/// finishes first, the grouping logic can't find the parent
/// chain and the message stays orphaned. Serialising
/// processing per session guarantees messages are upserted
/// and grouped in arrival order.
class InlineMessageProcessor {
  final Map<String, Future<void>> _queue = {};

  /// Coalescing buffers for [enqueueBatch], keyed by sessionId. Items
  /// accumulate here while a batch drain is scheduled or running; each
  /// drain swaps out the whole list so mid-drain arrivals are picked up
  /// by the next iteration instead of racing the current batch.
  final Map<String, List<Object>> _batches = {};

  /// Sessions with a batch drain scheduled or running. Guard against two
  /// concurrent drains for one session. Removed synchronously together
  /// with the final empty-buffer check so an enqueue can never fall into
  /// a gap between "drain decided to stop" and "drain deregistered".
  final Set<String> _activeBatches = {};

  /// Enqueue a processing task for [sessionId].
  ///
  /// If there is already a pending task for this session,
  /// the new task will execute after the current one
  /// completes (serial chaining). Cross-session tasks
  /// execute concurrently.
  void enqueue(String sessionId, Future<void> Function() process) {
    final previous = _queue[sessionId];
    // Wrap in a try-catch so a failed task doesn't break
    // the chain and block subsequent tasks.
    Future<void> safeProcess() async {
      try {
        await process();
      } catch (_) {
        // Caller is responsible for error handling.
      }
    }

    late final Future<void> current;
    current = (previous ?? Future<void>.value())
        .then((_) => safeProcess())
        .whenComplete(() {
          if (identical(_queue[sessionId], current)) {
            _queue.remove(sessionId);
          }
        });
    _queue[sessionId] = current;
  }

  /// Enqueue [item] into the coalescing batch for [sessionId].
  ///
  /// All items buffered for the session are delivered to [process] in
  /// arrival order as ONE list per drain. A burst enqueued within one
  /// event-loop turn produces exactly one [process] invocation; items
  /// arriving while a drain is awaiting [process] are consumed by the
  /// same drain's follow-up iterations (never concurrently), so FIFO
  /// order and exactly-once delivery hold under any interleaving.
  /// Cross-session batches run concurrently.
  void enqueueBatch<T>(
    String sessionId,
    T item,
    Future<void> Function(List<T> items) process,
  ) {
    (_batches[sessionId] ??= <Object>[]).add(item as Object);
    if (!_activeBatches.add(sessionId)) {
      return; // A drain is scheduled or running and will pick this up.
    }
    scheduleMicrotask(() {
      unawaited(_runBatchDrain(sessionId, process));
    });
  }

  Future<void> _runBatchDrain<T>(
    String sessionId,
    Future<void> Function(List<T> items) process,
  ) async {
    try {
      while (true) {
        final pending = _batches.remove(sessionId);
        if (pending == null || pending.isEmpty) break;
        try {
          await process(pending.cast<T>());
        } catch (_) {
          // Caller owns error handling; keep draining later waves.
        }
        // Loop again so arrivals during `process` join this drain rather
        // than racing a second concurrent one.
      }
    } finally {
      _activeBatches.remove(sessionId);
    }
  }

  /// Clear the queue for [sessionId].
  ///
  /// Buffered-but-unstarted batch items are discarded (a deleted or
  /// re-opened session re-fetches them authoritatively); an in-flight
  /// batch still finishes, but finds nothing further queued.
  void clearSession(String sessionId) {
    _queue.remove(sessionId);
    _batches.remove(sessionId);
  }

  /// Clear all queues (for suspend/shutdown).
  void clear() {
    _queue.clear();
    _batches.clear();
  }

  /// Whether a queue entry exists for [sessionId].
  bool contains(String sessionId) =>
      _queue.containsKey(sessionId) || _batches.containsKey(sessionId);

  /// The number of sessions with active queues.
  @visibleForTesting
  int get length => _queue.length;
}
