import 'dart:io';

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

  // GlitchTip 8725: the worker body force-unwrapped its request map, so any
  // failure escaped the isolate as a bare `Null check operator used on a
  // null value` naming neither the step nor the reason.
  group('MMKV worker compaction request validation', () {
    test('a missing request payload returns a structured error', () {
      final result = MMKVStorage.debugCompactDefaultMMKVIfNeeded(
        <String, Object>{},
      );

      expect(result['trimmed'], isFalse);
      expect(result['error'], 'invalid-request');
      expect(result['errorDetail'], contains('rootDir'));
    });

    test('wrongly typed fields return a structured error, not a throw', () {
      final result = MMKVStorage.debugCompactDefaultMMKVIfNeeded(
        <String, Object>{'rootDir': 42, 'minFileBytes': 'many'},
      );

      expect(result['trimmed'], isFalse);
      expect(result['error'], 'invalid-request');
      expect(result['errorDetail'], contains('String'));
      expect(result['errorDetail'], contains('int'));
    });

    test('a valid request never throws, whatever the store does', () {
      // The store itself is platform-dependent; the contract under test is
      // that this call reports an outcome instead of throwing out of the
      // worker (which is what the catch in the body exists to guarantee).
      final result = MMKVStorage.debugCompactDefaultMMKVIfNeeded(
        <String, Object>{
          'rootDir': '${Directory.systemTemp.path}/happy-compact-test',
          'minFileBytes': 64 * 1024 * 1024,
        },
      );

      expect(result.containsKey('trimmed'), isTrue);
      expect(result['rootDir'], isNotNull);
    });
  });
}
