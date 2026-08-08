import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show compute, kIsWeb, visibleForTesting;
import 'package:sentry_flutter/sentry_flutter.dart';

import '../utils/image_content_blocks.dart';
import 'at_rest_encryption_service.dart';
import 'logger_service.dart' show logger;
import 'mmkv_storage.dart';
import 'opentelemetry_service.dart';

const String _cacheCiphertextMarker = '_happyAtRestCiphertext';

/// Cache window prepared for persistence.
class _PreparedCacheWindow {
  const _PreparedCacheWindow({
    required this.messages,
    required this.originalCount,
    required this.hash,
    required this.prepareMs,
  });

  final List<Map<String, dynamic>> messages;
  final int originalCount;
  final int hash;
  final int prepareMs;
}

_PreparedCacheWindow _prepareMessageCacheWindow(
  List<Map<String, dynamic>> messages,
) {
  final prepareWatch = Stopwatch()..start();
  final withoutSynthetics = MessageCacheService.stripOrphanSynthetics(messages);
  final trimmed = MessageCacheService._trimToCacheWindow(withoutSynthetics);
  final sanitized = trimmed.map(stripInlineImageData).toList();
  return _PreparedCacheWindow(
    messages: sanitized,
    originalCount: messages.length,
    hash: MessageCacheService._computeCacheWindowHash(sanitized),
    prepareMs: prepareWatch.elapsedMilliseconds,
  );
}

/// Top-level isolate worker: prepares, encodes, and protects a cache window.
///
/// Must stay top-level and take only sendable POD arguments — a closure
/// capturing `this` here reintroduces the "Isolate unsendable Future"
/// production bug (ROADMAP, 7b69d1b).
Map<String, dynamic> _prepareAndProtectMessageCacheJson(
  Map<String, dynamic> request,
) {
  final protectionKey = request['protectionKey'] as Uint8List;
  try {
    final messages = (request['messages'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final associatedData = request['associatedData'] as String;
    final prepared = _prepareMessageCacheWindow(messages);
    final protected = protectAtRestPayloadForWorker(
      jsonEncode(prepared.messages),
      associatedData: associatedData,
      key: protectionKey,
    );
    return <String, dynamic>{
      'encodedMarker': protected == null
          ? null
          : jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{_cacheCiphertextMarker: protected},
            ]),
      'originalCount': prepared.originalCount,
      'savedCount': prepared.messages.length,
      'hash': prepared.hash,
      'prepareMs': prepared.prepareMs,
    };
  } finally {
    // Also covers failures before the encryption helper is reached.
    protectionKey.fillRange(0, protectionKey.length, 0);
  }
}

/// A raw cache snapshot queued for background preparation + persistence.
///
/// Queuing (rather than firing one `compute()` per save) means at most
/// one encode isolate is alive at a time and a session that changes
/// again while its previous snapshot is still encoding supersedes it
/// instead of racing a second isolate.
class _PendingCacheSave {
  _PendingCacheSave({required this.messages, required this.seq});

  final List<Map<String, dynamic>> messages;

  /// Monotonic write order. A write whose [seq] is older than the last
  /// committed write for the session is dropped instead of clobbering
  /// fresher data (e.g. the synchronous suspend flush).
  final int seq;
  final Completer<void> completer = Completer<void>();
  final Stopwatch queueWatch = Stopwatch()..start();

  void complete() {
    if (!completer.isCompleted) completer.complete();
  }
}

/// Local-first message cache service.
///
/// Provides instant access to cached messages while network fetches
/// happen in the background. Messages are persisted to MMKV for
/// immediate cold-start loads.
///
/// On web, at most [_maxWebSessions] sessions are kept in the cache to
/// avoid exceeding IndexedDB quota limits. The least-recently-used
/// sessions are evicted when a new session is written and the limit
/// would be exceeded.
class MessageCacheService {
  factory MessageCacheService() => _instance;
  MessageCacheService._();
  static final MessageCacheService _instance = MessageCacheService._();

