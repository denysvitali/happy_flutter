/// EXPERIMENTAL — NOT WIRED TO PRODUCTION.
///
/// Everything in this file is a design spike for a future append-only
/// replacement of [MessageOutbox]. As of this writing:
///
/// * [kUseSqliteOutbox] defaults to `false` and nothing reads it,
/// * the `sqlite3` package is **not** a dependency of this app, so there
///   is no SQLite-backed [OutboxStore] — [InMemoryOutboxStore] is the
///   only implementation and it does not survive a process restart,
/// * [SqliteMessageOutbox] has zero production call sites; the live
///   singleton is `messageOutbox` in `message_outbox.dart`,
/// * it does **not** carry the dead-letter bucket that
///   [MessageOutbox] uses to stop exhausted entries destroying the
///   user's only copy of a message.
///
/// Do not "prefer it for new code". The MMKV [MessageOutbox] is the
/// production outbox. Keep this file only as the reference fold/replay
/// design (covered by `test/services/message_outbox_sqlite_test.dart`);
/// any adoption has to add the `sqlite3` dependency, a real
/// [OutboxStore], and dead-letter parity first.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../wire/wire_parsers.dart';
import 'logger_service.dart';
import 'message_outbox.dart'
    show
        OutboxDeliverFn,
        OutboxDeliveryFailure,
        OutboxEntry,
        OutboxFailureClass,
        OutboxStatusChangedFn;

/// Build flag controlling adoption of the SQLite-backed outbox.
///
/// EXPERIMENTAL: nothing reads this flag today. See the library-level
/// doc above before wiring it up.
const bool kUseSqliteOutbox = bool.fromEnvironment(
  'kUseSqliteOutbox',
  defaultValue: false,
);

/// Append-only event log for the message outbox.
///
/// Why a log instead of the existing whole-list reserialize?
///
/// `MessageOutbox._persist` (line ~344 of `message_outbox.dart`)
/// JSON-encodes the *entire* `_entries` map on every change.  For
/// 100-message outboxes (rare, but happens when the user is offline
/// for hours) that's a ~50KB MMKV write per status change.  Worse,
/// a crash mid-write can corrupt the whole file.
///
/// An append-only log writes one row per state transition.  On
/// restore we fold the log to compute the current outbox.  In WAL
/// mode, partial writes are recovered by SQLite itself and never
/// expose a torn record.
///
/// Schema (kept tiny on purpose — easy to migrate or rebuild):
///
/// ```sql
/// CREATE TABLE outbox_events (
///   seq         INTEGER PRIMARY KEY AUTOINCREMENT,
///   ts_ms       INTEGER NOT NULL,
///   local_id    TEXT NOT NULL,
///   session_id  TEXT NOT NULL,
///   kind        TEXT NOT NULL,
///                              -- 'add'|'retry'|'sent'|'failed'
///   payload     TEXT                     -- JSON, only for 'add'
/// );
/// CREATE INDEX outbox_events_local_id ON outbox_events(local_id);
/// ```
///
/// `kind` is a discriminator for the event variant.  `'add'` carries
/// the full [OutboxEntry] payload as JSON; the other kinds reference
/// a previously-added row by `local_id` and only need the new
/// `retry_count` (encoded as an integer in `payload`).
abstract class OutboxStore {
  Future<void> open();
  Future<int> appendAdd(OutboxEntry entry);
  Future<int> appendRetry(String localId, int retryCount);
  Future<int> appendSent(String localId);
  Future<int> appendFailed(String localId);
  Future<List<OutboxEvent>> readAll();
  Future<void> close();
}

/// One row in the append-only outbox event log.
class OutboxEvent {
  OutboxEvent({
    required this.seq,
    required this.tsMs,
    required this.localId,
    required this.sessionId,
    required this.kind,
    this.payload,
  });

  final int seq;
  final int tsMs;
  final String localId;
  final String sessionId;
  final String kind;
  final Map<String, dynamic>? payload;
}

/// In-memory implementation of [OutboxStore].  Used in tests and as a
/// stand-in until the `sqlite3` package is added to `pubspec.yaml`
/// (deferred to coordinate with the architecture branch).  The fold
/// logic and public API are identical to the eventual SQLite
/// implementation, so swapping in a real driver is a one-file change.
class InMemoryOutboxStore implements OutboxStore {
  final List<OutboxEvent> _events = [];
  int _nextSeq = 1;

  @override
  Future<void> open() async {}

  @override
  Future<int> appendAdd(OutboxEntry entry) async {
    final event = OutboxEvent(
      seq: _nextSeq++,
      tsMs: DateTime.now().millisecondsSinceEpoch,
      localId: entry.localId,
      sessionId: entry.sessionId,
      kind: 'add',
      payload: entry.toJson(),
    );
    _events.add(event);
    return event.seq;
  }

