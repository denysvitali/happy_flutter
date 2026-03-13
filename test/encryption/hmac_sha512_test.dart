import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/hmac_sha512.dart';

void main() {
  group('HmacSha512', () {
    test('compute returns 64-byte output', () async {
      final key = Uint8List.fromList([1, 2, 3]);
      final data = Uint8List.fromList([4, 5, 6]);

      final result = await HmacSha512.compute(key, data);
      expect(result.length, 64);
    });

    test('same inputs produce same output', () async {
      final key = Uint8List.fromList([1, 2, 3, 4, 5]);
      final data = Uint8List.fromList([10, 20, 30]);

      final result1 = await HmacSha512.compute(key, data);
      final result2 = await HmacSha512.compute(key, data);
      expect(result1, result2);
    });

    test('different keys produce different outputs', () async {
      final key1 = Uint8List.fromList([1, 2, 3]);
      final key2 = Uint8List.fromList([4, 5, 6]);
      final data = Uint8List.fromList([10, 20, 30]);

      final result1 = await HmacSha512.compute(key1, data);
      final result2 = await HmacSha512.compute(key2, data);
      expect(result1, isNot(equals(result2)));
    });

    test('different data produces different outputs', () async {
      final key = Uint8List.fromList([1, 2, 3]);
      final data1 = Uint8List.fromList([10, 20, 30]);
      final data2 = Uint8List.fromList([40, 50, 60]);

      final result1 = await HmacSha512.compute(key, data1);
      final result2 = await HmacSha512.compute(key, data2);
      expect(result1, isNot(equals(result2)));
    });

    test('handles empty data', () async {
      final key = Uint8List.fromList([1, 2, 3]);
      final data = Uint8List(0);

      final result = await HmacSha512.compute(key, data);
      expect(result.length, 64);
    });

    test('handles empty key', () async {
      final key = Uint8List(0);
      final data = Uint8List.fromList([1, 2, 3]);

      final result = await HmacSha512.compute(key, data);
      expect(result.length, 64);
    });

    test('handles key longer than block size (128 bytes)', () async {
      // SHA-512 block size is 128 bytes
      final key = Uint8List(200);
      for (var i = 0; i < 200; i++) {
        key[i] = i % 256;
      }
      final data = Uint8List.fromList([10, 20, 30]);

      final result = await HmacSha512.compute(key, data);
      expect(result.length, 64);
    });

    test('handles key exactly at block size', () async {
      final key = Uint8List(128);
      for (var i = 0; i < 128; i++) {
        key[i] = i;
      }
      final data = Uint8List.fromList([10, 20, 30]);

      final result = await HmacSha512.compute(key, data);
      expect(result.length, 64);
    });

    test('produces deterministic output', () async {
      final key = Uint8List.fromList(
        List.generate(32, (i) => i),
      );
      final data = Uint8List.fromList(
        List.generate(64, (i) => i + 100),
      );

      final results = <Uint8List>[];
      for (var i = 0; i < 10; i++) {
        results.add(await HmacSha512.compute(key, data));
      }

      // All results should be identical
      for (var i = 1; i < results.length; i++) {
        expect(results[i], results[0]);
      }
    });

    test('handles large data', () async {
      final key = Uint8List.fromList([1, 2, 3]);
      final data = Uint8List(10000);
      for (var i = 0; i < 10000; i++) {
        data[i] = i % 256;
      }

      final result = await HmacSha512.compute(key, data);
      expect(result.length, 64);
    });

    test('handles all-zero key and data', () async {
      final key = Uint8List(32);
      final data = Uint8List(32);

      final result = await HmacSha512.compute(key, data);
      expect(result.length, 64);
      // Should not be all zeros
      expect(result.any((b) => b != 0), true);
    });

    test('single byte changes in key change output', () async {
      final key1 = Uint8List(32);
      final key2 = Uint8List(32);
      key2[31] = 1; // Only change last byte
      final data = Uint8List.fromList([1, 2, 3]);

      final result1 = await HmacSha512.compute(key1, data);
      final result2 = await HmacSha512.compute(key2, data);
      expect(result1, isNot(equals(result2)));
    });

    test('single byte changes in data change output', () async {
      final key = Uint8List.fromList([1, 2, 3]);
      final data1 = Uint8List(32);
      final data2 = Uint8List(32);
      data2[31] = 1;

      final result1 = await HmacSha512.compute(key, data1);
      final result2 = await HmacSha512.compute(key, data2);
      expect(result1, isNot(equals(result2)));
    });
  });
}
