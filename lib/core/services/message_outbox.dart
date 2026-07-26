import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../wire/wire_parsers.dart';
import 'logger_service.dart';
import 'mmkv_storage.dart';
import 'power_diagnostics_service.dart';

/// A single queued message awaiting delivery.
class OutboxEntry {
  const OutboxEntry({
    required this.localId,
    required this.sessionId,
    required this.text,
    required this.encryptedContent,
    required this.rawRecord,
    required this.queuedAt,
    this.retryCount = 0,
    this.dead = false,
  });

  factory OutboxEntry.fromJson(Map<String, dynamic> json) {
    return OutboxEntry(
      localId: json['localId'] as String,
      sessionId: json['sessionId'] as String,
      text: json['text'] as String,
      encryptedContent: json['encryptedContent'] as String,
      rawRecord: WireParsers.asMap(json['rawRecord']) ?? {},
      queuedAt: json['queuedAt'] as int,
      retryCount: json['retryCount'] as int? ?? 0,
      dead: json['dead'] == true,
    );
  }

  /// Unique ID assigned at send time (matches the optimistic message).
  final String localId;

  /// Session the message belongs to.
  final String sessionId;

  /// Plaintext message text (for display in the optimistic message).
  final String text;

  /// Pre-encrypted content ready to POST to the server.
  final String encryptedContent;

  /// The raw (unencrypted) message record used for socket emit.
  final Map<String, dynamic> rawRecord;

  /// Milliseconds since epoch when the entry was queued.
  final int queuedAt;

  /// How many delivery attempts have been made so far.
  final int retryCount;

  /// Whether this entry exhausted its retries and moved to the
  /// dead-letter bucket. Dead entries are still persisted (the encrypted
  /// payload is the only recoverable copy of the user's message) but are
  /// never auto-retried; the user drives recovery from the `'failed'`
  /// row's retry affordance.
  final bool dead;

  OutboxEntry copyWith({int? retryCount, bool? dead}) {
    return OutboxEntry(
      localId: localId,
      sessionId: sessionId,
      text: text,
      encryptedContent: encryptedContent,
      rawRecord: rawRecord,
      queuedAt: queuedAt,
      retryCount: retryCount ?? this.retryCount,
      dead: dead ?? this.dead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'localId': localId,
      'sessionId': sessionId,
      'text': text,
      'encryptedContent': encryptedContent,
      'rawRecord': rawRecord,
      'queuedAt': queuedAt,
      'retryCount': retryCount,
      if (dead) 'dead': true,
    };
  }
}

/// Callback invoked when the outbox attempts to deliver a queued message.
///
/// Returns `true` on success, `false` if delivery should be retried later.
typedef OutboxDeliverFn = Future<bool> Function(OutboxEntry entry);

/// Callback invoked after delivery status changes so the UI can update.
typedef OutboxStatusChangedFn = void Function(
  String sessionId,
  String localId,
  String status,
);

/// Offline message outbox with exponential-backoff retry.
///
/// Failed message sends are queued here and retried automatically.
/// Entries are persisted to MMKV so they survive app restarts.
///
/// Retry schedule:
///   attempt 1 → 1 s
///   attempt 2 → 2 s
///   attempt 3 → 4 s
///   (max 30 s cap, max 3 retries before marking as permanently failed)
class MessageOutbox {
  MessageOutbox({
    MMKVStorage? storage,
    @visibleForTesting OutboxDeliverFn? deliverOverride,
  })  : _storage = storage ?? MMKVStorage(),
        _deliverOverride = deliverOverride;

  static const int _maxRetries = 3;
  static const int _baseDelayMs = 1000;
  static const int _maxDelayMs = 30000;

  /// How many dead-lettered entries are kept on disk. Bounded so a
  /// long-running permanent failure (e.g. a deleted session) cannot grow
  /// the MMKV blob without limit. Oldest entries are dropped first.
  static const int maxDeadEntries = 50;

  MMKVStorage _storage;

  /// Override the storage backend for testing. Avoids MMKV
  /// initialization failures in CI where the native plugin is
  /// unavailable.
  @visibleForTesting
  set testStorage(MMKVStorage value) => _storage = value;
  final OutboxDeliverFn? _deliverOverride;

  OutboxDeliverFn? _deliver;
  OutboxStatusChangedFn? _onStatusChanged;

  final Map<String, OutboxEntry> _entries = {};

  /// Dead-letter bucket: entries that exhausted [_maxRetries]. They are
  /// persisted alongside the live entries so the encrypted payload
  /// survives a cold start and the user's retry affordance still has
  /// something to resend.
  final Map<String, OutboxEntry> _dead = {};
  final Map<String, Timer> _retryTimers = {};
  Timer? _persistTimer;
  bool _initialized = false;

  static final Random _rng = Random();

  /// Register the delivery callback and status-change notifier.
  /// Must be called before [add] or [restoreAndFlush].
  void configure({
    required OutboxDeliverFn deliver,
    OutboxStatusChangedFn? onStatusChanged,
  }) {
    _deliver = _deliverOverride ?? deliver;
    _onStatusChanged = onStatusChanged;
  }

