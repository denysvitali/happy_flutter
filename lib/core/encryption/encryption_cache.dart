import 'dart:typed_data';

/// Cache entry with access time tracking
class CacheEntry<T> {
  final T data;
  int accessTime;

  CacheEntry(this.data, this.accessTime);
}

/// In-memory cache for decrypted data to avoid expensive re-decryption
class EncryptionCache {
  final _agentStateCache = <String, CacheEntry<Map<String, dynamic>>>{};
  final _metadataCache = <String, CacheEntry<Map<String, dynamic>>>{};
  final _messageCache = <String, CacheEntry<DecryptedMessage>>{};
  final _machineMetadataCache = <String, CacheEntry<Map<String, dynamic>>>{};
  final _daemonStateCache = <String, CacheEntry<dynamic>>{};

  // Configuration
  static const int maxAgentStates = 1000;
  static const int maxMetadata = 1000;
  static const int maxMessages = 1000;
  static const int maxMachineMetadata = 500;
  static const int maxDaemonStates = 500;

  /// Get cached agent state for a session
  Map<String, dynamic>? getCachedAgentState(String sessionId, int version) {
    final key = '$sessionId:$version';
    final entry = _agentStateCache[key];
    if (entry != null) {
      entry.accessTime = DateTime.now().millisecondsSinceEpoch;
      return entry.data;
    }
    return null;
  }

  /// Cache agent state for a session
  void setCachedAgentState(
    String sessionId,
    int version,
    Map<String, dynamic> data,
  ) {
    final key = '$sessionId:$version';
    _agentStateCache[key] = CacheEntry(
      data,
      DateTime.now().millisecondsSinceEpoch,
    );
    _evictOldest(_agentStateCache, maxAgentStates);
  }

  /// Get cached metadata for a session
  Map<String, dynamic>? getCachedMetadata(String sessionId, int version) {
    final key = '$sessionId:$version';
    final entry = _metadataCache[key];
    if (entry != null) {
      entry.accessTime = DateTime.now().millisecondsSinceEpoch;
      return entry.data;
    }
    return null;
  }

  /// Cache metadata for a session
  void setCachedMetadata(
    String sessionId,
    int version,
    Map<String, dynamic> data,
  ) {
    final key = '$sessionId:$version';
    _metadataCache[key] = CacheEntry(
      data,
      DateTime.now().millisecondsSinceEpoch,
    );
    _evictOldest(_metadataCache, maxMetadata);
  }

  /// Get cached decrypted message
  DecryptedMessage? getCachedMessage(String messageId) {
    final entry = _messageCache[messageId];
    if (entry != null) {
      entry.accessTime = DateTime.now().millisecondsSinceEpoch;
      return entry.data;
    }
    return null;
  }

  /// Cache decrypted message
  void setCachedMessage(String messageId, DecryptedMessage data) {
    _messageCache[messageId] = CacheEntry(
      data,
      DateTime.now().millisecondsSinceEpoch,
    );
    _evictOldest(_messageCache, maxMessages);
  }

  /// Get cached machine metadata
  Map<String, dynamic>? getCachedMachineMetadata(String machineId, int version) {
    final key = '$machineId:$version';
    final entry = _machineMetadataCache[key];
    if (entry != null) {
      entry.accessTime = DateTime.now().millisecondsSinceEpoch;
      return entry.data;
    }
    return null;
  }

  /// Cache machine metadata
  void setCachedMachineMetadata(
    String machineId,
    int version,
    Map<String, dynamic> data,
  ) {
    final key = '$machineId:$version';
    _machineMetadataCache[key] = CacheEntry(
      data,
      DateTime.now().millisecondsSinceEpoch,
    );
    _evictOldest(_machineMetadataCache, maxMachineMetadata);
  }

  /// Get cached daemon state
  dynamic getCachedDaemonState(String machineId, int version) {
    final key = '$machineId:$version';
    final entry = _daemonStateCache[key];
    if (entry != null) {
      entry.accessTime = DateTime.now().millisecondsSinceEpoch;
      return entry.data;
    }
    return null;
  }

  /// Cache daemon state (including null values)
  void setCachedDaemonState(String machineId, int version, dynamic data) {
    final key = '$machineId:$version';
    _daemonStateCache[key] = CacheEntry(
      data,
      DateTime.now().millisecondsSinceEpoch,
    );
    _evictOldest(_daemonStateCache, maxDaemonStates);
  }

  /// Clear all cache entries for a specific machine
  void clearMachineCache(String machineId) {
    _machineMetadataCache.keys
        .where((key) => key.startsWith('$machineId:'))
        .toList()
        .forEach((key) => _machineMetadataCache.remove(key));

    _daemonStateCache.keys
        .where((key) => key.startsWith('$machineId:'))
        .toList()
        .forEach((key) => _daemonStateCache.remove(key));
  }

  /// Clear all cache entries for a specific session
  void clearSessionCache(String sessionId) {
    _agentStateCache.keys
        .where((key) => key.startsWith('$sessionId:'))
        .toList()
        .forEach((key) => _agentStateCache.remove(key));

    _metadataCache.keys
        .where((key) => key.startsWith('$sessionId:'))
        .toList()
        .forEach((key) => _metadataCache.remove(key));
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

  /// Evict oldest entry (LRU eviction)
  void _evictOldest<T>(Map<String, CacheEntry<T>> cache, int maxSize) {
    if (cache.length <= maxSize) return;

    String? oldestKey;
    int oldestTime = 0x7FFFFFFFFFFFFFFF; // Max 64-bit int

    for (final entry in cache.entries) {
      if (entry.value.accessTime < oldestTime) {
        oldestTime = entry.value.accessTime;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      cache.remove(oldestKey);
    }
  }
}

/// Decrypted message model
class DecryptedMessage {
  final String id;
  final int seq;
  final String? localId;
  final dynamic content;
  final DateTime createdAt;

  DecryptedMessage({
    required this.id,
    required this.seq,
    this.localId,
    this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seq': seq,
      'localId': localId,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DecryptedMessage.fromJson(Map<String, dynamic> json) {
    return DecryptedMessage(
      id: json['id'] as String,
      seq: json['seq'] as int,
      localId: json['localId'] as String?,
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