  @override
  Future<int> appendRetry(String localId, int retryCount) async {
    final event = OutboxEvent(
      seq: _nextSeq++,
      tsMs: DateTime.now().millisecondsSinceEpoch,
      localId: localId,
      sessionId: _findSessionId(localId),
      kind: 'retry',
      payload: {'retryCount': retryCount},
    );
    _events.add(event);
    return event.seq;
  }

  @override
  Future<int> appendSent(String localId) async {
    final event = OutboxEvent(
      seq: _nextSeq++,
      tsMs: DateTime.now().millisecondsSinceEpoch,
      localId: localId,
      sessionId: _findSessionId(localId),
      kind: 'sent',
    );
    _events.add(event);
    return event.seq;
  }

  @override
  Future<int> appendFailed(String localId) async {
    final event = OutboxEvent(
      seq: _nextSeq++,
      tsMs: DateTime.now().millisecondsSinceEpoch,
      localId: localId,
      sessionId: _findSessionId(localId),
      kind: 'failed',
    );
    _events.add(event);
    return event.seq;
  }

  @override
  Future<List<OutboxEvent>> readAll() async => List.unmodifiable(_events);

  @override
  Future<void> close() async {
    _events.clear();
  }

  String _findSessionId(String localId) {
    for (final ev in _events.reversed) {
      if (ev.localId == localId && ev.kind == 'add') {
        return ev.sessionId;
      }
    }
    return '';
  }

  /// Compact the event log: drop everything for messages that are
  /// already in a terminal state (`sent` or `failed`).  Called
  /// opportunistically when the live outbox is empty.
  void compact() {
    final terminal = <String>{};
    for (final ev in _events) {
      if (ev.kind == 'sent' || ev.kind == 'failed') {
        terminal.add(ev.localId);
      }
    }
    _events.removeWhere((e) => terminal.contains(e.localId));
  }
}

/// EXPERIMENTAL — see the library-level doc. This class has no
/// production call sites and no durable store; do not adopt it without
/// first adding the `sqlite3` dependency and dead-letter parity with
/// `MessageOutbox`.
///
/// Prospective drop-in replacement for `MessageOutbox`, backed by an
/// [OutboxStore]. The API mirrors the existing class so swapping would
/// be a one-line change in `sync_service.dart`:
///
/// ```dart
/// final messageOutbox = kUseSqliteOutbox
///     ? SqliteMessageOutbox(store: ...)
///     : MessageOutbox();
/// ```
///
/// Until the `sqlite3` dep is added, callers can wire
/// [InMemoryOutboxStore] for tests and benchmarks.
class SqliteMessageOutbox {
  SqliteMessageOutbox({
    required this.store,
    @visibleForTesting OutboxDeliverFn? deliverOverride,
  }) : _deliverOverride = deliverOverride;

  static const int _maxRetries = 3;

  /// Mirrors `MessageOutbox._maxTransientRetries` — keep the two in
  /// sync so this spike does not drift from the production budget.
  static const int _maxTransientRetries = 480;
  static const int _baseDelayMs = 1000;
  static const int _maxDelayMs = 30000;

  final OutboxStore store;
  final OutboxDeliverFn? _deliverOverride;

  OutboxDeliverFn? _deliver;
  OutboxStatusChangedFn? _onStatusChanged;

  final Map<String, OutboxEntry> _entries = {};
  final Map<String, Timer> _retryTimers = {};
  bool _initialized = false;

  static final Random _rng = Random();

  void configure({
    required OutboxDeliverFn deliver,
    OutboxStatusChangedFn? onStatusChanged,
  }) {
    _deliver = _deliverOverride ?? deliver;
    _onStatusChanged = onStatusChanged;
  }

  /// Open the store and rebuild the live outbox by folding events.
  Future<void> restoreAndFlush() async {
    if (_initialized) return;
    _initialized = true;
    await store.open();
    final events = await store.readAll();
    final folded = _foldEvents(events);
    _entries.addAll(folded);
    final sorted = folded.values.toList()
      ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    for (final entry in sorted) {
      _scheduleRetry(entry, initialDelay: const Duration(seconds: 2));
    }
  }

