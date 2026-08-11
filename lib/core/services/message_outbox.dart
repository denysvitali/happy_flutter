import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../wire/wire_parsers.dart';
import 'at_rest_encryption_service.dart';
import 'logger_service.dart';
import 'mmkv_storage.dart';
import 'power_diagnostics_service.dart';

/// Whether a delivery failure may succeed on a later attempt.
enum OutboxFailureClass {
  /// Timeout, unreachable network, 5xx, 429 — the server may accept the
  /// message later (e.g. once a brownout clears), so the outbox keeps
  /// retrying for hours with a capped backoff instead of giving up after
  /// a handful of attempts.
  transient,

  /// The server rejected the message definitively (4xx, session gone).
  /// Retrying past a small budget only burns requests; the entry
  /// dead-letters quickly and recovery is user-driven via the failed
  /// row's retry affordance.
  permanent,
}

/// Non-`null` return of [OutboxDeliverFn]: why delivery failed.
///
/// `null` means the message was delivered.
class OutboxDeliveryFailure {
  const OutboxDeliveryFailure(this.failureClass, [this.reason]);

  final OutboxFailureClass failureClass;

  /// Bucketed telemetry reason — one of `timeout`, `network`,
  /// `server_error`, `rate_limited`, `session_gone`, `client_rejected`,
  /// `unknown`. Never a raw exception string or a per-message id (both
  /// would explode metric cardinality).
  final String? reason;