  /// Storage backend.  Defaults to the singleton MMKVStorage.  Tests can
  /// override this via [debugSetStorage] to inject a stateful fake so
  /// round-trip behavior (e.g. cleaned-cache rewrites) can be observed
  /// without booting the native MMKV plugin.
  MMKVStorage _storage = MMKVStorage();
  AtRestEncryptionService _protection = AtRestEncryptionService();

  static final Uint8List _testProtectionKey = Uint8List.fromList(
    List<int>.generate(32, (index) => index + 1),
  );

  @visibleForTesting
  // ignore: avoid_setters_without_getters
  set debugSetStorage(MMKVStorage storage) {
    _storage = storage;
    _protection = AtRestEncryptionService.memoryOnly(_testProtectionKey);
  }

  @visibleForTesting
  void debugResetStorage() {
    _storage = MMKVStorage();
    _protection = AtRestEncryptionService();
  }

  /// Maximum number of messages to cache per session.
  /// Keep the persisted copy bounded to the recent window used by the
  /// sync save path so cold-start JSON decode and initial rendering stay
  /// predictable.
  static const int _maxCachedMessages = 200;
  // Reads are synchronous on the main isolate (getMessages), so a 50ms+
  // read is genuinely user-visible (it blocks cold-start render) and
  // worth flagging.
  static const int _slowCacheReadMs = 50;
  // Writes run off the main isolate via compute() on the hot path
  // (saveMessagesAsync), so a 50-100ms write does not jank the UI. The
  // previous 50ms threshold flooded telemetry (~280 benign entries/6h);
  // 150ms keeps the signal for genuinely slow persistence only.
  static const int _slowCacheWriteMs = 150;

  /// Maximum number of sessions to keep in cache on web.
  ///
  /// localStorage / IndexedDB quota on web is much tighter than native
  /// MMKV. Keeping only the most recently accessed sessions avoids
  /// QuotaExceededError for users with many active sessions.
  static const int _maxWebSessions = 3;

  /// LRU order for cached sessions on web. The last entry is the most
  /// recently used.
  final List<String> _webSessionLru = [];

  /// Whether the LRU list has been seeded with sessions already present
  /// in storage. The merge happens once per process to avoid scanning
  /// the full cached-session set on every save (hot path).
  bool _webLruSeeded = false;

  /// Per-session content hash of the last persisted tail. Used to skip
  /// redundant MMKV writes when the message list hasn't changed.
  final Map<String, int> _lastSavedHash = {};

  /// Latest queued snapshot per session, awaiting background encode.
  final Map<String, _PendingCacheSave> _pendingSaves = {};

  /// Snapshot currently being prepared by the single worker.
  final Map<String, _PendingCacheSave> _inFlightSaves = {};

  /// Whether the queue drain loop is currently running. Guarantees a
  /// single in-flight encode isolate across all sessions.
  bool _draining = false;

  /// Monotonic counter handing out [_PendingCacheSave.seq] values.
  int _saveSeq = 0;

  /// Highest write sequence actually committed per session.
  final Map<String, int> _committedSeq = {};

