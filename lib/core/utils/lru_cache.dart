/// Simple LRU cache implementation with O(1) get/put/evict
///
/// Uses a [LinkedHashMap] where access-order is maintained by
/// removing and re-inserting entries on access.  All operations
/// (get, put/evict-oldest) are O(1).
///
/// An optional [sizeOf] turns on retained-byte accounting: every entry is
/// charged [sizeOf] bytes on insert, evictions subtract, and a [maxBytes]
/// budget evicts oldest-first until the cache fits. Count-only caps let
/// 1000 small-looking entries pin tens of MB when values are large —
/// byte budgets bound residency directly (progressive-lag audit
/// 2026-08-24).
class LRUCache<K, V> {
  LRUCache(this.maxSize, {this.sizeOf, this.maxBytes = 0});

  final _map = <K, V>{};
  final int maxSize;

  /// Estimates one entry's retained size in bytes. Null disables
  /// byte accounting.
  final int Function(V value)? sizeOf;

  /// Retained-byte ceiling; requires [sizeOf]. Zero disables the budget.
  final int maxBytes;

  int _bytes = 0;

  /// Total estimated bytes currently retained (0 without [sizeOf]).
  int get retainedBytes => _bytes;

  /// Get value by key, updating access order
  V? get(K key) {
    final value = _map.remove(key);
    if (value != null) {
      _map[key] = value; // re-insert at tail (most recent)
    }
    return value;
  }

  /// Put value, evicting oldest while at capacity or over [maxBytes].
  void put(K key, V value) {
    // remove() (not a bare map removal) so an overwrite subtracts the
    // previous entry's charge before adding the new one.
    remove(key);
    if (sizeOf != null) {
      _bytes += sizeOf!(value);
    }
    if (_map.length >= maxSize) {
      _evictOldest();
    }
    if (maxBytes > 0) {
      while (_bytes > maxBytes && _map.isNotEmpty) {
        _evictOldest();
      }
    }
    _map[key] = value;
  }

  /// Evict oldest (head) in O(1) using for-in instead of
  /// _map.keys.first (O(n)) — coverage: maxSize is always >= 1
  void _evictOldest() {
    for (final oldestKey in _map.keys) {
      final oldest = _map.remove(oldestKey);
      if (oldest != null && sizeOf != null) {
        _bytes -= sizeOf!(oldest);
      }
      break;
    }
  }

  /// Remove a specific key
  void remove(K key) {
    final removed = _map.remove(key);
    if (removed != null && sizeOf != null) {
      _bytes -= sizeOf!(removed);
    }
  }

  /// Check if key exists
  bool containsKey(K key) => _map.containsKey(key);

  /// Get current size
  int get length => _map.length;

  /// Clear all entries
  void clear() {
    _map.clear();
    _bytes = 0;
  }

  /// Get all keys in access order (oldest first)
  List<K> get keys => _map.keys.toList();

  /// Get cache statistics
  Map<String, int> getStats() => {
    'size': length,
    'maxSize': maxSize,
    'retainedBytes': _bytes,
  };
}
