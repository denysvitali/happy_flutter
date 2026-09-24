import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/aes_gcm.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/native/native_core.dart';

import 'bench_runner.dart';

void main() {
  final reporter = BenchReporter(group: 'native_encrypt');
  tearDownAll(() => reporter.finish());

  test('20KB wire payload: Dart AES versus production Rust path', () async {
    await NativeCore.instance.ensureInitialized();
    expect(
      NativeCore.instance.isAvailable,
      isTrue,
      reason: 'CI builds the native library before benchmarking',
    );
    final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final payload = {'localId': 'bench-send', 'text': 'continue' * 2500};
    final encryptor = AES256Encryption(key);
    var bytesProduced = 0;

    await reporter.measure(
      'dart_aes_wire_20kb',
      () async {
        final raw = await AesGcmEncryption.encrypt(payload, key);
        bytesProduced += raw.length + 1;
      },
      iterations: 30,
      warmup: 3,
    );
    await reporter.measure(
      'rust_aes_wire_20kb',
      () async {
        final wire = (await encryptor.encrypt([payload])).single;
        bytesProduced += wire.length;
      },
      iterations: 30,
      warmup: 3,
    );

    expect(NativeCore.instance.isAvailable, isTrue);
    final wire = (await encryptor.encrypt([payload])).single;
    expect(wire[0], 0);
    expect(await AesGcmEncryption.decrypt(wire.sublist(1), key), payload);
    expect(bytesProduced, greaterThan(0));
  });
}
