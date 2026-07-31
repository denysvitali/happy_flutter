import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show compute, kIsWeb, visibleForTesting;
import 'package:sentry_flutter/sentry_flutter.dart';

import '../utils/image_content_blocks.dart';
import 'logger_service.dart' show logger;
import 'mmkv_storage.dart';
import 'opentelemetry_service.dart';

/// Top-level isolate worker: encodes a prepared cache window to JSON.
///
/// Must stay top-level and take only sendable POD arguments — a closure
/// capturing `this` here reintroduces the "Isolate unsendable Future"
/// production bug (ROADMAP, 7b69d1b).
String _encodeMessageCacheJson(List<Map<String, dynamic>> messages) {
  return jsonEncode(messages);
}

/// A cache window prepared on the main isolate and queued for
/// background encoding + persistence.
///
/// Queuing (rather than firing one `compute()` per save) means at most
/// one encode isolate is alive at a time and a session that changes
/// again while its previous snapshot is still encoding supersedes it
/// instead of racing a second isolate.
class _PendingCacheSave {
  _PendingCacheSave({
    required this.messages,
    required this.originalCount,
    required this.hash,
    required this.seq,
    required this.prepareMs,
  });

  final List<Map<String, dynamic>> messages;
  final int originalCount;
  final int hash;

  /// Monotonic write order. A write whose [seq] is older than the last
  /// committed write for the session is dropped instead of clobbering
  /// fresher data (e.g. the synchronous suspend flush).
  final int seq;
  final int prepareMs;
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

  @visibleForTesting
  // ignore: avoid_setters_without_getters
  set debugSetStorage(MMKVStorage storage) => _storage = storage;