  /// Get cached messages for a session synchronously.
  ///
  /// Returns empty list if no cache exists (not null). This enables
  /// zero-delay UI rendering on cold starts.
  List<Map<String, dynamic>> getMessages(String sessionId) {
    final stopwatch = Stopwatch()..start();
    final cached = _storage.getSessionMessages(sessionId);
    return _processCachedMessages(
      sessionId,
      cached,
      storedWasProtected: _isProtectedCacheMarker(cached),
      elapsedMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Async cache read for web IndexedDB-backed message blobs.
  ///
  /// The sync [getMessages] path remains the fastest option when the cache
  /// is already in memory. On web cold starts, message blobs are intentionally
  /// skipped during storage initialization, so callers that can await should
  /// use this method to load the selected session on demand.
  Future<List<Map<String, dynamic>>> getMessagesAsync(String sessionId) async {
    final stopwatch = Stopwatch()..start();
    final cached = await _storage.getSessionMessagesAsync(sessionId);
    return _processCachedMessages(
      sessionId,
      cached,
      storedWasProtected: _isProtectedCacheMarker(cached),
      elapsedMs: stopwatch.elapsedMilliseconds,
    );
  }

  List<Map<String, dynamic>> _processCachedMessages(
    String sessionId,
    List<Map<String, dynamic>> cached, {
    required bool storedWasProtected,
    required int elapsedMs,
  }) {
    final decoded = _decodeStoredCache(sessionId, cached);
    if (decoded == null) return <Map<String, dynamic>>[];
    var messages = _trimToCacheWindow(decoded);

    if (storedWasProtected && messages.length != decoded.length) {
      _rewriteTrimmedCache(sessionId, messages, originalCount: decoded.length);
    }

    // Scrub legacy `_orphanRecovery: true` synthetic Task tiles that
    // were persisted before the cache-write strip was introduced
    // (commit 53475ce3, May 9 2026).  Old installs can keep showing
    // the ghost tile forever otherwise.  When we actually strip
    // something, rewrite the cleaned list back to MMKV so the next
    // read is free.
    final scrubbed = stripOrphanSynthetics(messages);
    if (!identical(scrubbed, messages)) {
      if (storedWasProtected) {
        _rewriteScrubbedCache(sessionId, scrubbed);
      }
      messages = scrubbed;
    }

    if (messages.isNotEmpty && kIsWeb) {
      _touchWebLru(sessionId);
    }

    // Seed the dirty-tracking hash from what storage already holds so a
    // cold start that restores N sessions does not immediately rewrite
    // all N cache windows with byte-identical content.
    if (messages.isNotEmpty && !_lastSavedHash.containsKey(sessionId)) {
      _lastSavedHash[sessionId] = _computeCacheWindowHash(messages);
    }

    if (!storedWasProtected && cached.isNotEmpty) {
      _rewriteProtectedCache(
        sessionId,
        messages,
        reason: 'legacy plaintext migration',
      );
    }

    // Emit the read span for EVERY read, hit or miss. Emitting it only on
    // slow reads made the metric self-selecting: the dashboard could not tell
    // "cache is fast" from "cache is never read", and misses were invisible.
    OpenTelemetryService()
        .startTrace(
          'cache.messages.read',
          attributes: {
            'session.id': sessionId,
            'message.count': messages.length,
            'cache.elapsed_ms': elapsedMs,
            'cache.hit': messages.isNotEmpty,
            'cache.slow': elapsedMs >= _slowCacheReadMs,
          },
        )
        ?.end();

    if (messages.isEmpty) {
      return [];
    }

    if (elapsedMs >= _slowCacheReadMs) {
      logger.debug(
        '[MessageCache] Slow cache hit for session $sessionId: '
        '${messages.length} messages in ${elapsedMs}ms',
      );
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'MessageCache: slow cache hit',
          category: 'cache.messages',
          level: SentryLevel.info,
          data: {
            'sessionId': sessionId,
            'messageCount': messages.length,
            'elapsedMs': elapsedMs,
          },
        ),
      );
    }
    return messages;
  }

  bool _isProtectedCacheMarker(List<Map<String, dynamic>> cached) =>
      cached.length == 1 && cached.single[_cacheCiphertextMarker] is String;

