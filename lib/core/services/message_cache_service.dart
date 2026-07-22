import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show compute, kIsWeb, visibleForTesting;
import 'package:sentry_flutter/sentry_flutter.dart';

import '../utils/image_content_blocks.dart';
import 'logger_service.dart' show logger;
import 'mmkv_storage.dart';
import 'opentelemetry_service.dart';

String _encodeMessageCacheJson(List<Map<String, dynamic>> messages) {
  return jsonEncode(messages);
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
  final Map<String, int> _asyncSaveGeneration = {};

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
      OpenTelemetryService()
          .startTrace(
            'cache.messages.read',
            attributes: {
              'session.id': sessionId,
              'message.count': messages.length,
              'cache.elapsed_ms': elapsedMs,
            },
          )
          ?.end();
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
    _saveMessages(sessionId, messages, asyncWrite: false);
  }

  Future<void> saveMessagesAsync(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) {
    return _saveMessages(sessionId, messages, asyncWrite: true);
  }

  Future<void> _saveMessages(
    String sessionId,
    List<Map<String, dynamic>> messages, {
    required bool asyncWrite,
  }) async {
    final stopwatch = Stopwatch()..start();
    final trimmed = _trimToCacheWindow(messages);
    // Strip inline base64 image bytes before persisting: a chat with a
    // few screenshots would otherwise put multi-MB strings into MMKV
    // (and into the cache-window hash) for every save. Stripped blocks
    // keep their shape so restored rows render a placeholder, and the
    // retry path refuses to resend them (the pixels are gone).
    final toSave = trimmed.map(stripInlineImageData).toList();

    // Skip write when the cache-window hash is unchanged — avoids repeated
    // MMKV serialization of the same message list (e.g. 1200-message
    // saves taking ~131ms each).
    final hash = _computeCacheWindowHash(toSave);
    final prevHash = _lastSavedHash[sessionId];
    if (prevHash == hash && prevHash != null) {
      logger.debug(
        '[MessageCache] Skipping save for session $sessionId '
        '(hash unchanged: $hash)',
      );
      return;
    }

    // On web, evict stale sessions before writing so we never exceed
    // the quota guard.
    if (kIsWeb) {
      _touchWebLru(sessionId);
    }

    try {
      if (asyncWrite) {
        final generation = (_asyncSaveGeneration[sessionId] ?? 0) + 1;
        _asyncSaveGeneration[sessionId] = generation;
        final encoded = await compute(_encodeMessageCacheJson, toSave);
        if (_asyncSaveGeneration[sessionId] != generation) return;
        _storage.saveSessionMessagesEncoded(sessionId, encoded);
      } else {
        _storage.saveSessionMessages(sessionId, toSave);
      }
      _lastSavedHash[sessionId] = hash;
      final elapsedMs = stopwatch.elapsedMilliseconds;
      if (elapsedMs >= _slowCacheWriteMs) {
        logger.debug(
          '[MessageCache] Slow save for session $sessionId: '
          '${toSave.length}/${messages.length} messages in ${elapsedMs}ms',
        );
        unawaited(
          Sentry.addBreadcrumb(
            Breadcrumb(
              message: 'MessageCache: slow save',
              category: 'cache.messages',
              level: SentryLevel.info,
              data: {
                'sessionId': sessionId,
                'savedCount': toSave.length,
                'originalCount': messages.length,
                'truncated': messages.length > _maxCachedMessages,
                'elapsedMs': elapsedMs,
              },
            ),
          ),
        );
        OpenTelemetryService()
            .startTrace(
              'cache.messages.write',
              attributes: {
                'session.id': sessionId,
                'message.saved_count': toSave.length,
                'message.original_count': messages.length,
                'cache.truncated': messages.length > _maxCachedMessages,
                'cache.elapsed_ms': elapsedMs,
              },
            )
            ?.end();
      }
    } catch (e) {
      final elapsedMs = stopwatch.elapsedMilliseconds;
      logger.warning('[MessageCache] Failed to save cache for $sessionId: $e');
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'MessageCache: save failed',
            category: 'cache.messages',
            level: SentryLevel.warning,
            data: {
              'sessionId': sessionId,
              'error': e.toString(),
              'elapsedMs': elapsedMs,
            },
          ),
        ),
      );
      final span = OpenTelemetryService().startTrace(
        'cache.messages.write',
        attributes: {'session.id': sessionId, 'cache.elapsed_ms': elapsedMs},
      );
      span?.recordError(e);
      span?.end(ok: false);
    }
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
      _lastSavedHash[sessionId] = _computeCacheWindowHash(messages);
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
      _lastSavedHash[sessionId] = _computeCacheWindowHash(cleaned);
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
