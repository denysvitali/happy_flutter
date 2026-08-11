// Fake MMKV platform registered globally by [testExecutable] in
// `flutter_test_config.dart` so every test (widget, unit, integration)
// can call `MMKV.initialize()` / `MMKV.defaultMMKV()` without the
// real native library. Without this stub, every code path that
// touches MMKV throws `Null check operator used on a null value`
// from `_mmkvPlatform.initialize(...)` and the affected tests are
// reported as failed.
//
// Behaviour is intentionally minimal: every write is a no-op, every
// read returns a fixed default, no on-disk persistence. Tests that
// care about real persistence inject a `_FakeMMKVStorage` via
// `messageOutbox.testStorage` instead.
//
// Originally lived in `test/features/chat/chat_screen_test.dart`;
// promoted to a global helper when CI test shards (5/8, 6/8, 7/8,
// 8/8) started failing for the same reason after the cold-start
// perf commits added more MMKV call sites on the test path.
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mmkv_platform_interface/mmkv_platform_interface.dart';

class FakeMmkvPlatform extends MMKVPluginPlatform {
  final Map<int, Map<String, Object>> _stores = <int, Map<String, Object>>{};
  final Map<String, int> _handles = <String, int>{};
  int _nextHandle = 2;

  Map<String, Object> _store(Pointer<Void> handle) =>
      _stores.putIfAbsent(handle.address, () => <String, Object>{});

  Pointer<Void> _handleFor(String id) {
    final address = _handles.putIfAbsent(id, () => _nextHandle++);
    _stores.putIfAbsent(address, () => <String, Object>{});
    return Pointer<Void>.fromAddress(address);
  }

  @override
  Future<String> getApplicationDocumentsPath() async => '/tmp/mmkv_test';

  @override
  Future<String> initialize(
    String rootDir, {
    String? groupDir,
    int logLevel = 1,
    Pointer<NativeFunction<LogCallbackWrap>>? logHandler,
  }) async => rootDir;

  @override
  Pointer<Void> Function(int, Pointer<Utf8>, int, int, int, int, int, int, int)
  getDefaultMMKVFunc() =>
      (
        int mode,
        Pointer<Utf8> cryptKey,
        int aes256,
        int expectedCapacity,
        int enableKeyExpire,
        int expiredInSeconds,
        int enableCompareBeforeSet,
        int recover,
        int itemSizeLimit,
      ) => _handleFor('default');

  @override
  Pointer<Void> Function(
    Pointer<Utf8>,
    int,
    Pointer<Utf8>,
    Pointer<Utf8>,
    int,
    int,
    int,
    int,
    int,
    int,
    int,
    int,
  )
  getMMKVWithIDFunc() =>
      (
        id,
        mode,
        cryptKey,
        rootDir,
        capacity,
        namespace,
        aes256,
        expire,
        seconds,
        compare,
        recover,
        itemSizeLimit,
      ) => _handleFor(id.toDartString());

  @override
  ContentCallbackRegister registerContentLoadedHandlerFunc() =>
      (Pointer<NativeFunction<ContentCallbackWrap>> handler) {};

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, int) decodeBoolFunc() =>
      (h, key, fallback) =>
          (_store(h)[key.toDartString()] as bool? ?? fallback != 0) ? 1 : 0;

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, int) encodeBoolFunc() =>
      (h, key, value) {
        _store(h)[key.toDartString()] = value != 0;
        return 1;
      };

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, int, int) encodeBoolV2Func() =>
      (h, key, value, expiry) {
        _store(h)[key.toDartString()] = value != 0;
        return 1;
      };

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, int) encodeInt32Func() =>
      (h, key, value) {
        _store(h)[key.toDartString()] = value;
        return 1;
      };

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, int, int) encodeInt32V2Func() =>
      (h, key, value, expiry) {
        _store(h)[key.toDartString()] = value;
        return 1;
      };

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, int) decodeInt32Func() =>
      (h, key, fallback) => _store(h)[key.toDartString()] as int? ?? fallback;

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, int) encodeInt64Func() =>
      encodeInt32Func();

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, int, int) encodeInt64V2Func() =>
      encodeInt32V2Func();

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, int) decodeInt64Func() =>
      decodeInt32Func();

  @override
  Pointer<Uint8> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Uint64>)
  decodeBytesFunc() => (h, key, length) {
    final value = _store(h)[key.toDartString()] as List<int>?;
    if (value == null) return nullptr;
    length.value = value.length;
    final result = calloc<Uint8>(value.isEmpty ? 1 : value.length);
    if (value.isNotEmpty) result.asTypedList(value.length).setAll(0, value);
    return result;
  };

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Uint8>, int)
  encodeBytesFunc() => (h, key, value, length) {
    _store(h)[key.toDartString()] = List<int>.from(value.asTypedList(length));
    return 1;
  };

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Uint8>, int, int)
  encodeBytesV2Func() => (h, key, value, length, expiry) {
    _store(h)[key.toDartString()] = List<int>.from(value.asTypedList(length));
    return 1;
  };

  @override
  int Function(
    Pointer<Void>,
    Pointer<Pointer<Pointer<Utf8>>>,
    Pointer<Pointer<Uint32>>,
    int,
  )
  allKeysFunc() => (handle, keyArrayOut, sizeArrayOut, filterExpired) {
    final keys = _store(handle).keys.toList();
    if (keys.isEmpty) return 0;
    final keyArray = calloc<Pointer<Utf8>>(keys.length);
    final sizes = calloc<Uint32>(keys.length);
    for (var index = 0; index < keys.length; index++) {
      final bytes = keys[index].codeUnits;
      final key = calloc<Uint8>(bytes.length).cast<Utf8>();
      key.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
      keyArray[index] = key;
      sizes[index] = bytes.length;
    }
    keyArrayOut.value = keyArray;
    sizeArrayOut.value = sizes;
    return keys.length;
  };

  @override
  int Function(Pointer<Void>, Pointer<Utf8>) containsKeyFunc() =>
      (handle, key) => _store(handle).containsKey(key.toDartString()) ? 1 : 0;

  @override
  int Function(Pointer<Void>, int) countFunc() =>
      (handle, filterExpired) => _store(handle).length;

  @override
  void Function(Pointer<Void>, Pointer<Utf8>) removeValueForKeyFunc() =>
      (handle, key) => _store(handle).remove(key.toDartString());

  @override
  void Function(Pointer<Void>, int) clearAllFunc() =>
      (handle, keepSpace) => _store(handle).clear();

  @override
  void Function(Pointer) freePtrFunc() => calloc.free;
}
