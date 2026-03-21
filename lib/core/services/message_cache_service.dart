import 'mmkv_storage.dart';
import 'logger_service.dart' show logger;

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
    final cached = MMKVStorage().getSessionMessages(sessionId);
    if (cached.isEmpty) {
      logger.info('[MessageCache] Cache miss for session $sessionId');
      return [];
    }
    logger.info(
      '[MessageCache] Cache hit for session $sessionId: ${cached.length} messages',
    );
    return cached;
  }

  /// Save messages to cache.
  ///
  /// Only saves the last N messages to keep cache size bounded.
  /// Messages are persisted synchronously for instant recall.
  void saveMessages(String sessionId, List<Map<String, dynamic>> messages) {
    final toSave = messages.length > _maxCachedMessages
        ? messages.sublist(messages.length - _maxCachedMessages)
        : messages;
    try {
      MMKVStorage().saveSessionMessages(sessionId, toSave);
      logger.info(
        '[MessageCache] Saved ${toSave.length} messages for session $sessionId '
        '(truncated from ${messages.length})',
      );
    } catch (e) {
      logger.warning('[MessageCache] Failed to save cache for $sessionId: $e');
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