  List<Map<String, dynamic>>? _decodeStoredCache(
    String sessionId,
    List<Map<String, dynamic>> cached,
  ) {
    if (!_isProtectedCacheMarker(cached)) {
      if (!_protection.isReady && cached.isNotEmpty) {
        // Never retain legacy sensitive plaintext when the device key is
        // unavailable. The server remains the source of truth.
        _storage.clearSessionMessages(sessionId);
        return null;
      }
      return cached;
    }
    final protected = cached.single[_cacheCiphertextMarker]! as String;
    if (!_protection.isReady) {
      // A temporary secure-storage failure is not corruption. Keep the
      // ciphertext so a later read can recover it after key initialization.
      return null;
    }
    final plaintext = _protection.unprotectString(
      protected,
      associatedData: _cacheAssociatedData(sessionId),
    );
    if (plaintext == null) {
      // Authentication failure, missing key, or corrupt envelope. Delete the
      // cache rather than treating ciphertext as a message row.
      _storage.clearSessionMessages(sessionId);
      return null;
    }
    try {
      final decoded = jsonDecode(plaintext);
      if (decoded is! List<dynamic>) {
        throw const FormatException('cache root is not a list');
      }
      return <Map<String, dynamic>>[
        for (final item in decoded)
          if (item is Map<String, dynamic>)
            Map<String, dynamic>.from(item)
          else
            throw const FormatException('cache row is not an object'),
      ];
    } catch (error) {
      logger.warning(
        '[MessageCache] Decrypted cache was malformed for $sessionId: $error',
      );
      _storage.clearSessionMessages(sessionId);
      return null;
    }
  }

  String _cacheAssociatedData(String sessionId) =>
      'message-cache:v1:$sessionId';

  /// Updates the LRU list for web, evicting the oldest session(s) if
  /// the number of cached sessions exceeds [_maxWebSessions].
  void _touchWebLru(String sessionId) {
    _webSessionLru
      ..remove(sessionId)
      ..add(sessionId);
    _evictWebOverflow();
  }

  /// Removes the least-recently-used sessions from the cache until the
  /// number of cached sessions is within [_maxWebSessions].
  void _evictWebOverflow() {
    // Seed the LRU once with sessions that exist in storage from a
    // previous run. Subsequent saves only touch the in-memory list.
    if (!_webLruSeeded) {
      final stored = _storage.getCachedSessionIds();
      for (final sid in stored) {
        if (!_webSessionLru.contains(sid)) {
          _webSessionLru.insert(0, sid);
        }
      }
      _webLruSeeded = true;
    }

    while (_webSessionLru.length > _maxWebSessions) {
      final oldest = _webSessionLru.removeAt(0);
      _storage.clearSessionMessages(oldest);
      logger.warning(
        '[MessageCache] Web quota guard: evicted session $oldest '
        '(keeping ${_webSessionLru.length}/$_maxWebSessions sessions)',
      );
    }
  }

  /// Save messages to cache.
  ///
  /// Only saves the last N messages to keep cache size bounded.
  /// Messages are persisted synchronously for instant recall.
  ///
  /// On web, the LRU session list is updated and any sessions beyond
  /// [_maxWebSessions] are evicted to prevent QuotaExceededError.
  void saveMessages(String sessionId, List<Map<String, dynamic>> messages) {
    // A synchronous save is the durability path (suspend/background
    // flush): it supersedes any queued snapshot for the session, which
    // may never get its encode isolate before the process is killed.
    _pendingSaves.remove(sessionId)?.complete();
    final seq = ++_saveSeq;
    final prepared = _prepareMessageCacheWindow(messages);
    if (_lastSavedHash[sessionId] == prepared.hash) {
      _committedSeq[sessionId] = seq;
      return;
    }
    if (kIsWeb) {
      _touchWebLru(sessionId);
    }

    final writeWatch = Stopwatch()..start();
    try {
      if (!_writeProtectedCache(sessionId, prepared.messages)) return;
      _commitWrite(sessionId, hash: prepared.hash, seq: seq);
      _recordWrite(
        sessionId,
        savedCount: prepared.messages.length,
        originalCount: prepared.originalCount,
        prepareMs: prepared.prepareMs,
        queueMs: 0,
        encodeMs: 0,
        writeMs: writeWatch.elapsedMilliseconds,
      );
    } catch (e) {
      _recordWriteFailure(sessionId, e, writeWatch.elapsedMilliseconds);
    }
  }

  Future<void> saveMessagesAsync(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) {
    final save = _PendingCacheSave(messages: messages, seq: ++_saveSeq);

    // Latest snapshot wins: the superseded one is resolved immediately
    // because the newer write subsumes its content.
    _pendingSaves.remove(sessionId)?.complete();
    _pendingSaves[sessionId] = save;
    if (kIsWeb) {
      _touchWebLru(sessionId);
    }
    _kickDrain();
    return save.completer.future;
  }

