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

  /// Clear the queue for [sessionId].
  void clearSession(String sessionId) {
    _queue.remove(sessionId);
  }

  /// Clear all queues (for suspend/shutdown).
  void clear() {
    _queue.clear();
  }

  /// Whether a queue entry exists for [sessionId].
  bool contains(String sessionId) => _queue.containsKey(sessionId);

  /// The number of sessions with active queues.
  @visibleForTesting
  int get length => _queue.length;
}
