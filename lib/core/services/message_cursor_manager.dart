import 'dart:math';

/// The fetch window `fetchMessages` should ask the server for.
///
/// Produced by [MessageCursorManager.computeFetchWindow], which is pure: it
/// decides, and the caller applies. Nothing here touches storage, the network
/// or `Sync`'s in-memory maps.
class MessageFetchWindow {
  const MessageFetchWindow({
    required this.afterSeq,
    required this.useTailLoad,
    required this.isGapRecovery,
    this.firstLoadedSeq,
  });

  /// Value for the request's `after_seq`: the server returns messages with
  /// `seq > afterSeq`.
  final int afterSeq;

  /// True when the window was computed from the end of the history rather
  /// than continued from the cursor.
  final bool useTailLoad;

  /// True when this tail load exists to repair a gap (a forced refresh or
  /// cached messages whose image data was stripped) rather than to open a
  /// session for the first time. The caller uses it to decide whether the
  /// first page needs merging into existing messages.
  final bool isGapRecovery;

  /// The seq the caller should record as "oldest loaded" for this session, or
  /// null when this fetch is not a first load and so must not touch it.
  ///
  /// 0 means the whole history will be loaded, so there are no older messages
  /// to page back to.
  final int? firstLoadedSeq;
}

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

  /// Decide which window of messages a `fetchMessages` cycle should request.
  ///
  /// A tail jump is only safe when there is no usable in-memory prefix: with
  /// cached messages, even an explicit refresh must continue from their cursor
  /// or merging the tail would leave a missing middle.
  ///
  /// [strippedImageAfterSeq], when non-null, pins the window so cached
  /// messages whose image payloads were dropped get re-fetched.
  ///
  /// Pure — see [MessageFetchWindow]. The caller owns the logging, the
  /// `firstLoadedSeq` write and its persistence.
  MessageFetchWindow computeFetchWindow(
    String sessionId, {
    required bool isFirstLoad,
    required bool forceTailRefresh,
    required bool hasStrippedImages,
    required int cursorSeq,
    required int serverLastSeq,
    required int? strippedImageAfterSeq,
    required int initialLoad,
  }) {
    final useTailLoad =
        isFirstLoad ||
        hasStrippedImages ||
        (forceTailRefresh && cursorSeq <= 0);
    final isGapRecovery =
        (forceTailRefresh || hasStrippedImages) && useTailLoad;

    if (!useTailLoad) {
      return MessageFetchWindow(
        // No cursor established yet — use the server's hint.
        afterSeq: cursorSeq == 0
            ? tailAfterSeq(
                sessionId,
                serverLastSeq: serverLastSeq,
                initialLoad: initialLoad,
              )
            : cursorSeq,
        useTailLoad: false,
        isGapRecovery: isGapRecovery,
      );
    }

    // Lazy tail-load: start near the end of the session history so we don't
    // download thousands of messages the UI will never show. For a first load
    // or a tail refresh the window comes from the known max seq, ignoring the
    // cursor.
    final knownMax = max(cursorSeq, serverLastSeq);
    var afterSeq = knownMax <= initialLoad ? 0 : knownMax - initialLoad;
    // after_seq=N returns messages with seq > N, so small non-zero values
    // (1-10) would skip the very first message(s) of the conversation. Round
    // down to 0 when the window barely exceeds initialLoad, so the first
    // message is always included in the initial fetch.
    if (afterSeq > 0 && afterSeq <= 10) {
      afterSeq = 0;
    }
    if (strippedImageAfterSeq != null) {
      afterSeq = strippedImageAfterSeq;
    }

    return MessageFetchWindow(
      afterSeq: afterSeq,
      useTailLoad: true,
      isGapRecovery: isGapRecovery,
      // Record where we started so the UI can offer "load older" later; 0
      // means the session is short enough that everything will be loaded.
      firstLoadedSeq: isFirstLoad ? (afterSeq > 0 ? afterSeq + 1 : 0) : null,
    );
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