  /// Synchronously persist every cache save owned by this service, plus
  /// sessions whose Sync debounce timer has not fired yet.
  void flushPendingMessages(
    Map<String, List<Map<String, dynamic>>> latestMessages, {
    Iterable<String> additionalSessionIds = const <String>[],
  }) {
    final sessionIds = <String>{
      ..._pendingSaves.keys,
      ..._inFlightSaves.keys,
      ...additionalSessionIds,
    };
    for (final sessionId in sessionIds) {
      final messages = latestMessages[sessionId];
      if (messages != null) saveMessages(sessionId, messages);
    }
  }

  void _kickDrain() {
    if (_draining) return;
    _draining = true;
    unawaited(_drainPendingSaves());
  }

  /// Serialize every queued snapshot through a single encode isolate.
  ///
  /// Running one at a time keeps two chatty sessions from spawning two
  /// concurrent `compute()` isolates that each deep-copy their whole
  /// cache window off the UI isolate at the same time.
  Future<void> _drainPendingSaves() async {
    try {
      while (_pendingSaves.isNotEmpty) {
        final sessionId = _pendingSaves.keys.first;
        final save = _pendingSaves.remove(sessionId)!;
        _inFlightSaves[sessionId] = save;
        await _runQueuedSave(sessionId, save);
        if (identical(_inFlightSaves[sessionId], save)) {
          _inFlightSaves.remove(sessionId);
        }
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _runQueuedSave(String sessionId, _PendingCacheSave save) async {
    final queueMs = save.queueWatch.elapsedMilliseconds;
    final workerWatch = Stopwatch()..start();
    try {
      if (!_protection.isReady) {
        try {
          await _protection.initialize();
        } catch (error) {
          logger.warning(
            '[MessageCache] Device protection key unavailable; '
            'skipping async cache write for $sessionId: $error',
          );
          return;
        }
      }
      final protectionKey = _protection.copyKeyForWorker();
      if (protectionKey == null) {
        logger.warning(
          '[MessageCache] Device protection key unavailable; '
          'skipping async cache write for $sessionId',
        );
        return;
      }
      late Map<String, dynamic> result;
      try {
        result = await compute(_prepareAndProtectMessageCacheJson, {
          'messages': save.messages,
          'associatedData': _cacheAssociatedData(sessionId),
          'protectionKey': protectionKey,
        });
      } finally {
        // Native compute copies this buffer; web compute may share it.
        protectionKey.fillRange(0, protectionKey.length, 0);
      }
      final workerMs = workerWatch.elapsedMilliseconds;
      // A newer snapshot arrived, or a synchronous flush / clear already
      // wrote fresher state while we were encoding — drop the stale
      // write instead of clobbering it.
      if (_pendingSaves.containsKey(sessionId) ||
          (_committedSeq[sessionId] ?? 0) > save.seq) {
        return;
      }
      final hash = result['hash'] as int;
      final prepareMs = result['prepareMs'] as int;
      final encodeMs = workerMs > prepareMs ? workerMs - prepareMs : 0;
      if (_lastSavedHash[sessionId] == hash) {
        _commitWrite(sessionId, hash: hash, seq: save.seq);
        return;
      }
      final writeWatch = Stopwatch()..start();
      final marker = result['encodedMarker'] as String?;
      if (marker == null) {
        logger.warning(
          '[MessageCache] Worker failed to protect payload; '
          'skipping async cache write for $sessionId',
        );
        return;
      }
      _storage.saveSessionMessagesEncoded(sessionId, marker);
      _commitWrite(sessionId, hash: hash, seq: save.seq);
      _recordWrite(
        sessionId,
        savedCount: result['savedCount'] as int,
        originalCount: result['originalCount'] as int,
        prepareMs: prepareMs,
        queueMs: queueMs,
        encodeMs: encodeMs,
        writeMs: writeWatch.elapsedMilliseconds,
      );
    } catch (e) {
      _recordWriteFailure(sessionId, e, workerWatch.elapsedMilliseconds);
    } finally {
      save.complete();
    }
  }

  void _commitWrite(String sessionId, {required int hash, required int seq}) {
    _lastSavedHash[sessionId] = hash;
    _committedSeq[sessionId] = seq;
  }

  void _recordWrite(
    String sessionId, {
    required int savedCount,
    required int originalCount,
    required int prepareMs,
    required int queueMs,
    required int encodeMs,
    required int writeMs,
  }) {
    final elapsedMs = prepareMs + queueMs + encodeMs + writeMs;
    if (elapsedMs < _slowCacheWriteMs) return;
    logger.debug(
      '[MessageCache] Slow save for session $sessionId: '
      '$savedCount/$originalCount messages in '
      '${elapsedMs}ms (prepare ${prepareMs}ms, queue ${queueMs}ms, '
      'encode ${encodeMs}ms, write ${writeMs}ms)',
    );
    final truncated = originalCount > _maxCachedMessages;
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'MessageCache: slow save',
          category: 'cache.messages',
          level: SentryLevel.info,
          data: {
            'sessionId': sessionId,
            'savedCount': savedCount,
            'originalCount': originalCount,
            'truncated': truncated,
            'elapsedMs': elapsedMs,
            'prepareMs': prepareMs,
            'queueMs': queueMs,
            'encodeMs': encodeMs,
            'writeMs': writeMs,
          },
        ),
      ),
    );
    OpenTelemetryService()
        .startTrace(
          'cache.messages.write',
          attributes: {
            'session.id': sessionId,
            'message.saved_count': savedCount,
            'message.original_count': originalCount,
            'cache.truncated': truncated,
            'cache.elapsed_ms': elapsedMs,
            // Async saves prepare + encode in the worker; synchronous
            // suspend saves prepare + write on the UI isolate.
            'cache.prepare_ms': prepareMs,
            'cache.queue_ms': queueMs,
            'cache.encode_ms': encodeMs,
            'cache.write_ms': writeMs,
          },
        )
        ?.end();
  }

