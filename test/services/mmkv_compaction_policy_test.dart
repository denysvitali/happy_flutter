import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';

void main() {
  group('MMKV message-cache compaction policy', () {
    test('accepts the measured sparse Linux store', () {
      expect(
        MMKVStorage.debugShouldCompactMessageCache(
          totalBytes: 268435456,
          actualBytes: 30537372,
          isLinux: true,
        ),
        isTrue,
      );
    });

    test('rejects other platforms and small files', () {
      expect(
        MMKVStorage.debugShouldCompactMessageCache(
          totalBytes: 268435456,
          actualBytes: 30537372,
          isLinux: false,
        ),
        isFalse,
      );
      expect(
        MMKVStorage.debugShouldCompactMessageCache(
          totalBytes: 63 * 1024 * 1024,
          actualBytes: 48 * 1024 * 1024,
          isLinux: true,
        ),
        isFalse,
      );
    });

    test('does not treat append position as live payload size', () {
      expect(
        MMKVStorage.debugShouldCompactMessageCache(
          totalBytes: 268435456,
          actualBytes: 218 * 1024 * 1024,
          isLinux: true,
        ),
        isTrue,
        reason: 'trim performs fullWriteback before deciding how far to shrink',
      );
    });

    test('re-arms maintenance after 32 MiB of cache writes', () {
      expect(
        MMKVStorage.debugCrossesMessageCacheCompactionWriteTrigger(
          accumulatedBytes: 31 * 1024 * 1024,
          writeBytes: 1024 * 1024 - 1,
        ),
        isFalse,
      );
      expect(
        MMKVStorage.debugCrossesMessageCacheCompactionWriteTrigger(
          accumulatedBytes: 31 * 1024 * 1024,
          writeBytes: 1024 * 1024,
        ),
        isTrue,
      );
    });
  });
}
