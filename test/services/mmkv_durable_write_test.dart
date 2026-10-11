import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mmkv_platform_interface/mmkv_platform_interface.dart';

import '../helpers/fake_mmkv_platform.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';

class _FailingWritePlatform extends FakeMmkvPlatform {
  bool failWrites = false;

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Uint8>, int)
  encodeBytesFunc() {
    final write = super.encodeBytesFunc();
    return (handle, key, value, length) =>
        failWrites ? 0 : write(handle, key, value, length);
  }
}

void main() {
  final platform = _FailingWritePlatform();
  MMKVPluginPlatform.instance = platform;

  test(
    'native encode failure rejects durable journal and outbox writes',
    () async {
      MMKVStorage.resetForTesting();
      await MMKVStorage.initialize();
      final storage = MMKVStorage();
      await storage.setStringDurable('durable-contract', 'committed');
      platform.failWrites = true;
      try {
        await expectLater(
          storage.setStringDurable('durable-contract', 'lost'),
          throwsStateError,
        );
        expect(storage.getString('durable-contract'), 'committed');
        await expectLater(storage.saveOutboxEntries('lost'), throwsStateError);
      } finally {
        platform.failWrites = false;
        await storage.removeKeyDurable('durable-contract');
      }
    },
  );

  test('durable generic writes and removals are awaitable', () async {
    MMKVStorage.resetForTesting();
    await MMKVStorage.initialize();
    final storage = MMKVStorage();
    await storage.setStringDurable('durable-contract', 'committed');
    expect(storage.getString('durable-contract'), 'committed');
    await storage.removeKeyDurable('durable-contract');
    expect(storage.getString('durable-contract'), isNull);
  });
}
