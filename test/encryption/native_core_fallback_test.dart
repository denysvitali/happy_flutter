import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/native/native_core.dart';

/// The native (Rust) core is an optimisation, never a dependency.
///
/// Every platform that has not wired the library in — and every platform
/// where loading it fails — must keep decrypting through the existing Dart
/// path. These tests pin the contract that makes that safe: an unavailable
/// core reports itself unavailable and returns `null` (the caller's signal to
/// run the Dart implementation), rather than throwing or returning a
/// partially-filled batch that would look like decryption failures.
void main() {
  tearDown(NativeCore.instance.debugReset);

  test('an unavailable core returns null so the caller falls back', () async {
    NativeCore.instance.debugSetAvailable(available: false);

    final result = await NativeCore.instance.decryptAesGcmBase64Batch(
      key: List<int>.filled(32, 0),
      envelopesBase64: const ['AAAA'],
    );

    expect(
      result,
      isNull,
      reason:
          'null means "I did not run" — distinct from a list of nulls, '
          'which would mean "these rows failed to decrypt"',
    );
  });

  test('isAvailable is false before initialization is attempted', () {
    NativeCore.instance.debugReset();
    expect(NativeCore.instance.isAvailable, isFalse);
  });

  test('an empty batch short-circuits without touching the native core', () async {
    NativeCore.instance.debugSetAvailable(available: true);

    final result = await NativeCore.instance.decryptAesGcmBase64Batch(
      key: List<int>.filled(32, 0),
      envelopesBase64: const [],
    );

    expect(
      result,
      isEmpty,
      reason: 'no crossing should happen for an empty batch',
    );
  });

  test('ensureInitialized resolves quietly whether or not the library '
      'is present', () async {
    NativeCore.instance.debugReset();

    // A platform without the library is an expected configuration, so this
    // must never throw — it just leaves the core unavailable.
    await expectLater(NativeCore.instance.ensureInitialized(), completes);
  });

  test('when the core loads, it decrypts real Dart-written envelopes '
      'identically to Dart', () async {
    NativeCore.instance.debugReset();
    await NativeCore.instance.ensureInitialized();
    if (!NativeCore.instance.isAvailable) {
      // Host has no native library wired in; the fallback tests above cover
      // that case and there is nothing to compare against here.
      return;
    }

    final key = Uint8List.fromList(List<int>.generate(32, (i) => i * 7 % 256));
    final dart = AES256Encryption(key);
    final payloads = <dynamic>[
      {'hello': 'world', 'n': 42},
      {'nested': {'a': [1, 2, 3]}, 'unicode': 'caffè ☕'},
      {'empty': {}},
    ];
    final envelopes = await dart.encrypt(payloads);

    final native = await NativeCore.instance.decryptAesGcmBase64Batch(
      key: key,
      envelopesBase64: [for (final e in envelopes) base64.encode(e)],
    );

    expect(native, isNotNull);
    expect(native!, hasLength(payloads.length));
    for (var i = 0; i < payloads.length; i++) {
      expect(
        jsonDecode(native[i]!),
        equals(payloads[i]),
        reason: 'Rust must reproduce exactly what Dart sealed (row \$i)',
      );
    }
  });

  test('a corrupt row yields null in place without failing its neighbours',
      () async {
    NativeCore.instance.debugReset();
    await NativeCore.instance.ensureInitialized();
    if (!NativeCore.instance.isAvailable) return;

    final key = Uint8List.fromList(List<int>.filled(32, 3));
    final dart = AES256Encryption(key);
    final good = (await dart.encrypt([
      {'ok': true},
    ])).single;

    final native = await NativeCore.instance.decryptAesGcmBase64Batch(
      key: key,
      envelopesBase64: [
        base64.encode(good),
        'not-base64!!',
        base64.encode(good),
      ],
    );

    expect(native, isNotNull);
    expect(jsonDecode(native![0]!), {'ok': true});
    expect(native[1], isNull, reason: 'index alignment must be preserved');
    expect(jsonDecode(native[2]!), {'ok': true});
  });
}
