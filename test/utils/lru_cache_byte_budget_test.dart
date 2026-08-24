import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/lru_cache.dart';

/// Byte-accounted LRU (progressive-lag audit, third pass 2026-08-24).
///
/// Count-only caps let 1000 small-looking entries pin tens of MB when
/// values are large; the byte budget bounds residency directly. These
/// tests pin the accounting invariants: charges on insert, subtractions on
/// every removal path, oldest-first eviction under budget pressure.
void main() {
  group('LRUCache byte accounting', () {
    test('charges sizeOf on put and reports retainedBytes', () {
      final cache = LRUCache<String, String>(10, sizeOf: (v) => v.length);
      cache.put('a', 'xxx');
      expect(cache.retainedBytes, 3);
      cache.put('b', 'yy');
      expect(cache.retainedBytes, 5);
    });

    test('overwrite subtracts the previous charge', () {
      final cache = LRUCache<String, String>(10, sizeOf: (v) => v.length);
      cache.put('a', 'xxxxx');
      cache.put('a', 'y');
      expect(cache.length, 1);
      expect(cache.retainedBytes, 1);
    });

    test('remove subtracts; remove of missing key is a no-op', () {
      final cache = LRUCache<String, String>(10, sizeOf: (v) => v.length);
      cache.put('a', 'xx');
      cache.remove('missing');
      expect(cache.retainedBytes, 2);
      cache.remove('a');
      expect(cache.retainedBytes, 0);
    });

    test('count eviction subtracts the evicted charge', () {
      final cache = LRUCache<String, String>(2, sizeOf: (v) => v.length);
      cache.put('a', 'xxx');
      cache.put('b', 'xxx');
      cache.put('c', 'xxx');
      expect(cache.length, 2);
      expect(cache.containsKey('a'), isFalse, reason: 'oldest is evicted');
      expect(cache.retainedBytes, 6);
    });

    test('maxBytes evicts oldest until the cache fits', () {
      final cache = LRUCache<String, String>(
        10,
        sizeOf: (v) => v.length,
        maxBytes: 5,
      );
      cache.put('a', 'xx'); // 2 bytes — fits
      expect(cache.retainedBytes, 2);
      cache.put('b', 'xxx'); // charged to 5 — still fits exactly
      expect(cache.keys, ['a', 'b']);
      cache.put('c', 'x'); // 6 > 5 → evict 'a' (2) → fits at 4
      expect(cache.keys, ['b', 'c']);
      expect(cache.retainedBytes, 4);
    });

    test('an entry larger than the whole budget is retained alone', () {
      final cache = LRUCache<String, String>(
        10,
        sizeOf: (v) => v.length,
        maxBytes: 4,
      );
      cache.put('big', 'xxxxxxxxxx');
      expect(cache.keys, ['big'], reason: 'single oversized entries are kept');
      expect(cache.retainedBytes, 10);

      cache.put('small', 'x');
      expect(cache.containsKey('big'), isFalse, reason: 'evicted to fit');
      expect(cache.retainedBytes, 1);
    });

    test('get refreshes recency so byte eviction follows LRU order', () {
      final cache = LRUCache<String, String>(
        10,
        sizeOf: (v) => v.length,
        maxBytes: 4,
      );
      cache.put('old', 'xx');
      cache.put('new', 'xx');
      cache.get('old'); // touch: 'new' is now the coldest
      cache.put('third', 'xx');
      expect(cache.containsKey('old'), isTrue);
      expect(cache.containsKey('new'), isFalse);
    });

    test('clear resets the byte counter', () {
      final cache = LRUCache<String, String>(10, sizeOf: (v) => v.length);
      cache.put('a', 'xxxx');
      cache.clear();
      expect(cache.retainedBytes, 0);
      expect(cache.getStats()['retainedBytes'], 0);
    });

    test('caches without sizeOf keep working and report zero bytes', () {
      final cache = LRUCache<String, String>(2);
      cache.put('a', 'anything');
      cache.put('b', 'more');
      cache.put('c', 'overflow');
      expect(cache.retainedBytes, 0);
      expect(cache.length, 2);
    });
  });
}
