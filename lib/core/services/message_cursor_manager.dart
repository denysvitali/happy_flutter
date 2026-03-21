import 'dart:math';

/// Manages per-session message sequence cursors.
///
/// Tracks the highest seq received per session (for
/// incremental delta fetches) and the lowest seq loaded
/// (for pagination/older-message detection).
///
/// Extracted from [Sync] to enable isolated testing of
/// cursor advancement and tail-load offset computation.
class MessageCursorManager {
  /// Current cursor position per session (highest seq
  /// seen). Persisted to MMKV via callbacks.
  final Map<String, int> lastSeq = {};

  /// Lowest seq loaded per session. A value of 0 means
  /// the full history has been loaded.
  final Map<String, int> firstLoadedSeq = {};

  /// Advance the cursor for [sessionId] to [newSeq].
  ///
  /// Returns `true` if the cursor was actually advanced
  /// (i.e., [newSeq] > current value). The caller should
  /// schedule a debounced persist and update session
  /// metadata when this returns `true`.
  bool advanceSeqCursor(String sessionId, int newSeq) {
    if (newSeq <= (lastSeq[sessionId] ?? 0)) return false;
    lastSeq[sessionId] = newSeq;
    return true;
  }

  /// Compute the `afterSeq` value for a tail-load or
  /// incremental fetch.
  ///
  /// - If cursor > [serverLastSeq]: returns cursor
  ///   (socket advanced past server)
  /// - If gap <= [initialLoad]: returns cursor (normal
  ///   delta path)
  /// - If gap > [initialLoad]: returns tail-load offset
  int tailAfterSeq(
    String sessionId, {
    required int serverLastSeq,
    required int initialLoad,
  }) {
    final cursorSeq = lastSeq[sessionId] ?? 0;

    if (cursorSeq > serverLastSeq) {
      return cursorSeq;
    }

    final gap = serverLastSeq - cursorSeq;
    if (gap <= initialLoad) {
      return cursorSeq;
    }

    final knownLastSeq = max(cursorSeq, serverLastSeq);
    if (knownLastSeq <= initialLoad) return 0;
    return knownLastSeq - initialLoad;
  }

  /// Remove all cursor data for [sessionId].
  void removeSession(String sessionId) {
    lastSeq.remove(sessionId);
    firstLoadedSeq.remove(sessionId);
  }

  /// Restore cursors from persisted storage.
  void restore(
    Map<String, int> lastSeqData,
    Map<String, int> firstLoadedSeqData,
  ) {
    lastSeq
      ..clear()
      ..addAll(lastSeqData);
    firstLoadedSeq
      ..clear()
      ..addAll(firstLoadedSeqData);
  }
}
