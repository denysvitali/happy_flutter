import '../utils/lru_cache.dart';

/// LRU cache entry with access time tracking for legacy compatibility
class CacheEntry<T> {
  CacheEntry(this.data, [int? accessTime])
      : accessTime =
            accessTime ?? DateTime.now().millisecondsSinceEpoch;
  final T data;
  final int accessTime;
}

/// In-memory cache for decrypted data to avoid expensive re-decryption
///
/// Uses O(1) LRU eviction instead of O(n) scan for better performance.
class EncryptionCache {
  late final LRUCache<String, Map<String, dynamic>> _agentStateCache;
  late final LRUCache<String, Map<String, dynamic>> _metadataCache;
  late final LRUCache<String, DecryptedMessage> _messageCache;
  late final LRUCache<String, Map<String, dynamic>> _machineMetadataCache;
  late final LRUCache<String, dynamic> _daemonStateCache;

  // Configuration
  static const int maxAgentStates = 1000;
  static const int maxMetadata = 1000;
  static const int maxMessages = 1000;
  static const int maxMachineMetadata = 500;
  static const int maxDaemonStates = 500;

  EncryptionCache() {
    _agentStateCache = LRUCache(maxAgentStates);
    _metadataCache = LRUCache(maxMetadata);
    _messageCache = LRUCache(maxMessages);
    _machineMetadataCache = LRUCache(maxMachineMetadata);
    _daemonStateCache = LRUCache(maxDaemonStates);
  }

  /// Get cached agent state for a session
  Map<String, dynamic>? getCachedAgentState(String sessionId, int version) {
    final key = '$sessionId:$version';
    return _agentStateCache.get(key);
  }

  /// Cache agent state for a session
  void setCachedAgentState(
    String sessionId,
    int version,
    Map<String, dynamic> data,
  ) {
    final key = '$sessionId:$version';
    _agentStateCache.put(key, data);
  }

  /// Get cached metadata for a session
  Map<String, dynamic>? getCachedMetadata(String sessionId, int version) {
    final key = '$sessionId:$version';
    return _metadataCache.get(key);
  }

  /// Cache metadata for a session
  void setCachedMetadata(
    String sessionId,
    int version,
    Map<String, dynamic> data,
  ) {
    final key = '$sessionId:$version';
    _metadataCache.put(key, data);
  }

  /// Get cached decrypted message
  DecryptedMessage? getCachedMessage(String messageId) {
    return _messageCache.get(messageId);
  }

  /// Cache decrypted message
  void setCachedMessage(String messageId, DecryptedMessage data) {
    _messageCache.put(messageId, data);
  }

  /// Get cached machine metadata
  Map<String, dynamic>? getCachedMachineMetadata(
    String machineId,
    int version,
  ) {
    final key = '$machineId:$version';
    return _machineMetadataCache.get(key);
  }

  /// Cache machine metadata
  void setCachedMachineMetadata(
    String machineId,
    int version,
    Map<String, dynamic> data,
  ) {
    final key = '$machineId:$version';
    _machineMetadataCache.put(key, data);
  }

  /// Get cached daemon state
  dynamic getCachedDaemonState(String machineId, int version) {
    final key = '$machineId:$version';
    return _daemonStateCache.get(key);
  }

  /// Cache daemon state (including null values)
  void setCachedDaemonState(String machineId, int version, dynamic data) {
    final key = '$machineId:$version';
    _daemonStateCache.put(key, data);
  }

  /// Clear all cache entries for a specific machine
  void clearMachineCache(String machineId) {
    // Remove all entries matching the machineId prefix
    _machineMetadataCache.keys
        .where((key) => key.startsWith('$machineId:'))
        .forEach(_machineMetadataCache.remove);
    _daemonStateCache.keys
        .where((key) => key.startsWith('$machineId:'))
        .forEach(_daemonStateCache.remove);
  }

  /// Clear all cache entries for a specific session
  void clearSessionCache(String sessionId) {
    // Remove all entries matching the sessionId prefix
    _agentStateCache.keys
        .where((key) => key.startsWith('$sessionId:'))
        .forEach(_agentStateCache.remove);
    _metadataCache.keys
        .where((key) => key.startsWith('$sessionId:'))
        .forEach(_metadataCache.remove);
  }

  /// Clear all cached data
  void clearAll() {
    _agentStateCache.clear();
    _metadataCache.clear();
    _messageCache.clear();
    _machineMetadataCache.clear();
    _daemonStateCache.clear();
  }

  /// Get cache statistics for debugging
  Map<String, int> getStats() {
    return {
      'agentStates': _agentStateCache.length,
      'metadata': _metadataCache.length,
      'messages': _messageCache.length,
      'machineMetadata': _machineMetadataCache.length,
      'daemonStates': _daemonStateCache.length,
      'totalEntries': _agentStateCache.length +
          _metadataCache.length +
          _messageCache.length +
          _machineMetadataCache.length +
          _daemonStateCache.length,
    };
  }
}

/// Decrypted message model
class DecryptedMessage {

  DecryptedMessage({
    required this.id,
    required this.seq,
    required this.createdAt, this.localId,
    this.content,
  });

  factory DecryptedMessage.fromJson(Map<String, dynamic> json) {
    return DecryptedMessage(
      id: json['id'] as String,
      seq: json['seq'] as int,
      localId: json['localId'] as String?,
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
  final String id;
  final int seq;
  final String? localId;
  final dynamic content;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seq': seq,
      'localId': localId,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
