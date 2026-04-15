import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sentry_flutter/sentry_flutter.dart';

import 'logger_service.dart' show logger;
import 'mmkv_storage.dart';

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

  /// Maximum number of messages to cache per session.
  /// Matches the in-memory cap (3000) so cold starts don't lose
  /// messages that were visible before the app was killed.
  static const int _maxCachedMessages = 3000;

  /// Maximum number of sessions to keep in cache on web.
  ///
  /// localStorage / IndexedDB quota on web is much tighter than native
  /// MMKV. Keeping only the most recently accessed sessions avoids
  /// QuotaExceededError for users with many active sessions.
  static const int _maxWebSessions = 3;

  /// LRU order for cached sessions on web. The last entry is the most
  /// recently used.
  final List<String> _webSessionLru = [];

  /// Get cached messages for a session synchronously.
  ///
  /// Returns empty list if no cache exists (not null). This enables
  /// zero-delay UI rendering on cold starts.
  List<Map<String, dynamic>> getMessages(String sessionId) {
    final stopwatch = Stopwatch()..start();
    final cached = MMKVStorage().getSessionMessages(sessionId);
    final elapsedMs = stopwatch.elapsedMilliseconds;

    if (cached.isNotEmpty && kIsWeb) {
      _touchWebLru(sessionId);
    }

    if (cached.isEmpty) {
      logger.debug('[MessageCache] Cache miss for session $sessionId');
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'MessageCache: cache miss',
        category: 'cache.messages',
        level: SentryLevel.info,
        data: {
          'sessionId': sessionId,
          'elapsedMs': elapsedMs,
        },
      ));
      return [];
    }
    logger.debug(
      '[MessageCache] Cache hit for session $sessionId: '
      '${cached.length} messages',
    );
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'MessageCache: cache hit',
      category: 'cache.messages',
      level: SentryLevel.info,
      data: {
        'sessionId': sessionId,
        'messageCount': cached.length,
        'elapsedMs': elapsedMs,
      },
    ));
    return cached;
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
    // Merge in any sessions that exist in storage but are not yet
    // tracked in the LRU list (e.g. loaded from a previous run).
    final stored = MMKVStorage().getCachedSessionIds();
    for (final sid in stored) {
      if (!_webSessionLru.contains(sid)) {
        // Insert at the front so they are evicted first.
        _webSessionLru.insert(0, sid);
      }
    }

    while (_webSessionLru.length > _maxWebSessions) {
      final oldest = _webSessionLru.removeAt(0);
      MMKVStorage().clearSessionMessages(oldest);
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
    final stopwatch = Stopwatch()..start();
    final toSave = messages.length > _maxCachedMessages
        ? messages.sublist(messages.length - _maxCachedMessages)
        : messages;

    // On web, evict stale sessions before writing so we never exceed
    // the quota guard.
    if (kIsWeb) {
      _touchWebLru(sessionId);
    }

    try {
      MMKVStorage().saveSessionMessages(sessionId, toSave);
      final elapsedMs = stopwatch.elapsedMilliseconds;
      logger.debug(
        '[MessageCache] Saved ${toSave.length} messages for session '
        '$sessionId (truncated from ${messages.length})',
      );
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'MessageCache: saved messages',
        category: 'cache.messages',
        level: SentryLevel.info,
        data: {
          'sessionId': sessionId,
          'savedCount': toSave.length,
          'originalCount': messages.length,
          'truncated': messages.length > _maxCachedMessages,
          'elapsedMs': elapsedMs,
        },
      ));
    } catch (e) {
      final elapsedMs = stopwatch.elapsedMilliseconds;
      logger.warning('[MessageCache] Failed to save cache for $sessionId: $e');
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'MessageCache: save failed',
        category: 'cache.messages',
        level: SentryLevel.warning,
        data: {
          'sessionId': sessionId,
          'error': e.toString(),
          'elapsedMs': elapsedMs,
        },
      ));
    }
  }

  /// Clear cached messages for a session.
  ///
  /// Call when a session is deleted or cleared.
  void clearMessages(String sessionId) {
    try {
      MMKVStorage().clearSessionMessages(sessionId);
      logger.debug('[MessageCache] Cleared cache for session $sessionId');
    } catch (e) {
      logger.warning('[MessageCache] Failed to clear cache for $sessionId: $e');
    }
  }

  /// Check if a session has cached messages.
  bool hasCachedMessages(String sessionId) {
    final cached = MMKVStorage().getSessionMessages(sessionId);
    return cached.isNotEmpty;
  }

  /// Get the approximate cache size as message count for a session.
  int? getCacheSize(String sessionId) {
    final cached = MMKVStorage().getSessionMessages(sessionId);
    if (cached.isEmpty) return null;
    return cached.length;
  }
}