  /// Pure folder used both at restore and in tests to assert that the
  /// log is replayable.  Drops events whose terminal state has been
  /// recorded — `sent` / `failed` make the entry disappear from the
  /// live outbox.
  static Map<String, OutboxEntry> _foldEvents(List<OutboxEvent> events) {
    final live = <String, OutboxEntry>{};
    for (final ev in events) {
      switch (ev.kind) {
        case 'add':
          final payload = ev.payload;
          if (payload != null) {
            live[ev.localId] = OutboxEntry.fromJson(payload);
          }
        case 'retry':
          final entry = live[ev.localId];
          if (entry != null) {
            final newCount = (ev.payload?['retryCount'] as int?) ?? 0;
            live[ev.localId] = entry.copyWith(retryCount: newCount);
          }
        case 'sent':
        case 'failed':
          live.remove(ev.localId);
      }
    }
    return live;
  }

  Future<void> add(OutboxEntry entry) async {
    _entries[entry.localId] = entry;
    await store.appendAdd(entry);
    _onStatusChanged?.call(entry.sessionId, entry.localId, 'pending');
    _scheduleRetry(entry, initialDelay: _backoff(0));
  }

  Future<void> remove(String localId) async {
    if (_entries.remove(localId) != null) {
      _retryTimers.remove(localId)?.cancel();
      await store.appendSent(localId);
    }
  }

  bool contains(String localId) => _entries.containsKey(localId);

  List<OutboxEntry> get entries => List.unmodifiable(_entries.values);

  void suspend() {
    for (final t in _retryTimers.values) {
      t.cancel();
    }
    _retryTimers.clear();
  }

  void resume() {
    if (!_initialized) return;
    for (final entry in _entries.values) {
      _scheduleRetry(entry, initialDelay: const Duration(seconds: 1));
    }
  }

  Future<void> dispose() async {
    for (final t in _retryTimers.values) {
      t.cancel();
    }
    _retryTimers.clear();
    _entries.clear();
    _initialized = false;
    await store.close();
  }

  Duration _backoff(int retryCount) {
    final delayMs = min(_baseDelayMs * pow(2, retryCount).toInt(), _maxDelayMs);
    final jitter = _rng.nextInt(251);
    return Duration(milliseconds: delayMs + jitter);
  }

  void _scheduleRetry(OutboxEntry entry, {Duration? initialDelay}) {
    _retryTimers.remove(entry.localId)?.cancel();
    final delay = initialDelay ?? _backoff(entry.retryCount);
    _retryTimers[entry.localId] = Timer(delay, () {
      _retryTimers.remove(entry.localId);
      unawaited(_attempt(entry.localId));
    });
  }

  Future<void> _attempt(String localId) async {
    final entry = _entries[localId];
    if (entry == null) return;
    final deliver = _deliver;
    if (deliver == null) {
      logger.warning('[SqliteMessageOutbox] no deliver callback');
      return;
    }
    OutboxDeliveryFailure? failure;
    try {
      failure = await deliver(entry);
    } catch (e, stack) {
      logger.error('[SqliteMessageOutbox] deliver threw', e, stack);
      failure = const OutboxDeliveryFailure(
        OutboxFailureClass.transient,
        'unknown',
      );
    }
    if (failure == null) {
      _entries.remove(localId);
      await store.appendSent(localId);
      _onStatusChanged?.call(entry.sessionId, localId, 'sent');
      return;
    }
    final updated = entry.copyWith(
      retryCount: entry.retryCount + 1,
      failureClass: failure.failureClass,
      failureReason: failure.reason,
    );
    _entries[localId] = updated;
    await store.appendRetry(localId, updated.retryCount);
    final budget = failure.failureClass == OutboxFailureClass.permanent
        ? _maxRetries
        : _maxTransientRetries;
    if (updated.retryCount >= budget) {
      _entries.remove(localId);
      await store.appendFailed(localId);
      _onStatusChanged?.call(entry.sessionId, localId, 'failed');
      return;
    }
    _onStatusChanged?.call(entry.sessionId, localId, 'pending');
    _scheduleRetry(updated);
  }
}

/// Helper used by tests to round-trip an outbox entry through the
/// log fold, without building a full SQLite database.  Mirrors the
/// behaviour the real driver will exhibit when the `sqlite3` dep
/// is wired up.
@visibleForTesting
Map<String, OutboxEntry> debugFoldEvents(List<Map<String, dynamic>> rawEvents) {
  final events = rawEvents
      .map(
        (m) => OutboxEvent(
          seq: WireParsers.parseInt(m['seq']) ?? 0,
          tsMs: WireParsers.parseInt(m['ts_ms']) ?? 0,
          localId: m['local_id'] as String,
          sessionId: m['session_id'] as String? ?? '',
          kind: m['kind'] as String,
          payload: WireParsers.asMap(m['payload']) ??
              ((m['payload'] is String)
                  ? jsonDecode(m['payload'] as String) as Map<String, dynamic>
                  : null),
        ),
      )
      .toList();
  return SqliteMessageOutbox._foldEvents(events);
}
