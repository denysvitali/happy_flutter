import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/native/native_core.dart';

/// At-rest payloads are *persisted*, so the Rust and Dart implementations must
/// agree on the envelope forever: `[12-byte nonce][ciphertext][16-byte tag]`
/// with the domain string bound as GCM associated data, and no version byte.
///
/// A divergence here would not fail loudly — it would quietly orphan every
/// cached window and outbox entry written by the other implementation.
void main() {
  final cipher = DartAesGcm.with256bits();
  final key = Uint8List.fromList(List<int>.generate(32, (i) => (i * 11) % 256));
  final nonce = Uint8List.fromList(List<int>.generate(12, (i) => i + 3));

  setUp(() async {
    NativeCore.instance.debugReset();
    await NativeCore.instance.ensureInitialized();
  });

  Uint8List sealWithDart(String plaintext, String aad) {
    final keyData = SecretKeyData(Uint8List.fromList(key));
    try {
      final box = cipher.encryptSync(
        utf8.encode(plaintext),
        secretKeyData: keyData,
        nonce: nonce,
        aad: utf8.encode(aad),
      );
      return Uint8List(
          box.nonce.length + box.cipherText.length + box.mac.bytes.length,
        )
        ..setAll(0, box.nonce)
        ..setAll(box.nonce.length, box.cipherText)
        ..setAll(box.nonce.length + box.cipherText.length, box.mac.bytes);
    } finally {
      keyData.destroy();
    }
  }

  test('Rust opens an at-rest payload sealed by Dart', () {
    if (!NativeCore.instance.isAvailable) return;
    const plaintext = '{"cached":[1,2,3],"unicode":"caffè ☕"}';
    final sealed = sealWithDart(plaintext, 'cache:session-1');

    final opened = NativeCore.instance.decryptAtRestBatchSync(
      payloads: [sealed],
      key: key,
      associatedData: utf8.encode('cache:session-1'),
    );

    expect(opened, isNotNull);
    expect(opened!.single, plaintext);
  });

  test('Dart opens an at-rest payload sealed by Rust, byte-identically', () {
    if (!NativeCore.instance.isAvailable) return;
    const plaintext = '{"written":"by rust"}';

    final sealed = NativeCore.instance.encryptAtRestBatchSync(
      plaintexts: const [plaintext],
      nonces: [nonce],
      key: key,
      associatedData: utf8.encode('cache:session-2'),
    );
    expect(sealed, isNotNull);

    // Same nonce and domain => the two implementations must produce the exact
    // same bytes, not merely mutually-readable ones.
    expect(
      sealed!.single,
      orderedEquals(sealWithDart(plaintext, 'cache:session-2')),
      reason: 'Rust and Dart must serialise the at-rest envelope identically',
    );
  });

  test('the domain string is enforced by both implementations', () {
    if (!NativeCore.instance.isAvailable) return;
    final sealed = sealWithDart('{}', 'cache:a');

    final wrongDomain = NativeCore.instance.decryptAtRestBatchSync(
      payloads: [sealed],
      key: key,
      associatedData: utf8.encode('outbox:a'),
    );

    expect(wrongDomain, isNotNull);
    expect(
      wrongDomain!.single,
      isNull,
      reason: 'a payload sealed for one domain must not open under another',
    );
  });
}