  static const transient = OutboxDeliveryFailure(OutboxFailureClass.transient);
  static const permanent = OutboxDeliveryFailure(OutboxFailureClass.permanent);
}

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
    this.failureClass,
    this.failureReason,
  });

  factory OutboxEntry.fromJson(Map<String, dynamic> json) {
    OutboxFailureClass? failureClass;
    switch (json['failureClass']) {
      case 'transient':
        failureClass = OutboxFailureClass.transient;
      case 'permanent':
        failureClass = OutboxFailureClass.permanent;
    }
    return OutboxEntry(
      localId: json['localId'] as String,
      sessionId: json['sessionId'] as String,
      text: json['text'] as String,
      encryptedContent: json['encryptedContent'] as String,
      rawRecord: WireParsers.asMap(json['rawRecord']) ?? {},
      queuedAt: json['queuedAt'] as int,
      retryCount: json['retryCount'] as int? ?? 0,
      dead: json['dead'] == true,
      failureClass: failureClass,
      failureReason: json['failureReason'] as String?,
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
  /// payload is the only recoverable copy of the user's message).
  /// Transient-class dead entries are re-armed automatically on
  /// reconnect/foreground; permanent-class ones wait for the user to
  /// drive recovery from the `'failed'` row's retry affordance.
  final bool dead;

  /// Class of the most recent delivery failure, once known. Drives the
  /// retry budget: transient failures retry for hours, permanent ones
  /// dead-letter quickly. `null` entries (queued before their first
  /// attempt, or persisted by older builds) get the transient budget —
  /// losing a message is worse than one extra retry cycle.
  final OutboxFailureClass? failureClass;

  /// Bucketed reason of the most recent delivery failure, for telemetry.
  final String? failureReason;

  OutboxEntry copyWith({
    int? retryCount,
    bool? dead,
    OutboxFailureClass? failureClass,
    String? failureReason,
  }) {
    return OutboxEntry(
      localId: localId,
      sessionId: sessionId,
      text: text,
      encryptedContent: encryptedContent,
      rawRecord: rawRecord,
      queuedAt: queuedAt,
      retryCount: retryCount ?? this.retryCount,
      dead: dead ?? this.dead,
      failureClass: failureClass ?? this.failureClass,
      failureReason: failureReason ?? this.failureReason,
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
      if (failureClass != null) 'failureClass': failureClass!.name,
      if (failureReason != null) 'failureReason': failureReason,
    };
  }
}

/// Callback invoked when the outbox attempts to deliver a queued message.
///
/// Returns `null` on success, or an [OutboxDeliveryFailure] describing why
/// delivery failed. The failure class selects the retry budget: transient
/// failures (timeouts, network, 5xx) keep retrying for hours with capped
/// backoff; permanent failures (4xx, session gone) dead-letter after a
/// small budget.
typedef OutboxDeliverFn =
    Future<OutboxDeliveryFailure?> Function(OutboxEntry entry);

/// Callback invoked after delivery status changes so the UI can update.
typedef OutboxStatusChangedFn =
    void Function(String sessionId, String localId, String status);

/// Offline message outbox with exponential-backoff retry.
///
/// Failed message sends are queued here and retried automatically.
/// Entries are persisted to MMKV so they survive app restarts.
///
/// Retry schedule:
///   attempt 1 → 1 s
///   attempt 2 → 2 s
///   attempt 3 → 4 s
///   …doubling to a 30 s cap.
///
/// Budgets are failure-class aware (audit 2026-08-03 — four messages were
/// permanently lost because the old flat 3-retry / ~40 s budget was shorter
/// than the observed 30–75 min server brownouts):
///   * transient (timeout / network / 5xx / 429): [_maxTransientRetries]
///     attempts — roughly four hours at the 30 s cap;
///   * permanent (4xx / session gone): [_maxRetries] attempts, then the
///     entry dead-letters and waits for the user.
class MessageOutbox {
  MessageOutbox({
    MMKVStorage? storage,
    @visibleForTesting OutboxDeliverFn? deliverOverride,
    @visibleForTesting AtRestEncryptionService? protection,
  }) : _storage = storage ?? MMKVStorage(),
       _protection =
           protection ??
           (storage == null
               ? AtRestEncryptionService()
               : AtRestEncryptionService.memoryOnly(_testProtectionKey)),
       _deliverOverride = deliverOverride;

  static const int _maxRetries = 3;

  /// ~4 h of retries once the 30 s backoff cap is reached. Deliberately
  /// longer than any observed server brownout so a wedged write path does
  /// not convert into permanent message loss.
  static const int _maxTransientRetries = 480;
  static const int _baseDelayMs = 1000;
  static const int _maxDelayMs = 30000;

  /// How many dead-lettered entries are kept on disk. Bounded so a
  /// long-running permanent failure (e.g. a deleted session) cannot grow
  /// the MMKV blob without limit. Oldest entries are dropped first.
  static const int maxDeadEntries = 50;
  static const String _outboxAssociatedData = 'message-outbox:v1';
  static final Uint8List _testProtectionKey = Uint8List.fromList(
    List<int>.generate(32, (index) => 32 - index),
  );

  MMKVStorage _storage;
  AtRestEncryptionService _protection;

  /// Override the storage backend for testing. Avoids MMKV
  /// initialization failures in CI where the native plugin is
  /// unavailable.
  @visibleForTesting
  set testStorage(MMKVStorage value) {
    _storage = value;
    _protection = AtRestEncryptionService.memoryOnly(_testProtectionKey);
  }

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
  final Map<String, Future<void>> _sessionDeliveryTails = {};
  Timer? _persistTimer;
  bool _initialized = false;
  int _generation = 0;

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
    String? raw;
    try {
      raw = await _storage.getOutboxEntries();
    } catch (error) {
      // A transient MMKV read failure is not evidence that the persisted
      // payload is corrupt. Leave it untouched and allow a later retry.
      _initialized = false;
      logger.warning(
        '[MessageOutbox] failed to read persisted entries: $error',
      );
      return;
    }
    try {
      if (raw == null) return;
      final wasLegacyPlaintext = !_protection.isProtected(raw);
      if (!_protection.isReady) {
        try {
          await _protection.initialize();
        } catch (error) {
          if (wasLegacyPlaintext) {
            // Fail closed: legacy data must never remain plaintext merely
            // because the secure key is temporarily unavailable.
            await _storage.saveOutboxEntries('');
          }
          // Keep an already-encrypted blob byte-for-byte intact so recovery
          // can be retried when platform secure storage is available again.
          _initialized = false;
          logger.warning(
            '[MessageOutbox] protection key unavailable during restore: '
            '$error',
          );
          return;
        }
      }
      final plaintext = wasLegacyPlaintext
          ? raw
          : _protection.unprotectString(
              raw,
              associatedData: _outboxAssociatedData,
            );
      if (plaintext == null) {
        await _replacePersistedOutboxWithEmpty();
        return;
      }
      final list = jsonDecode(plaintext) as List<dynamic>;
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
      if (wasLegacyPlaintext) {
        // Complete the one-way migration before scheduling any retries. The
        // same localId/rawRecord values are encrypted as one atomic blob.
        final migrated = await _persistCurrentSnapshot();
        if (!migrated) {
          // Normal debounced writes are loss-averse and retain their previous
          // ciphertext on failure. Migration is stricter: if sealing failed,
          // remove the legacy plaintext before any retry is scheduled.
          await _storage.saveOutboxEntries('');
          _entries.clear();
          _dead.clear();
          return;
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
      _entries.clear();
      _dead.clear();
      await _replacePersistedOutboxWithEmpty();
    }
  }

  /// Queue a failed message for retry.
  Future<void> add(OutboxEntry entry) async {
    final previousPending = _entries[entry.localId];
    final previousDead = _dead.remove(entry.localId);
    _entries[entry.localId] = entry.copyWith(dead: false);
    // A successful return is the durability boundary. In particular, callers
    // may background or be killed immediately after this future completes;
    // the entry must already be recoverable from storage at that point.
    _persistTimer?.cancel();
    _persistTimer = null;
    if (!await _persistCurrentSnapshot()) {
      _entries.remove(entry.localId);
      if (previousPending != null) {
        _entries[entry.localId] = previousPending;
      }
      if (previousDead != null) {
        _dead[entry.localId] = previousDead;
      }
      throw StateError('Failed to persist message outbox entry');
    }
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
      _persistTimer?.cancel();
      _persistTimer = null;
      if (!await _persistCurrentSnapshot()) {
        _schedulePersist();
      }
      logger.info('[MessageOutbox] removed localId=$localId');
    }
  }

  /// Runs delivery work in FIFO order for one session.
  ///
  /// Foreground sends and outbox retries share this queue, preventing a later
  /// message or a restored retry from overtaking an earlier logical send.
  /// Different sessions remain independent.
  Future<T> serialize<T>(String sessionId, Future<T> Function() action) {
    final result = Completer<T>();
    final previous = _sessionDeliveryTails[sessionId] ?? Future<void>.value();
    late final Future<void> tail;
    tail = previous.catchError((Object _) {}).then((_) async {
      try {
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    _sessionDeliveryTails[sessionId] = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_sessionDeliveryTails[sessionId], tail)) {
          _sessionDeliveryTails.remove(sessionId);
        }
      }),
    );
    return result.future;
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
  ///
  /// User-driven (the failed row's retry affordance) — revives ANY class,
  /// including permanent ones: a user tap is an explicit "try again".
  Future<bool> reviveDead(String localId) async {
    final entry = _dead.remove(localId);
    if (entry == null) return false;
    logger.info('[MessageOutbox] reviving dead entry localId=$localId');
    await add(entry.copyWith(retryCount: 0, dead: false));
    return true;
  }

  /// Re-arm every dead-lettered entry whose failure was NOT a permanent
  /// server rejection, giving each a fresh retry budget.
  ///
  /// Called on socket reconnect and foreground resume (audit 2026-08-03:
  /// a brownout longer than the retry budget used to convert queued sends
  /// into permanent loss; the network coming back is exactly the signal
  /// that a transient failure may now deliver). Entries that never carried
  /// a class (queued by older builds) are revived too — loss-averse.
  /// Permanent-class entries stay dead for the user to retry by hand.
  ///
  /// Returns how many entries were re-armed.
  Future<int> reviveTransientDead({String reason = 'reconnect'}) async {
    final candidates = _dead.values
        .where((e) => e.failureClass != OutboxFailureClass.permanent)
        .toList();
    if (candidates.isEmpty) return 0;
    logger.info(
      '[MessageOutbox] re-arming ${candidates.length} '
      'dead-lettered entr${candidates.length == 1 ? 'y' : 'ies'} '
      '($reason)',
    );
    for (final entry in candidates) {
      _dead.remove(entry.localId);
      await add(entry.copyWith(retryCount: 0, dead: false));
    }
    return candidates.length;
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
  ///
  /// Also re-arms transient-class dead letters: the app coming back to the
  /// foreground usually means the network is usable again, which is the
  /// signal a brownout-dead-lettered send was waiting for.
  void resume() {
    if (!_initialized) return;
    // Re-schedule retries for all pending entries
    for (final entry in _entries.values) {
      _scheduleRetry(entry, initialDelay: const Duration(seconds: 1));
    }
    unawaited(reviveTransientDead(reason: 'app resumed'));
  }

  /// Cancel all pending retry timers and clear in-memory state.
  void dispose() {
    _generation++;
    _persistTimer?.cancel();
    _persistTimer = null;
    for (final t in _retryTimers.values) {
      t.cancel();
    }
    _retryTimers.clear();
    _sessionDeliveryTails.clear();
    _entries.clear();
    _dead.clear();
    _initialized = false;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Duration _backoffDuration(int retryCount) {
    final delayMs = min(_baseDelayMs * pow(2, retryCount).toInt(), _maxDelayMs);
    final jitter = _rng.nextInt(251); // 0–250 ms
    return Duration(milliseconds: delayMs + jitter);
  }

  void _scheduleRetry(OutboxEntry entry, {Duration? initialDelay}) {
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

    final generation = _generation;
    await serialize(entry.sessionId, () async {
      await _attemptSerialized(localId, generation);
    });
  }

  Future<void> _attemptSerialized(String localId, int generation) async {
    final entry = _entries[localId];
    if (entry == null || generation != _generation) return;

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

    OutboxDeliveryFailure? failure;
    try {
      failure = await deliver(entry);
    } catch (e, stack) {
      logger.error(
        '[MessageOutbox] delivery threw for localId=$localId',
        e,
        stack,
      );
      // An unexpected throw carries no class — treat it as transient.
      // Losing a message to an early dead-letter is worse than spending
      // a few extra retries on a genuinely broken deliver callback.
      failure = const OutboxDeliveryFailure(
        OutboxFailureClass.transient,
        'unknown',
      );
    }

    if (generation != _generation || _entries[localId] == null) return;

    if (failure == null) {
      logger.info('[MessageOutbox] delivered localId=$localId');
      _entries.remove(localId);
      _persistTimer?.cancel();
      _persistTimer = null;
      if (!await _persistCurrentSnapshot()) {
        _schedulePersist();
      }
      _onStatusChanged?.call(entry.sessionId, localId, 'sent');
      return;
    }

    // Delivery failed — increment retry count and remember the class.
    final updated = entry.copyWith(
      retryCount: entry.retryCount + 1,
      failureClass: failure.failureClass,
      failureReason: failure.reason,
    );
    _entries[localId] = updated;
    _schedulePersist();

    // Count EVERY failed attempt, including the terminal one. The audit
    // found the final attempt uncounted because the dead branch used to
    // return before recordOutboxFailure — the failure rate silently
    // under-reported by one per lost message.
    powerDiagnostics.recordOutboxFailure(localId, reason: failure.reason);

    final budget = failure.failureClass == OutboxFailureClass.permanent
        ? _maxRetries
        : _maxTransientRetries;

    if (updated.retryCount >= budget) {
      logger.warning(
        '[MessageOutbox] retry budget exhausted for '
        'localId=$localId '
        'class=${failure.failureClass.name} '
        'reason=${failure.reason ?? 'unknown'} — dead-lettering',
      );
      // Do NOT drop the entry: its encrypted payload is the only
      // recoverable copy of the user's message. Move it to the
      // dead-letter bucket so a cold start can still republish the
      // 'failed' row and a retry can rebuild the send. Transient-class
      // entries are re-armed automatically on reconnect/foreground.
      _entries.remove(localId);
      _deadLetter(updated.copyWith(dead: true));
      _schedulePersist();
      powerDiagnostics.recordOutboxDeadLetter(
        localId,
        reason: failure.reason,
        failureClass: failure.failureClass.name,
      );
      _onStatusChanged?.call(entry.sessionId, localId, 'failed');
      return;
    }

    logger.info(
      '[MessageOutbox] delivery failed for '
      'localId=$localId, will retry '
      '(attempt ${updated.retryCount + 1} of $budget)',
    );
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
    await _persistCurrentSnapshot();
  }

  Future<bool> _persistCurrentSnapshot() async {
    try {
      if (!_protection.isReady) {
        await _protection.initialize();
      }
      final list = [
        ..._entries.values.map((e) => e.toJson()),
        ..._dead.values.map((e) => e.toJson()),
      ];
      final protected = _protection.protectString(
        jsonEncode(list),
        associatedData: _outboxAssociatedData,
      );
      if (protected == null) {
        logger.warning(
          '[MessageOutbox] device protection key unavailable; '
          'skipping persist',
        );
        return false;
      }
      await _storage.saveOutboxEntries(protected);
      return true;
    } catch (e) {
      logger.warning('[MessageOutbox] failed to persist: $e');
      return false;
    }
  }

  Future<void> _replacePersistedOutboxWithEmpty() async {
    try {
      if (!_protection.isReady) {
        await _protection.initialize();
      }
      final protected = _protection.protectString(
        '[]',
        associatedData: _outboxAssociatedData,
      );
      await _storage.saveOutboxEntries(protected ?? '');
    } catch (error) {
      // An empty string carries no user data and prevents legacy plaintext
      // from surviving when secure storage is unavailable.
      await _storage.saveOutboxEntries('');
      logger.warning('[MessageOutbox] failed to seal empty outbox: $error');
    }
  }
}

/// Global singleton outbox — mirrors the pattern used by [Sync], [logger],
/// and [socketIoClient].
final messageOutbox = MessageOutbox();