  @visibleForTesting
  void debugResetStorage() => _storage = MMKVStorage();

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
      elapsedMs: stopwatch.elapsedMilliseconds,
    );
  }

  List<Map<String, dynamic>> _processCachedMessages(
    String sessionId,
    List<Map<String, dynamic>> cached, {
    required int elapsedMs,
  }) {
    var messages = _trimToCacheWindow(cached);

    if (messages.length != cached.length) {
      _rewriteTrimmedCache(sessionId, messages, originalCount: cached.length);
    }

    // Scrub legacy `_orphanRecovery: true` synthetic Task tiles that
    // were persisted before the cache-write strip was introduced
    // (commit 53475ce3, May 9 2026).  Old installs can keep showing
    // the ghost tile forever otherwise.  When we actually strip
    // something, rewrite the cleaned list back to MMKV so the next
    // read is free.
    final scrubbed = stripOrphanSynthetics(messages);
    if (!identical(scrubbed, messages)) {
      _rewriteScrubbedCache(sessionId, scrubbed);
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

    final prepared = _prepareSave(sessionId, messages);
    if (prepared == null) return;

    final writeWatch = Stopwatch()..start();
    try {
      _storage.saveSessionMessages(sessionId, prepared.messages);
      _commitWrite(sessionId, prepared);
      _recordWrite(
        sessionId,
        prepared,
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
    final prepared = _prepareSave(sessionId, messages);
    if (prepared == null) return Future<void>.value();

    // Latest snapshot wins: the superseded one is resolved immediately
    // because the newer write subsumes its content.
    _pendingSaves.remove(sessionId)?.complete();
    _pendingSaves[sessionId] = prepared;
    _kickDrain();
    return prepared.completer.future;
  }

  /// Build the persisted cache window on the main isolate, or return
  /// `null` when the write can be skipped because nothing changed.
  _PendingCacheSave? _prepareSave(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) {
    final prepareWatch = Stopwatch()..start();
    final trimmed = _trimToCacheWindow(messages);
    // Strip inline base64 image bytes before persisting: a chat with a
    // few screenshots would otherwise put multi-MB strings into MMKV
    // (and into the cache-window hash) for every save. Stripped blocks
    // keep their shape so restored rows render a placeholder, and the
    // retry path refuses to resend them (the pixels are gone).
    final toSave = trimmed.map(stripInlineImageData).toList();

    // Skip write when the cache-window hash is unchanged — avoids
    // repeated MMKV serialization of the same message list. The queued
    // snapshot's hash wins over the last committed one so a rapid
    // change/revert while an encode is queued still reconciles.
    final hash = _computeCacheWindowHash(toSave);
    final prevHash =
        _pendingSaves[sessionId]?.hash ?? _lastSavedHash[sessionId];
    if (prevHash == hash && prevHash != null) {
      logger.debug(
        '[MessageCache] Skipping save for session $sessionId '
        '(hash unchanged: $hash)',
      );
      return null;
    }

    // On web, evict stale sessions before writing so we never exceed
    // the quota guard.
    if (kIsWeb) {
      _touchWebLru(sessionId);
    }

    return _PendingCacheSave(
      messages: toSave,
      originalCount: messages.length,
      hash: hash,
      seq: ++_saveSeq,
      prepareMs: prepareWatch.elapsedMilliseconds,
    );
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
        await _runQueuedSave(sessionId, save);
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _runQueuedSave(
    String sessionId,
    _PendingCacheSave save,
  ) async {
    final queueMs = save.queueWatch.elapsedMilliseconds;
    final encodeWatch = Stopwatch()..start();
    try {
      final encoded = await compute(_encodeMessageCacheJson, save.messages);
      final encodeMs = encodeWatch.elapsedMilliseconds;
      // A newer snapshot arrived, or a synchronous flush / clear already
      // wrote fresher state while we were encoding — drop the stale
      // write instead of clobbering it.
      if (_pendingSaves.containsKey(sessionId) ||
          (_committedSeq[sessionId] ?? 0) > save.seq) {
        return;
      }
      final writeWatch = Stopwatch()..start();
      _storage.saveSessionMessagesEncoded(sessionId, encoded);
      _commitWrite(sessionId, save);
      _recordWrite(
        sessionId,
        save,
        queueMs: queueMs,
        encodeMs: encodeMs,
        writeMs: writeWatch.elapsedMilliseconds,
      );
    } catch (e) {
      _recordWriteFailure(sessionId, e, encodeWatch.elapsedMilliseconds);
    } finally {
      save.complete();
    }
  }

  void _commitWrite(String sessionId, _PendingCacheSave save) {
    _lastSavedHash[sessionId] = save.hash;
    _committedSeq[sessionId] = save.seq;
  }

  void _recordWrite(
    String sessionId,
    _PendingCacheSave save, {
    required int queueMs,
    required int encodeMs,
    required int writeMs,
  }) {
    final elapsedMs = save.prepareMs + queueMs + encodeMs + writeMs;
    if (elapsedMs < _slowCacheWriteMs) return;
    logger.debug(
      '[MessageCache] Slow save for session $sessionId: '
      '${save.messages.length}/${save.originalCount} messages in '
      '${elapsedMs}ms (prepare ${save.prepareMs}ms, queue ${queueMs}ms, '
      'encode ${encodeMs}ms, write ${writeMs}ms)',
    );
    final truncated = save.originalCount > _maxCachedMessages;
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'MessageCache: slow save',
          category: 'cache.messages',
          level: SentryLevel.info,
          data: {
            'sessionId': sessionId,
            'savedCount': save.messages.length,
            'originalCount': save.originalCount,
            'truncated': truncated,
            'elapsedMs': elapsedMs,
            'prepareMs': save.prepareMs,
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
            'message.saved_count': save.messages.length,
            'message.original_count': save.originalCount,
            'cache.truncated': truncated,
            'cache.elapsed_ms': elapsedMs,
            // Split so the dashboard can tell UI-isolate cost
            // (prepare + write) from background encode + queue wait.
            'cache.prepare_ms': save.prepareMs,
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
      _storage.saveSessionMessages(sessionId, messages);
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
      _storage.saveSessionMessages(sessionId, cleaned);
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
      hash = Object.hash(hash, id, seq, state, sendStatus, contentHash);
    }
    return hash;
  }

  /// Bounded fingerprint for message content.
  ///
  /// Tool outputs and large assistant responses can be megabytes; hashing
  /// the full value on every save would dominate the CPU budget.
  static int _contentFingerprint(Object? content) {
    return switch (content) {
      final String text => text.length <= _cacheContentThreshold
          ? Object.hash(text.length, text.hashCode)
          : Object.hash(
              text.length,
              text.substring(0, _cacheContentSample).hashCode,
              text.substring(text.length - _cacheContentSample).hashCode,
            ),
      final List<dynamic> list => list.length > _cacheCollectionThreshold
          ? Object.hash(
              list.length,
              _contentFingerprint(list.firstOrNull),
              _contentFingerprint(list.lastOrNull),
            )
          : Object.hash(list.length, list.map(_contentFingerprint).join()),
      _ => content?.hashCode ?? 0,
    };
  }

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
