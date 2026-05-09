import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/crypto_worker.dart';

void main() {
  group('CryptoWorker', () {
    late CryptoWorker worker;

    setUp(() async {
      worker = await CryptoWorker.spawn();
    });

    tearDown(() {
      worker.shutdown();
    });

    test('echo round-trips a value through the isolate', () async {
      final result = await worker.echo({'hello': 42});
      expect(result, {'hello': 42});
    });

    test('decodeJson runs off the UI isolate', () async {
      final result = await worker.decodeJson('{"a":1,"b":[2,3]}');
      expect(result, {
        'a': 1,
        'b': [2, 3],
      });
    });

    test('naclSecretboxOpen round-trips bytes through the worker',
        () async {
      // Scaffold uses an echo-stub for the actual nacl call — see
      // doc comment in CryptoWorker._dispatch.  The point is that
      // the SendPort plumbing works end-to-end.
      final ciphertext = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = await worker.naclSecretboxOpen(
        ciphertext: ciphertext,
        nonce: Uint8List(24),
        key: Uint8List(32),
      );
      expect(result, isNotNull);
      expect(result, [1, 2, 3, 4, 5]);
    });

    test('after shutdown, new requests fail with StateError', () async {
      worker.shutdown();
      expect(worker.echo('x'), throwsStateError);
    });

    test('handles concurrent requests without mixing replies', () async {
      final futures = <Future<Object?>>[
        for (var i = 0; i < 25; i++) worker.echo(i),
      ];
      final results = await Future.wait(futures);
      for (var i = 0; i < 25; i++) {
        expect(results[i], i,
            reason: 'request $i should match the corresponding reply');
      }
    });
  });
}
