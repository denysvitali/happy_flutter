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

import 'package:mmkv_platform_interface/mmkv_platform_interface.dart';

class FakeMmkvPlatform extends MMKVPluginPlatform {
  @override
  Future<String> getApplicationDocumentsPath() async => '/tmp/mmkv_test';

  @override
  Future<String> initialize(
    String rootDir, {
    String? groupDir,
    int logLevel = 1,
    Pointer<NativeFunction<LogCallbackWrap>>? logHandler,
  }) async =>
      rootDir;

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
      ) => Pointer<Void>.fromAddress(1);

  @override
  ContentCallbackRegister registerContentLoadedHandlerFunc() =>
      (Pointer<NativeFunction<ContentCallbackWrap>> handler) {};

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, int) decodeBoolFunc() =>
      (Pointer<Void> h, Pointer<Utf8> k, int d) => 1;

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, int) encodeBoolFunc() =>
      (Pointer<Void> h, Pointer<Utf8> k, int v) => 1;

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, int, int) encodeBoolV2Func() =>
      (Pointer<Void> h, Pointer<Utf8> k, int v, int e) => 1;

  @override
  Pointer<Uint8> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Uint64>)
  decodeBytesFunc() =>
      (Pointer<Void> h, Pointer<Utf8> k, Pointer<Uint64> l) =>
          Pointer<Uint8>.fromAddress(0);

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Uint8>, int)
  encodeBytesFunc() =>
      (Pointer<Void> h, Pointer<Utf8> k, Pointer<Uint8> v, int l) => 1;

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Uint8>, int, int)
  encodeBytesV2Func() =>
      (Pointer<Void> h, Pointer<Utf8> k, Pointer<Utf8> v, int l, int e) => 1;

  @override
  void Function(Pointer<Void>, Pointer<Utf8>) removeValueForKeyFunc() =>
      (Pointer<Void> h, Pointer<Utf8> k) {};
}
