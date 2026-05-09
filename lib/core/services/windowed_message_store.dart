// Windowed message store with keyset pagination.
//
// Targets the `fetchMessages p95 = 54s` outlier from `ROADMAP.md` —
// a handful of sessions have message histories so large that the
// existing whole-page fetch + in-memory list mutate is the bottleneck.
//
// Design:
//
//   - Bounded ~500-message window kept in memory per visible session.
//   - Older messages are paged in via a `(timestamp, id)` cursor —
//     the standard keyset-pagination pattern.  Avoids OFFSET-based
//     scans and survives concurrent writes.
//   - A future SQLite backend can persist the full history; the
//     in-memory window stays the same shape so the UI layer never
//     observes the swap.
//
// Status: scaffold + paginated fetcher only — NOT integrated into
// `ChatScreen`.  Integration is intentionally deferred so the
// architecture branch (also rewriting `_sync_messaging*`) doesn't
// conflict with this work.

import 'dart:collection';

/// Composite cursor used for keyset pagination.  Two messages are
/// ordered first by [timestampMs] then by [id] (lexicographic) so we
/// have a deterministic tiebreaker when many messages share a
/// millisecond.
class MessageCursor implements Comparable<MessageCursor> {
  const MessageCursor({required this.timestampMs, required this.id});

  /// Sentinel for "before any message".  Useful when the window is
  /// empty and we need to ask the server for the first page.
  static const MessageCursor zero = MessageCursor(
    timestampMs: 0,
    id: '',
  );

  final int timestampMs;
  final String id;

  @override
  int compareTo(MessageCursor other) {
    final byTs = timestampMs.compareTo(other.timestampMs);
    if (byTs != 0) return byTs;
    return id.compareTo(other.id);
  }

  bool operator <(MessageCursor other) => compareTo(other) < 0;
  bool operator >(MessageCursor other) => compareTo(other) > 0;
  bool operator <=(MessageCursor other) => compareTo(other) <= 0;
  bool operator >=(MessageCursor other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is MessageCursor &&
      other.timestampMs == timestampMs &&
      other.id == id;

  @override
  int get hashCode => Object.hash(timestampMs, id);

  @override
  String toString() => 'MessageCursor($timestampMs, $id)';
}

/// Minimal shape used by [WindowedMessageStore].  Mirrors the keys
/// already present in the loose `Map<String, dynamic>` rows used by
/// `_sync_messaging*`.
class WindowedMessage {
  const WindowedMessage({
    required this.id,
    required this.localId,
    required this.timestampMs,
    required this.raw,
  });

  factory WindowedMessage.fromMap(Map<String, dynamic> map) {
    return WindowedMessage(
      id: (map['id'] as String?) ?? '',
      localId: (map['localId'] as String?) ?? '',
      timestampMs: _readTs(map),
      raw: map,
    );
  }

  static int _readTs(Map<String, dynamic> map) {
    final raw = map['createdAt'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  final String id;
  final String localId;
  final int timestampMs;
  final Map<String, dynamic> raw;

  MessageCursor get cursor =>
      MessageCursor(timestampMs: timestampMs, id: id);
}

/// In-memory ring buffer of recent messages keyed by cursor.
///
/// Two operations dominate the chat UX:
///
///   1. Append the next message at the tail (live socket arrivals).
///   2. Prepend a page of older messages at the head (paginate up).
///
/// We use a plain `List<WindowedMessage>` ordered ascending by cursor
/// because the typical window size (≤ 500) makes the list operations
/// trivial.  When the SQLite backend lands, this class becomes the
/// hot read-path cache and the list operations remain the same.
class WindowedMessageStore {
  WindowedMessageStore({this.windowSize = 500});

  final int windowSize;
  final List<WindowedMessage> _window = [];

  /// Read-only window, ascending by cursor.
  UnmodifiableListView<WindowedMessage> get window =>
      UnmodifiableListView(_window);

  /// Lowest cursor currently held — `null` if the window is empty.
  /// Use this as the `before` argument when paginating older messages.
  MessageCursor? get oldestCursor =>
      _window.isEmpty ? null : _window.first.cursor;

  /// Highest cursor currently held — `null` if the window is empty.
  MessageCursor? get newestCursor =>
      _window.isEmpty ? null : _window.last.cursor;

  bool get isEmpty => _window.isEmpty;

  int get length => _window.length;

  /// Insert or update a single message.  De-duplicates by `id`;
  /// preserves cursor order.  Trims the window from the *head* if
  /// it grew past [windowSize] — newer messages always win in the
  /// default insertion mode.  Use [prependOlder] when scrolling up.
  void upsert(WindowedMessage message) {
    _upsertInternal(message);
    _trimFromHead();
  }

  void _upsertInternal(WindowedMessage message) {
    final existing = _window.indexWhere((m) => m.id == message.id);
    if (existing >= 0) {
      _window[existing] = message;
      return;
    }
    // Binary-insert keeps the list sorted.
    var lo = 0;
    var hi = _window.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_window[mid].cursor < message.cursor) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    _window.insert(lo, message);
  }

  /// Append a batch of newer messages and trim to the window size,
  /// dropping older entries.
  void appendNewer(Iterable<WindowedMessage> messages) {
    for (final m in messages) {
      upsert(m);
    }
  }

  /// Prepend a batch of older messages.  If this would push the
  /// window past [windowSize] we drop the newest entries (because the
  /// user is scrolling up — they care about the older ones first).
  void prependOlder(Iterable<WindowedMessage> messages) {
    for (final m in messages) {
      _upsertInternal(m);
    }
    // Trim from the *tail* so the user keeps the older messages they
    // just paginated to.  Mirrors what happens visually when the user
    // scrolls up: keep what's near the top of the viewport.
    if (_window.length > windowSize) {
      _window.removeRange(windowSize, _window.length);
    }
  }

  void _trimFromHead() {
    if (_window.length <= windowSize) return;
    // Drop oldest entries — the chat UI prioritises the freshest
    // messages.  This mirrors the existing `Sync._maxVisibleSessionMessages`
    // semantics.
    _window.removeRange(0, _window.length - windowSize);
  }

  void clear() => _window.clear();
}

/// Fetcher contract for paging older messages from the server.  The
/// implementation lives in tests for now; the real one will wrap
/// the existing `MessagesApi.fetch...` calls once integration lands.
typedef WindowedMessageFetcher = Future<List<WindowedMessage>> Function({
  required MessageCursor before,
  required int limit,
});

/// Glue that drives [WindowedMessageStore.prependOlder] from a
/// fetcher.  Encapsulates the cursor advance so the screen layer
/// never has to deal with raw timestamps.
class PaginatedMessageLoader {
  PaginatedMessageLoader({
    required this.store,
    required this.fetcher,
    this.pageSize = 50,
  });

  final WindowedMessageStore store;
  final WindowedMessageFetcher fetcher;
  final int pageSize;

  bool _exhausted = false;
  bool _inFlight = false;

  bool get hasMore => !_exhausted;
  bool get isLoading => _inFlight;

  /// Load the next page of older messages.  Returns the number of new
  /// messages prepended (0 if exhausted or in-flight).
  Future<int> loadOlder() async {
    if (_exhausted || _inFlight) return 0;
    _inFlight = true;
    try {
      final before = store.oldestCursor ?? MessageCursor.zero;
      final page = await fetcher(before: before, limit: pageSize);
      if (page.isEmpty || page.length < pageSize) {
        _exhausted = page.isEmpty || page.length < pageSize;
      }
      store.prependOlder(page);
      return page.length;
    } finally {
      _inFlight = false;
    }
  }
}
