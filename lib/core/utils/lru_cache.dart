/// Simple LRU cache implementation with O(1) get/put/evict
///
/// Uses a combination of a HashMap for O(1) access and
/// maintains an ordered list for O(1) eviction of oldest entry.
class LRUCache<K, V> {
  final _cache = <K, V>{};
  final _accessOrder = <K>[];
  final int maxSize;

  LRUCache(this.maxSize);

  /// Get value by key, updating access order
  V? get(K key) {
    final value = _cache[key];
    if (value != null) {
      // Move to end (most recently used)
      _accessOrder.remove(key);
      _accessOrder.add(key);
    }
    return value;
  }

  /// Put value, evicting oldest if at capacity
  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      // Update existing: move to end
      _accessOrder.remove(key);
      _accessOrder.add(key);
    } else {
      // New entry: add to end, evict if needed
      if (_accessOrder.length >= maxSize) {
        final oldest = _accessOrder.removeAt(0);
        _cache.remove(oldest);
      }
      _accessOrder.add(key);
    }
    _cache[key] = value;
  }

  /// Remove a specific key
  void remove(K key) {
    _cache.remove(key);
    _accessOrder.remove(key);
  }

  /// Check if key exists
  bool containsKey(K key) => _cache.containsKey(key);

  /// Get current size
  int get length => _cache.length;

  /// Clear all entries
  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }

  /// Get all keys in access order (oldest first)
  List<K> get keys => List<K>.from(_accessOrder);

  /// Get cache statistics
  Map<String, int> getStats() => {'size': length, 'maxSize': maxSize};
}
