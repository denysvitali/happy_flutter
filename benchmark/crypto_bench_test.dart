@Timeout(Duration(minutes: 10))
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/aes_gcm.dart';

import 'bench_runner.dart';
import 'fixtures.dart';

/// Raw AES-256-GCM crypto cost, the substrate under every message page.
///
/// Payloads mirror production shapes: ~1KB assistant prose and a ~20KB
/// ANSI-laden tool result. `AesGcmEncryption.encrypt` jsonEncodes its
/// input and `decrypt` utf8-decodes + jsonDecodes its output, so these
/// numbers include the JSON codec work that always rides with crypto.
void main() {
  final reporter = BenchReporter(group: 'crypto');

  final key = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    key[i] = (i * 7 + 3) & 0xff;
  }

  tearDownAll(() => reporter.finish());

  test('AES-256-GCM encrypt+decrypt roundtrip, 1KB message', () async {
    final payload = <String, dynamic>{
      'role': 'assistant',
      'content': <String, dynamic>{
        'type': 'text',
        'text': benchText(1000),
      },
    };
    await reporter.measure(
      'aes_gcm_roundtrip_1kb',
      () async {
        final ct = await AesGcmEncryption.encrypt(payload, key);
        final pt = await AesGcmEncryption.decrypt(ct, key);
        expect(pt, isNotNull);
      },
      iterations: 200,
    );
  });

  test('AES-256-GCM encrypt+decrypt roundtrip, 20KB tool result', () async {
    final payload = <String, dynamic>{
      'role': 'user',
      'content': <String, dynamic>{
        'type': 'tool_result',
        'tool_use_id': 'toolu_bench',
        'output': ansiToolOutput(20000),
        'isError': false,
      },
    };
    await reporter.measure(
      'aes_gcm_roundtrip_20kb_tool_result',
      () async {
        final ct = await AesGcmEncryption.encrypt(payload, key);
        final pt = await AesGcmEncryption.decrypt(ct, key);
        expect(pt, isNotNull);
      },
      iterations: 80,
    );
  });

  test('AES-256-GCM decryptBatch of 100 x 2KB messages', () async {
    final batch = <Uint8List>[];
    for (var i = 0; i < 100; i++) {
      batch.add(await AesGcmEncryption.encrypt(
        <String, dynamic>{
          'role': 'assistant',
          'content': <String, dynamic>{
            'type': 'text',
            'text': benchText(2000),
          },
        },
        key,
      ));
    }
    var lastCount = 0;
    await reporter.measure(
      'aes_gcm_decrypt_batch_100x2kb',
      () async {
        final out = await AesGcmEncryption.decryptBatch(batch, key);
        lastCount = out.length;
      },
      iterations: 15,
      opsPerIteration: batch.length,
    );
    expect(lastCount, batch.length);
  });
}