  void _recordWriteFailure(String sessionId, Object error, int elapsedMs) {
    logger.warning(
      '[MessageCache] Failed to save cache for $sessionId: $error',
    );
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'MessageCache: save failed',
          category: 'cache.messages',
          level: SentryLevel.warning,
          data: {
            'sessionId': sessionId,
            'error': error.toString(),
            'elapsedMs': elapsedMs,
          },
        ),
      ),
    );
    final span = OpenTelemetryService().startTrace(
      'cache.messages.write',
      attributes: {'session.id': sessionId, 'cache.elapsed_ms': elapsedMs},
    );
    span?.recordError(error);
    span?.end(ok: false);
  }

  static List<Map<String, dynamic>> _trimToCacheWindow(
    List<Map<String, dynamic>> messages,
  ) {
    if (messages.length <= _maxCachedMessages) return messages;
    return messages.sublist(messages.length - _maxCachedMessages);
  }

  void _rewriteTrimmedCache(
    String sessionId,
    List<Map<String, dynamic>> messages, {
    required int originalCount,
  }) {
    try {
      if (!_writeProtectedCache(sessionId, messages)) return;
      _markPersisted(sessionId, messages);
      logger.debug(
        '[MessageCache] Trimmed legacy cache for session $sessionId '
        'from $originalCount to ${messages.length} messages',
      );
    } catch (e) {
      logger.warning(
        '[MessageCache] Failed to trim legacy cache for $sessionId: $e',
      );
    }
  }

  /// Rewrites a session cache that had stale `_orphanRecovery: true`
  /// synthetic Task tiles scrubbed.  Updates [_lastSavedHash] so the
  /// next save-path check sees the cleaned hash and does not redo work.
  void _rewriteScrubbedCache(
    String sessionId,
    List<Map<String, dynamic>> cleaned,
  ) {
    try {
      if (!_writeProtectedCache(sessionId, cleaned)) return;
      _markPersisted(sessionId, cleaned);
      logger.debug(
        '[MessageCache] Scrubbed stale orphan synthetics for session '
        '$sessionId (now ${cleaned.length} messages)',
      );
    } catch (e) {
      logger.warning(
        '[MessageCache] Failed to scrub legacy synthetics for $sessionId: $e',
      );
    }
  }

  void _rewriteProtectedCache(
    String sessionId,
    List<Map<String, dynamic>> messages, {
    required String reason,
  }) {
    try {
      if (!_writeProtectedCache(sessionId, messages)) {
        _storage.clearSessionMessages(sessionId);
        return;
      }
      logger.info('[MessageCache] Completed $reason for $sessionId');
    } catch (error) {
      logger.warning('[MessageCache] Failed $reason for $sessionId: $error');
      _storage.clearSessionMessages(sessionId);
    }
  }

  bool _writeProtectedCache(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) {
    final marker = _protectedCacheMarker(sessionId, jsonEncode(messages));
    if (marker == null) {
      logger.warning(
        '[MessageCache] Device protection key unavailable; '
        'skipping cache write for $sessionId',
      );
      return false;
    }
    _storage.saveSessionMessagesEncoded(sessionId, marker);
    return true;
  }

  String? _protectedCacheMarker(String sessionId, String plaintextJson) {
    final protected = _protection.protectString(
      plaintextJson,
      associatedData: _cacheAssociatedData(sessionId),
    );
    if (protected == null) return null;
    return jsonEncode(<Map<String, dynamic>>[
      <String, dynamic>{_cacheCiphertextMarker: protected},
    ]);
  }

  /// Record that [messages] is exactly what storage now holds for
  /// [sessionId], so the next save with identical content is skipped and
  /// any encode still in flight from before this point is discarded.
  void _markPersisted(String sessionId, List<Map<String, dynamic>> messages) {
    _lastSavedHash[sessionId] = _computeCacheWindowHash(messages);
    _committedSeq[sessionId] = ++_saveSeq;
  }

  /// Compute a lightweight hash of the persisted cache window.
  static int _computeCacheWindowHash(List<Map<String, dynamic>> messages) {
    if (messages.isEmpty) return 0;
    var hash = messages.length;
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final id = m['id'];
      final seq = m['seq'];
      final state = m['state'];
      final sendStatus = m['sendStatus'];
      final content = m['content'];
      final contentHash = _contentFingerprint(content);
      hash = _combineHash(hash, _contentFingerprint(id));
      hash = _combineHash(hash, _contentFingerprint(seq));
      hash = _combineHash(hash, _contentFingerprint(state));
      hash = _combineHash(hash, _contentFingerprint(sendStatus));
      hash = _combineHash(hash, contentHash);
    }
    return hash;
  }

  /// Bounded fingerprint for message content.
  ///
  /// Tool outputs and large assistant responses can be megabytes; hashing
  /// the full value on every save would dominate the CPU budget.
  static int _contentFingerprint(Object? content) {
    return switch (content) {
      final String text =>
        text.length <= _cacheContentThreshold
            ? _hashString(text)
            : _combineHashes(<int>[
                text.length,
                _hashString(text.substring(0, _cacheContentSample)),
                _hashString(text.substring(text.length - _cacheContentSample)),
              ]),
      final List<dynamic> list =>
        list.length > _cacheCollectionThreshold
            ? _combineHashes(<int>[
                list.length,
                _contentFingerprint(list.firstOrNull),
                _contentFingerprint(list.lastOrNull),
              ])
            : _combineHashes(<int>[
                list.length,
                ...list.map(_contentFingerprint),
              ]),
      final Map<dynamic, dynamic> map => _fingerprintMap(map),
      final num number => number.hashCode,
      final bool value => value ? 1 : 2,
      null => 0,
      _ => _hashString(content.toString()),
    };
  }

  static int _fingerprintMap(Map<dynamic, dynamic> map) {
    var hash = map.length;
    var visited = 0;
    for (final entry in map.entries) {
      if (visited >= _cacheCollectionThreshold) break;
      hash = _combineHash(hash, _contentFingerprint(entry.key));
      hash = _combineHash(hash, _contentFingerprint(entry.value));
      visited++;
    }
    return hash;
  }

  static int _hashString(String value) {
    var hash = value.length;
    for (final codeUnit in value.codeUnits) {
      hash = _combineHash(hash, codeUnit);
    }
    return hash;
  }

  static int _combineHashes(Iterable<int> values) {
    var hash = 0;
    for (final value in values) {
      hash = _combineHash(hash, value);
    }
    return hash;
  }

  // Stay within 29 bits so the result is identical on native Dart and web.
  static int _combineHash(int hash, int value) =>
      0x1fffffff & (hash * 31 + value);

  static const int _cacheContentThreshold = 256;
  static const int _cacheContentSample = 128;
  static const int _cacheCollectionThreshold = 16;

  /// Clear cached messages for a session.
  ///
  /// Call when a session is deleted or cleared.
  void clearMessages(String sessionId) {
    // Drop any queued snapshot and fence in-flight encodes: a delete
    // must not be undone by a background write that was already
    // encoding when the session was cleared.
    _pendingSaves.remove(sessionId)?.complete();
    _committedSeq[sessionId] = ++_saveSeq;
    try {
      _storage.clearSessionMessages(sessionId);
      _lastSavedHash.remove(sessionId);
      logger.debug('[MessageCache] Cleared cache for session $sessionId');
    } catch (e) {
      logger.warning('[MessageCache] Failed to clear cache for $sessionId: $e');
    }
  }

  /// Check if a session has cached messages.
  bool hasCachedMessages(String sessionId) {
    final cached = _storage.getSessionMessages(sessionId);
    return cached.isNotEmpty;
  }

  /// Get the approximate cache size as message count for a session.
  int? getCacheSize(String sessionId) {
    final cached = _storage.getSessionMessages(sessionId);
    if (cached.isEmpty) return null;
    return cached.length;
  }

  /// Replace any `_orphanRecovery: true` synthetic Task with its
  /// flattened children before persisting to disk.
  ///
  /// Persisting the synthetic shape would lock the corruption into
  /// MMKV: a subsequent cold-start would restore synthetics-as-Tasks,
  /// never re-attaching the children to the real Task that arrives
  /// later.
  ///
  /// Children are reset to top-level `isSidechain: true` entries; on
  /// restore the grouper either re-attaches them to the real Task
  /// (when the parent is in the cache window) or re-absorbs them
  /// into a fresh synthetic.  Either outcome is safe; the persisted
  /// synthetic shape is not.
  ///
  /// Returns the same list instance unchanged when no synthetics are
  /// present, so callers can use `identical(out, in)` to detect a
  /// no-op cheaply.
  static List<Map<String, dynamic>> stripOrphanSynthetics(
    List<Map<String, dynamic>> messages,
  ) {
    var hasSynthetic = false;
    for (final m in messages) {
      if (m['_orphanRecovery'] == true) {
        hasSynthetic = true;
        break;
      }
    }
    if (!hasSynthetic) return messages;

    final out = <Map<String, dynamic>>[];
    for (final m in messages) {
      if (m['_orphanRecovery'] == true) {
        final children = m['children'] as List<dynamic>?;
        if (children != null) {
          for (final c in children) {
            if (c is Map<String, dynamic>) {
              if (c['isSidechain'] != true) {
                out.add(<String, dynamic>{...c, 'isSidechain': true});
              } else {
                out.add(c);
              }
            }
          }
        }
        continue;
      }
      out.add(m);
    }
    return out;
  }

  @visibleForTesting
  static List<Map<String, dynamic>> trimForTesting(
    List<Map<String, dynamic>> messages,
  ) => _trimToCacheWindow(messages);
}