  /// Load persisted entries from MMKV and schedule retries for any that
  /// are still pending. Call this once after [configure] on app startup.
  Future<void> restoreAndFlush() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final raw = await _storage.getOutboxEntries();
      if (raw == null) return;
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final entry = OutboxEntry.fromJson(item);
          if (entry.dead) {
            _dead[entry.localId] = entry;
          } else {
            _entries[entry.localId] = entry;
          }
          logger.info(
            '[MessageOutbox] restored entry '
            'localId=${entry.localId} '
            'session=${entry.sessionId} '
            'retryCount=${entry.retryCount} '
            'dead=${entry.dead}',
          );
        }
      }
      // Republish the terminal state of every dead-lettered entry so the
      // chat row comes back as 'failed' (and therefore retryable) after a
      // cold start, instead of a row stuck on 'sending' forever.
      //
      // This only lands for sessions whose messages are already loaded.
      // Sessions opened later are reconciled by
      // `Sync.reconcileOutboxStatuses`, called from the chat load path.
      for (final entry in _dead.values) {
        _onStatusChanged?.call(entry.sessionId, entry.localId, 'failed');
      }
      // Flush all restored entries (with a brief initial delay so sync can
      // finish initializing before we start making network calls).
      // Sort by queuedAt to maintain message ordering on restore.
      final sortedEntries = List.of(_entries.values)
        ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
      for (final entry in sortedEntries) {
        _scheduleRetry(entry, initialDelay: const Duration(seconds: 2));
      }
    } catch (e) {
      logger.warning('[MessageOutbox] failed to restore entries: $e');
    }
  }

  /// Queue a failed message for retry.
  Future<void> add(OutboxEntry entry) async {
    _dead.remove(entry.localId);
    _entries[entry.localId] = entry.copyWith(dead: false);
    _schedulePersist();
    _onStatusChanged?.call(entry.sessionId, entry.localId, 'pending');
    logger.info(
      '[MessageOutbox] queued localId=${entry.localId} '
      'session=${entry.sessionId}',
    );
    _scheduleRetry(entry, initialDelay: _backoffDuration(0));
  }

  /// Remove an entry that was successfully delivered externally.
  Future<void> remove(String localId) async {
    final removed =
        _entries.remove(localId) != null || _dead.remove(localId) != null;
    if (removed) {
      _retryTimers.remove(localId)?.cancel();
      _schedulePersist();
      logger.info('[MessageOutbox] removed localId=$localId');
    }
  }

  /// Test-only: place [entry] in the pending bucket WITHOUT scheduling a
  /// retry timer or a persist. Lets widget tests reproduce "the outbox
  /// now owns this message" without leaving pending timers behind.
  @visibleForTesting
  void testInsertPending(OutboxEntry entry) {
    _entries[entry.localId] = entry.copyWith(dead: false);
  }

  /// Test-only: place [entry] in the dead-letter bucket directly.
  @visibleForTesting
  void testInsertDead(OutboxEntry entry) {
    _dead[entry.localId] = entry.copyWith(dead: true);
  }

  /// Whether the outbox contains an entry with the given [localId].
  bool contains(String localId) => _entries.containsKey(localId);

  /// All pending entries (unmodifiable view).
  List<OutboxEntry> get entries => List.unmodifiable(_entries.values);

  /// All dead-lettered entries (unmodifiable view).
  List<OutboxEntry> get deadEntries => List.unmodifiable(_dead.values);

  /// The dead-lettered entry for [localId], or `null` when the message
  /// never exhausted its retries.
  ///
  /// This is the last surviving copy of a permanently-failed message —
  /// use it to rebuild a retry when the in-memory chat row no longer
  /// carries the original `raw` record.
  OutboxEntry? deadEntry(String localId) => _dead[localId];

  /// Move a dead-lettered entry back into the live queue with a fresh
  /// retry budget. No-op when [localId] is not dead-lettered.
  Future<bool> reviveDead(String localId) async {
    final entry = _dead.remove(localId);
    if (entry == null) return false;
    logger.info('[MessageOutbox] reviving dead entry localId=$localId');
    await add(entry.copyWith(retryCount: 0, dead: false));
    return true;
  }

  /// Suspend retry timers when app goes to background.
  /// Entries are preserved for retry on resume.
  ///
  /// Any debounced persist is flushed first. Cancelling [_persistTimer]
  /// without writing loses every entry queued in the preceding 100 ms
  /// when the OS kills the backgrounded app — the message disappears
  /// from MMKV while the cached UI row still reads `'sending'`.
  ///
  /// The flush is started synchronously (the JSON encode runs before
  /// this method returns), mirroring the sibling cache flushes in
  /// `Sync.suspend()`. Callers that can await should prefer
  /// [suspendAndFlush].
  void suspend() {
    unawaited(suspendAndFlush());
  }

  /// Awaitable variant of [suspend]: completes once the pending persist
  /// has actually been written to storage.
  Future<void> suspendAndFlush() async {
    final hadPendingPersist = _persistTimer != null;
    _persistTimer?.cancel();
    _persistTimer = null;
    for (final t in _retryTimers.values) {
      t.cancel();
    }
    _retryTimers.clear();
    if (hadPendingPersist) {
      await _persist();
    }
  }

  /// Resume retry timers when app returns to foreground.
  void resume() {
    if (!_initialized) return;
    // Re-schedule retries for all pending entries
    for (final entry in _entries.values) {
      _scheduleRetry(entry, initialDelay: const Duration(seconds: 1));
    }
  }

  /// Cancel all pending retry timers and clear in-memory state.
  void dispose() {
    _persistTimer?.cancel();
    _persistTimer = null;
    for (final t in _retryTimers.values) {
      t.cancel();
    }
    _retryTimers.clear();
    _entries.clear();
    _dead.clear();
    _initialized = false;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Duration _backoffDuration(int retryCount) {
    final delayMs = min(
      _baseDelayMs * pow(2, retryCount).toInt(),
      _maxDelayMs,
    );
    final jitter = _rng.nextInt(251); // 0–250 ms
    return Duration(milliseconds: delayMs + jitter);
  }

  void _scheduleRetry(
    OutboxEntry entry, {
    Duration? initialDelay,
  }) {
    _retryTimers.remove(entry.localId)?.cancel();
    final delay = initialDelay ?? _backoffDuration(entry.retryCount);
    logger.info(
      '[MessageOutbox] scheduling retry for '
      'localId=${entry.localId} in ${delay.inMilliseconds}ms '
      '(attempt ${entry.retryCount + 1})',
    );
    powerDiagnostics.recordOutboxSchedule(
      localId: entry.localId,
      delayMs: delay.inMilliseconds,
    );
    _retryTimers[entry.localId] = Timer(delay, () {
      _retryTimers.remove(entry.localId);
      unawaited(_attempt(entry.localId));
    });
  }

  Future<void> _attempt(String localId) async {
    final entry = _entries[localId];
    if (entry == null) return; // already removed

    final deliver = _deliver;
    if (deliver == null) {
      logger.warning(
        '[MessageOutbox] no deliver callback configured, '
        'skipping attempt for localId=$localId',
      );
      return;
    }

    logger.info(
      '[MessageOutbox] attempting delivery '
      'localId=$localId '
      'retryCount=${entry.retryCount}',
    );
    powerDiagnostics.recordOutboxAttempt(localId);

    bool success;
    try {
      success = await deliver(entry);
    } catch (e, stack) {
      logger.error(
        '[MessageOutbox] delivery threw for localId=$localId',
        e,
        stack,
      );
      success = false;
    }

    if (success) {
      logger.info(
        '[MessageOutbox] delivered localId=$localId',
      );
      _entries.remove(localId);
      _schedulePersist();
      _onStatusChanged?.call(entry.sessionId, localId, 'sent');
      return;
    }

    // Delivery failed — increment retry count.
    final updated = entry.copyWith(retryCount: entry.retryCount + 1);
    _entries[localId] = updated;
    _schedulePersist();

    if (updated.retryCount >= _maxRetries) {
      logger.warning(
        '[MessageOutbox] max retries reached for '
        'localId=$localId — dead-lettering',
      );
      // Do NOT drop the entry: its encrypted payload is the only
      // recoverable copy of the user's message. Move it to the
      // dead-letter bucket so a cold start can still republish the
      // 'failed' row and a retry can rebuild the send.
      _entries.remove(localId);
      _deadLetter(updated.copyWith(dead: true));
      _schedulePersist();
      _onStatusChanged?.call(entry.sessionId, localId, 'failed');
      return;
    }

    logger.info(
      '[MessageOutbox] delivery failed for '
      'localId=$localId, will retry '
      '(attempt ${updated.retryCount + 1} of $_maxRetries)',
    );
    powerDiagnostics.recordOutboxFailure(localId);
    _onStatusChanged?.call(entry.sessionId, localId, 'pending');
    _scheduleRetry(updated);
  }

  void _deadLetter(OutboxEntry entry) {
    _dead[entry.localId] = entry;
    if (_dead.length <= maxDeadEntries) return;
    // Bounded: drop the oldest dead entries first.
    final ordered = List.of(_dead.values)
      ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    for (final stale in ordered.take(_dead.length - maxDeadEntries)) {
      _dead.remove(stale.localId);
      logger.warning(
        '[MessageOutbox] dead-letter bucket full, dropping '
        'localId=${stale.localId}',
      );
    }
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 100), () {
      // Clear before persisting: a completed timer left in place makes
      // the `hadPendingPersist` guard in suspendAndFlush() permanently
      // true, so every suspend re-encodes and rewrites the whole blob.
      _persistTimer = null;
      unawaited(_persist());
    });
  }

  Future<void> _persist() async {
    try {
      final list = [
        ..._entries.values.map((e) => e.toJson()),
        ..._dead.values.map((e) => e.toJson()),
      ];
      await _storage.saveOutboxEntries(jsonEncode(list));
    } catch (e) {
      logger.warning('[MessageOutbox] failed to persist: $e');
    }
  }
}

/// Global singleton outbox — mirrors the pattern used by [Sync], [logger],
/// and [socketIoClient].
final messageOutbox = MessageOutbox();
