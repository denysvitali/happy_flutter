import 'dart:collection';

/// Simple LRU cache implementation with O(1) get/put/evict
///
/// Uses a [LinkedHashMap] where access-order is maintained by
/// removing and re-inserting entries on access.  All operations
/// (get, put, remove, evict-oldest) are O(1).
class LRUCache<K, V> {
  final _map = LinkedHashMap<K, V>();
  final int maxSize;

  LRUCache(this.maxSize);

  /// Get value by key, updating access order
  V? get(K key) {
    final value = _map.remove(key);
    if (value != null) {
      _map[key] = value; // re-insert at tail (most recent)
    }
    return value;
  }

  /// Put value, evicting oldest if at capacity
  void put(K key, V value) {
    _map.remove(key); // remove existing to update position
    if (_map.length >= maxSize) {
      _map.remove(_map.keys.first); // evict oldest (head)
    }
    _map[key] = value;
  }

  /// Remove a specific key
  void remove(K key) {
    _map.remove(key);
  }

  /// Check if key exists
  bool containsKey(K key) => _map.containsKey(key);

  /// Get current size
  int get length => _map.length;

  /// Clear all entries
  void clear() {
    _map.clear();
  }

  /// Get all keys in access order (oldest first)
  List<K> get keys => _map.keys.toList();

  /// Get cache statistics
  Map<String, int> getStats() => {'size': length, 'maxSize': maxSize};
}
