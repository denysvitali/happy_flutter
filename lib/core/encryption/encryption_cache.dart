import '../utils/lru_cache.dart';
import 'json_text.dart';

/// LRU cache entry with access time tracking for legacy compatibility
class CacheEntry<T> {
  CacheEntry(this.data, [int? accessTime])
    : accessTime = accessTime ?? DateTime.now().millisecondsSinceEpoch;
  final T data;
  final int accessTime;
}

/// In-memory cache for decrypted data to avoid expensive re-decryption
///
/// Uses O(1) LRU eviction instead of O(n) scan for better performance.
class EncryptionCache {
  EncryptionCache() {
    _agentStateCache = LRUCache(
      maxAgentStates,
      sizeOf: estimateJsonBytes,
      maxBytes: agentStateByteBudget,
    );
    _metadataCache = LRUCache(
      maxMetadata,
      sizeOf: estimateJsonBytes,
      maxBytes: metadataByteBudget,
    );
    _messageCache = LRUCache(
      maxMessages,
      sizeOf: (m) => estimateJsonBytes(m.content),
      maxBytes: messageByteBudget,
    );
    _machineMetadataCache = LRUCache(
      maxMachineMetadata,
      sizeOf: estimateJsonBytes,
      maxBytes: machineMetadataByteBudget,
    );
    _daemonStateCache = LRUCache(
      maxDaemonStates,
      sizeOf: (v) => v is Map<String, dynamic> ? estimateJsonBytes(v) : 64,
      maxBytes: daemonStateByteBudget,
    );
  }

  // Configuration
  static const int maxAgentStates = 1000;
  static const int maxMetadata = 1000;
  static const int maxMessages = 1000;
  static const int maxMachineMetadata = 500;
  static const int maxDaemonStates = 500;

  // Retained-byte ceilings per map. Count caps alone let every version bump
  // of a streaming session insert another multi-KB agent-state JSON until the
  // LRU turns over — a heap ratchet that grows GC pauses over a long day
  // (progressive-lag audit, second sweep 2026-08-24).
  static const int agentStateByteBudget = 4 * 1024 * 1024;
  static const int metadataByteBudget = 2 * 1024 * 1024;
  static const int messageByteBudget = 8 * 1024 * 1024;
  static const int machineMetadataByteBudget = 1024 * 1024;
  static const int daemonStateByteBudget = 4 * 1024 * 1024;

  /// Recursively estimates retained UTF-16 chars of [node] as bytes, with an
  /// early bail-out once [limit] is exceeded so typical small payloads cost
  /// O(own length). Used both for cache admission sizing and budget checks.
  static int estimateJsonBytes(Object? node, {int limit = 1 << 20}) {
    var total = 0;
    bool walk(Object? n) {
      if (n is String) {
        total += n.length * 2;
        return total >= limit;
      }
      if (n is List) {
        total += 16;
        for (final element in n) {
          if (walk(element)) return true;
        }
        return false;
      }
      if (n is Map) {
        total += 24;
        for (final key in n.keys) {
          total += '${key}'.length * 2;
          if (walk(n[key])) return true;
        }
        return false;
      }
      return false;
    }

    walk(node);
    return total;
  }

  late final LRUCache<String, Map<String, dynamic>> _agentStateCache;
  late final LRUCache<String, Map<String, dynamic>> _metadataCache;
  late final LRUCache<String, DecryptedMessage> _messageCache;
  late final LRUCache<String, Map<String, dynamic>> _machineMetadataCache;
  late final LRUCache<String, dynamic> _daemonStateCache;

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
  ///
  /// Oversized entries (huge tool outputs) are skipped: the LRU caps
  /// entries by COUNT, so 1000 cached multi-hundred-KB tool results pin
  /// tens of MB until evicted — a heap ratchet that grows GC pauses the
  /// longer the session runs (progressive-lag audit 2026-08-24). Re-decrypting
  /// a skipped message on refetch is cheap next to pinning it.
  void setCachedMessage(String messageId, DecryptedMessage data) {
    if (_exceedsContentBudget(data.content)) return;
    _messageCache.put(messageId, data);
  }

  /// Char budget above which a decrypted message is not cached.
  static const int maxCachedMessageChars = 50000;

  /// Recursively counts string chars in [content] with an early bail-out
  /// once the budget is exceeded, so typical small messages touch only
  /// their own length.
  static bool _exceedsContentBudget(Object? content) {
    var remaining = maxCachedMessageChars;
    bool walk(Object? node) {
      if (node is String) {
        remaining -= node.length;
        return remaining < 0;
      }
      if (node is JsonText) {
        remaining -= node.length;
        return remaining < 0;
      }
      if (node is List) {
        for (final element in node) {
          if (walk(element)) return true;
        }
        return false;
      }
      if (node is Map) {
        for (final value in node.values) {
          if (walk(value)) return true;
        }
        return false;
      }
      return false;
    }

    return walk(content);
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
      'totalEntries':
          _agentStateCache.length +
          _metadataCache.length +
          _messageCache.length +
          _machineMetadataCache.length +
          _daemonStateCache.length,
      'retainedBytes':
          _agentStateCache.retainedBytes +
          _metadataCache.retainedBytes +
          _messageCache.retainedBytes +
          _machineMetadataCache.retainedBytes +
          _daemonStateCache.retainedBytes,
    };
  }
}

/// Decrypted message model
class DecryptedMessage {
  DecryptedMessage({
    required this.id,
    required this.seq,
    required this.createdAt,
    this.localId,
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
