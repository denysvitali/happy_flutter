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

    test('rejects other platforms and ordinary allocation slack', () {
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
          totalBytes: 64 * 1024 * 1024,
          actualBytes: 48 * 1024 * 1024,
          isLinux: true,
        ),
        isFalse,
      );
    });
  });
}
