import 'package:sentry_flutter/sentry_flutter.dart';

import 'logger_service.dart' show logger;
import 'mmkv_storage.dart';

/// Local-first message cache service.
///
/// Provides instant access to cached messages while network fetches
/// happen in the background. Messages are persisted to MMKV for
/// immediate cold-start loads.
class MessageCacheService {
  factory MessageCacheService() => _instance;
  MessageCacheService._();
  static final MessageCacheService _instance = MessageCacheService._();

  /// Maximum number of messages to cache per session.
  /// Keep last ~200 messages which covers most conversation contexts.
  static const int _maxCachedMessages = 200;

  /// Get cached messages for a session synchronously.
  ///
  /// Returns empty list if no cache exists (not null). This enables
  /// zero-delay UI rendering on cold starts.
  List<Map<String, dynamic>> getMessages(String sessionId) {
    final stopwatch = Stopwatch()..start();
    final cached = MMKVStorage().getSessionMessages(sessionId);
    final elapsedMs = stopwatch.elapsedMilliseconds;

    if (cached.isEmpty) {
      logger.info('[MessageCache] Cache miss for session $sessionId');
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
    logger.info(
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

  /// Save messages to cache.
  ///
  /// Only saves the last N messages to keep cache size bounded.
  /// Messages are persisted synchronously for instant recall.
  void saveMessages(String sessionId, List<Map<String, dynamic>> messages) {
    final stopwatch = Stopwatch()..start();
    final toSave = messages.length > _maxCachedMessages
        ? messages.sublist(messages.length - _maxCachedMessages)
        : messages;
    try {
      MMKVStorage().saveSessionMessages(sessionId, toSave);
      final elapsedMs = stopwatch.elapsedMilliseconds;
      logger.info(
        '[MessageCache] Saved ${toSave.length} messages for session $sessionId '
        '(truncated from ${messages.length})',
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
      logger.info('[MessageCache] Cleared cache for session $sessionId');
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
