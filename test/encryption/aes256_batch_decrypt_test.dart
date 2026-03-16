// Regression tests for AES256Encryption batch-decrypt completeness.
//
// Production bug context (commit 6fbe95e): crypto decryption was offloaded
// to Isolate.run(), which silently fails on Android because platform-channel-
// backed libraries (AES-256-GCM) cannot cross isolate boundaries. Every item
// in a batch returned null, causing "No machines found" on all Android
// devices. These tests guard against any future regression that would cause
// batch decrypt to silently drop or null-out items.

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';

void main() {
  group('AES256Encryption — batch decrypt completeness', () {
    test('batch decrypt returns same number of items as input', () async {
      final key = _generateKey();
      final enc = AES256Encryption(key);

      final inputs = List<Map<String, dynamic>>.generate(
        15,
        (i) => {'index': i, 'value': 'item_$i'},
      );

      final ciphertexts = await enc.encrypt(inputs);
      expect(ciphertexts.length, 15, reason: 'encrypt must preserve count');

      final results = await enc.decrypt(ciphertexts);

      expect(
        results.length,
        15,
        reason:
            'decrypt must return exactly as many items as were encrypted; '
            'a shorter list indicates silent drops (the Isolate.run() bug)',
      );
    });

    test('batch decrypt returns non-null for all valid items', () async {
      final key = _generateKey();
      final enc = AES256Encryption(key);

      final inputs = List<Map<String, dynamic>>.generate(
        15,
        (i) => {'index': i, 'payload': 'data_$i'},
      );

      final ciphertexts = await enc.encrypt(inputs);
      final results = await enc.decrypt(ciphertexts);

      for (var i = 0; i < results.length; i++) {
        expect(
          results[i],
          isNotNull,
          reason: 'item $i must not be null after successful decrypt',
        );
        expect(
          results[i],
          equals(inputs[i]),
          reason: 'item $i must round-trip to its original value',
        );
      }
    });

    test('batch decrypt with 1 item works', () async {
      final key = _generateKey();
      final enc = AES256Encryption(key);

      final input = [
        {'id': 'only', 'value': 42},
      ];

      final ciphertexts = await enc.encrypt(input);
      final results = await enc.decrypt(ciphertexts);

      expect(results.length, 1);
      expect(results[0], isNotNull);
      expect(results[0], equals(input[0]));
    });

    test('batch decrypt with 50 items works', () async {
      // A batch of 50 would have definitely triggered the old isolate path.
      // Every result must be non-null and match the original.
      final key = _generateKey();
      final enc = AES256Encryption(key);

      final inputs = List<Map<String, dynamic>>.generate(
        50,
        (i) => {'seq': i, 'label': 'machine_$i', 'active': i.isEven},
      );

      final ciphertexts = await enc.encrypt(inputs);
      expect(ciphertexts.length, 50);

      final results = await enc.decrypt(ciphertexts);

      expect(
        results.length,
        50,
        reason: 'all 50 items must be present in the result',
      );

      for (var i = 0; i < results.length; i++) {
        expect(
          results[i],
          isNotNull,
          reason: 'item $i must not be null',
        );
        expect(results[i], equals(inputs[i]));
      }
    });

    test(
      'encrypt then decrypt roundtrip preserves all data types',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);

        // A single batch containing diverse data types.
        final inputs = <dynamic>[
          'a plain string',
          42,
          3.14,
          true,
          false,
          [1, 'two', 3.0],
          {'nested': 'map', 'count': 7},
          {
            'deep': {
              'level': 2,
              'items': ['x', 'y'],
            },
          },
        ];

        final ciphertexts = await enc.encrypt(inputs);
        final results = await enc.decrypt(ciphertexts);

        expect(results.length, inputs.length);

        for (var i = 0; i < results.length; i++) {
          expect(
            results[i],
            isNotNull,
            reason: 'item $i (${inputs[i].runtimeType}) must survive roundtrip',
          );
          expect(
            results[i],
            equals(inputs[i]),
            reason: 'item $i must equal original after roundtrip',
          );
        }
      },
    );

    test(
      'batch decrypt with one corrupted item returns null for that '
      'item only, all others succeed',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);

        final inputs = List<Map<String, dynamic>>.generate(
          5,
          (i) => {'id': i, 'name': 'entry_$i'},
        );

        final ciphertexts = await enc.encrypt(inputs);
        expect(ciphertexts.length, 5);

        // Corrupt item at index 2 by flipping the last byte of its ciphertext.
        // The version byte (index 0) is 0x00; the AES-GCM auth tag is at the
        // tail, so flipping the last byte breaks authentication.
        const corruptedIndex = 2;
        final corrupted = Uint8List.fromList(ciphertexts[corruptedIndex]);
        corrupted[corrupted.length - 1] ^= 0xFF;
        ciphertexts[corruptedIndex] = corrupted;

        final results = await enc.decrypt(ciphertexts);

        expect(
          results.length,
          5,
          reason: 'result list must still contain 5 entries even with '
              'one corrupted item',
        );

        for (var i = 0; i < results.length; i++) {
          if (i == corruptedIndex) {
            expect(
              results[i],
              isNull,
              reason: 'corrupted item at index $i must return null',
            );
          } else {
            expect(
              results[i],
              isNotNull,
              reason:
                  'valid item at index $i must not be null because one '
                  'other item was corrupted',
            );
            expect(
              results[i],
              equals(inputs[i]),
              reason: 'valid item at index $i must match original',
            );
          }
        }
      },
    );
  });
}

/// Generates a cryptographically random 32-byte AES-256 key.
Uint8List _generateKey() {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(32, (_) => random.nextInt(256)),
  );
}
