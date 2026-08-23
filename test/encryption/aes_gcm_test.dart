import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/aes_gcm.dart';
import 'package:happy_flutter/core/encryption/base64.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';

void main() {
  group('AesGcmEncryption - True AES-256-GCM Encryption', () {
    group('Key and Nonce Constants', () {
      test('has correct key size', () {
        expect(AesGcmEncryption.keySize, 32); // 256 bits
      });

      test('has correct nonce size', () {
        expect(AesGcmEncryption.nonceSize, 12); // GCM standard
      });

      test('has correct auth tag size', () {
        expect(AesGcmEncryption.authTagSize, 16); // GCM standard
      });
    });

    group('Encryption and Decryption', () {
      test('encrypt and decrypt roundtrip works', () async {
        final secretKey = _generateKey();
        final originalData = {'message': 'Hello, World!', 'value': 42};

        final encrypted = await AesGcmEncryption.encrypt(originalData,
            secretKey,);

        expect(encrypted, isNot(equals(originalData)));

        final decrypted = await AesGcmEncryption.decrypt(encrypted, secretKey);

        expect(decrypted, isNotNull);
        expect(decrypted, equals(originalData));
      });

      test('encrypt and decrypt string roundtrip works', () async {
        final secretKey = _generateKey();
        final originalData = 'Hello, World!';

        final encrypted = await AesGcmEncryption.encrypt(originalData,
            secretKey,);
        final decrypted = await AesGcmEncryption.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encrypt and decrypt number roundtrip works', () async {
        final secretKey = _generateKey();
        final originalData = 12345;

        final encrypted = await AesGcmEncryption.encrypt(originalData,
            secretKey,);
        final decrypted = await AesGcmEncryption.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encrypt and decrypt list roundtrip works', () async {
        final secretKey = _generateKey();
        final originalData = [1, 2, 3, 'four', {'five': 5}];

        final encrypted = await AesGcmEncryption.encrypt(originalData,
            secretKey,);
        final decrypted = await AesGcmEncryption.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encrypt and decrypt complex object works', () async {
        final secretKey = _generateKey();
        final originalData = {
          'user': {
            'name': 'John Doe',
            'age': 30,
            'roles': ['admin', 'editor'],
            'settings': {
              'theme': 'dark',
              'notifications': true,
            },
          },
          'timestamp': 1234567890,
        };

        final encrypted = await AesGcmEncryption.encrypt(originalData,
            secretKey,);
        final decrypted = await AesGcmEncryption.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encrypt produces different output each time', () async {
        final secretKey = _generateKey();
        final data = 'Hello, World!';

        final encrypted1 = await AesGcmEncryption.encrypt(data, secretKey);
        final encrypted2 = await AesGcmEncryption.encrypt(data, secretKey);

        // Should be different due to random nonce
        expect(encrypted1, isNot(equals(encrypted2)));

        // But both should decrypt to the same value
        final decrypted1 = await AesGcmEncryption.decrypt(encrypted1,
            secretKey,);
        final decrypted2 = await AesGcmEncryption.decrypt(encrypted2,
            secretKey,);

        expect(decrypted1, equals(decrypted2));
        expect(decrypted1, equals(data));
      });

      test('decrypt with wrong key returns null', () async {
        final secretKey1 = _generateKey();
        final secretKey2 = _generateKey();
        final data = 'Hello, World!';

        final encrypted = await AesGcmEncryption.encrypt(data, secretKey1);

        final decrypted = await AesGcmEncryption.decrypt(encrypted, secretKey2);

        expect(decrypted, isNull);
      });

      test('encrypt and decrypt handle empty string', () async {
        final secretKey = _generateKey();
        final originalData = '';

        final encrypted = await AesGcmEncryption.encrypt(originalData,
            secretKey,);
        final decrypted = await AesGcmEncryption.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encrypt and decrypt handle empty object', () async {
        final secretKey = _generateKey();
        final originalData = <String, dynamic>{};

        final encrypted = await AesGcmEncryption.encrypt(originalData,
            secretKey,);
        final decrypted = await AesGcmEncryption.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encrypt and decrypt handle empty list', () async {
        final secretKey = _generateKey();
        final originalData = <dynamic>[];

        final encrypted = await AesGcmEncryption.encrypt(originalData,
            secretKey,);
        final decrypted = await AesGcmEncryption.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encrypt and decrypt handle larger data', () async {
        final secretKey = _generateKey();

        // Test with 1KB of data
        final largeString = List.generate(1024, (i) => 'X').join();
        final originalData = {'data': largeString};

        final encrypted = await AesGcmEncryption.encrypt(originalData,
            secretKey,);
        final decrypted = await AesGcmEncryption.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encrypt and decrypt handle unicode characters', () async {
        final secretKey = _generateKey();
        final originalData = {
          'emoji': '😀🎉🚀',
          'chinese': '你好世界',
          'arabic': 'مرحبا بالعالم',
          'russian': 'Привет мир',
        };

        final encrypted = await AesGcmEncryption.encrypt(originalData,
            secretKey,);
        final decrypted = await AesGcmEncryption.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encrypt and decrypt handle special characters', () async {
        final secretKey = _generateKey();
        final originalData = {
          'quotes': '"Test" \'data\'',
          'newlines': 'Line1\nLine2\rLine3',
          'tabs': 'Col1\tCol2\tCol3',
          'mixed': '"Hello\nWorld"\tTest',
        };

        final encrypted = await AesGcmEncryption.encrypt(originalData,
            secretKey,);
        final decrypted = await AesGcmEncryption.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });
    });

    group('Base64 Encoding', () {
      test('encryptToBase64 and decryptFromBase64 roundtrip works', () async {
        final secretKey = _generateKey();
        final originalData = {'message': 'Hello, Base64!'};

        final encryptedBase64 =
            await AesGcmEncryption.encryptToBase64(originalData, secretKey);

        expect(encryptedBase64, isA<String>());

        final decrypted =
            await AesGcmEncryption.decryptFromBase64(encryptedBase64,
                secretKey,);

        expect(decrypted, equals(originalData));
      });

      test('encryptToBase64 produces valid Base64 string', () async {
        final secretKey = _generateKey();
        final data = 'Hello, World!';

        final encryptedBase64 = await AesGcmEncryption.encryptToBase64(
          data,
          secretKey,
        );

        // Should be valid Base64 (only contains valid characters)
        expect(encryptedBase64, matches(RegExp(r'^[A-Za-z0-9+/]+=*$')));

        // Should be decodable
        final decoded = Base64Utils.decode(encryptedBase64);
        expect(decoded, isA<Uint8List>());
        expect(decoded.isNotEmpty, true);
      });

      test('encryptToBase64 produces consistent length', () async {
        final secretKey = _generateKey();
        final data = 'Hello, World!';

        final encrypted1 = await AesGcmEncryption.encryptToBase64(
          data,
          secretKey,
        );
        final encrypted2 = await AesGcmEncryption.encryptToBase64(
          data,
          secretKey,
        );

        // Same plaintext should produce same length Base64
        expect(encrypted1.length, equals(encrypted2.length));
      });
    });

    group('Encrypted Data Format', () {
      test('encrypted data has correct structure', () async {
        final secretKey = _generateKey();
        final data = 'Hello, World!';

        final encrypted = await AesGcmEncryption.encrypt(data, secretKey);

        // Format: [12-byte nonce][ciphertext + 16-byte auth tag]
        expect(
          encrypted.length,
          greaterThanOrEqualTo(
            AesGcmEncryption.nonceSize + AesGcmEncryption.authTagSize,
          ),
        );

        // Verify we can extract components
        final nonce = encrypted.sublist(0, AesGcmEncryption.nonceSize);
        expect(nonce.length, AesGcmEncryption.nonceSize);

        final ciphertextWithTag = encrypted.sublist(
          AesGcmEncryption.nonceSize,
        );
        expect(
          ciphertextWithTag.length,
          greaterThanOrEqualTo(AesGcmEncryption.authTagSize),
        );
      });

      test('isAesGcmEncrypted validates correctly', () {
        // Valid encrypted data (minimum size)
        final validData = Uint8List(
          AesGcmEncryption.nonceSize + AesGcmEncryption.authTagSize,
        );
        expect(AesGcmEncryption.isAesGcmEncrypted(validData), true);

        // Data too short
        final shortData = Uint8List(
          AesGcmEncryption.nonceSize + AesGcmEncryption.authTagSize - 1,
        );
        expect(AesGcmEncryption.isAesGcmEncrypted(shortData), false);

        // Empty data
        final emptyData = Uint8List(0);
        expect(AesGcmEncryption.isAesGcmEncrypted(emptyData), false);
      });
    });

    group('Error Handling', () {
      test('throws error for wrong key size', () async {
        final wrongKey = Uint8List(16); // Too short
        final data = 'Hello, World!';

        expect(
          () => AesGcmEncryption.encrypt(data, wrongKey),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('returns null for corrupted data', () async {
        final secretKey = _generateKey();
        final corruptedData = Uint8List.fromList([1, 2, 3, 4, 5]);

        final decrypted = await AesGcmEncryption.decrypt(
          corruptedData,
          secretKey,
        );

        expect(decrypted, isNull);
      });

      test('returns null for too short data', () async {
        final secretKey = _generateKey();
        final shortData = Uint8List.fromList([1, 2]);

        final decrypted = await AesGcmEncryption.decrypt(shortData, secretKey);

        expect(decrypted, isNull);
      });

      test('returns null for modified encrypted data', () async {
        final secretKey = _generateKey();
        final data = 'Hello, World!';

        final encrypted = await AesGcmEncryption.encrypt(data, secretKey);

        // Corrupt the data
        encrypted[0] = encrypted[0] ^ 0xFF;

        final decrypted = await AesGcmEncryption.decrypt(encrypted, secretKey);

        expect(decrypted, isNull);
      });
    });

    group('Compatibility with React Native Format', () {
      test('encrypted format matches expected structure', () async {
        final secretKey = _generateKey();
        final data = 'Hello, World!';

        final encrypted = await AesGcmEncryption.encrypt(data, secretKey);

        // React Native's rn-encryption format: [12-byte IV][ciphertext]
        // [16-byte tag]
        // Our format should match this structure
        expect(encrypted.length, greaterThan(12 + 16));

        // Extract nonce (12 bytes)
        final nonce = encrypted.sublist(0, 12);
        expect(nonce.length, 12);

        // The rest is ciphertext + auth tag (16 bytes at the end)
        final ciphertextAndTag = encrypted.sublist(12);
        expect(ciphertextAndTag.length, greaterThan(16));
      });

      test('Base64 format matches rn-encryption output', () async {
        final secretKey = _generateKey();
        final data = 'Hello, World!';

        final encryptedBase64 = await AesGcmEncryption.encryptToBase64(
          data,
          secretKey,
        );

        // Should be a valid Base64 string
        expect(encryptedBase64, matches(RegExp(r'^[A-Za-z0-9+/]+=*$')));

        // Should be similar format to rn-encryption's encryptAsyncAES output
        // (Base64-encoded encrypted data)
        expect(encryptedBase64.isNotEmpty, true);
      });
    });

    group('Cross-Platform Compatibility', () {
      test('different keys produce different encrypted output', () async {
        final key1 = _generateKey();
        final key2 = _generateKey();
        final data = 'Hello, World!';

        final encrypted1 = await AesGcmEncryption.encrypt(data, key1);
        final encrypted2 = await AesGcmEncryption.encrypt(data, key2);

        // Different keys should produce completely different output
        expect(encrypted1, isNot(equals(encrypted2)));
      });

      test(
          'same data with same key but different nonce produces '
          'different output', () async {
        final secretKey = _generateKey();
        final data = 'Hello, World!';

        final encrypted1 = await AesGcmEncryption.encrypt(data, secretKey);
        final encrypted2 = await AesGcmEncryption.encrypt(data, secretKey);

        // Random nonce ensures different output each time
        expect(encrypted1, isNot(equals(encrypted2)));
      });
    });

    group('React Native Cross-Platform Compatibility', () {
      test('encrypted output has correct [nonce][ciphertext][tag] layout',
          () async {
        final secretKey = _generateKey();
        final data = 'test';
        // "test" → JSON '"test"' → 6 UTF-8 bytes
        const plaintextLen = 6;

        final encrypted = await AesGcmEncryption.encrypt(data, secretKey);

        // Total length must be nonce(12) + plaintext(6) + tag(16) = 34
        expect(
          encrypted.length,
          AesGcmEncryption.nonceSize + plaintextLen + AesGcmEncryption.authTagSize,
        );
      });

      test('auth tag is verified: tampered tag returns null', () async {
        final secretKey = _generateKey();
        final data = {'path': '~/Documents/project'};

        final encrypted = await AesGcmEncryption.encrypt(data, secretKey);

        // Flip the last byte (inside the 16-byte auth tag)
        final tampered = Uint8List.fromList(encrypted);
        tampered[tampered.length - 1] ^= 0xFF;

        final result = await AesGcmEncryption.decrypt(tampered, secretKey);
        expect(result, isNull);
      });

      test('roundtrip preserves session metadata format', () async {
        final secretKey = _generateKey();
        // Typical session metadata as sent by the server
        final metadata = {
          'path': '~/Documents/project',
          'summary': 'Working on Flutter app',
        };

        final encrypted = await AesGcmEncryption.encrypt(metadata, secretKey);
        final decrypted = await AesGcmEncryption.decrypt(encrypted, secretKey);

        expect(decrypted, equals(metadata));
      });
    });

    group('Edge Cases', () {
      test('encryption works with byte value 255', () async {
        final secretKey = _generateKey();
        final originalData = [255, 254, 253, 0, 1, 2];

        final encrypted = await AesGcmEncryption.encrypt(originalData,
            secretKey,);
        final decrypted = await AesGcmEncryption.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encryption works with null values in object', () async {
        final secretKey = _generateKey();
        final originalData = {
          'value': null,
          'other': 'test',
        };

        final encrypted = await AesGcmEncryption.encrypt(originalData,
            secretKey,);
        final decrypted = await AesGcmEncryption.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encryption works with boolean values', () async {
        final secretKey = _generateKey();
        final originalData = {
          'trueValue': true,
          'falseValue': false,
          'mixed': true,
        };

        final encrypted = await AesGcmEncryption.encrypt(originalData,
            secretKey,);
        final decrypted = await AesGcmEncryption.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encryption works with nested objects', () async {
        final secretKey = _generateKey();
        final originalData = {
          'level1': {
            'level2': {
              'level3': {
                'value': 'deep',
              },
            },
          },
        };

        final encrypted = await AesGcmEncryption.encrypt(originalData,
            secretKey,);
        final decrypted = await AesGcmEncryption.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });
    });

    group('Isolate encryption path (send path off the UI isolate)', () {
      test('encryptBatch output layout is consumed by decryptBatch',
          () async {
        final secretKey = _generateKey();
        final items = <dynamic>[
          {'message': 'one'},
          'two',
          3,
          ['four'],
        ];

        final encrypted = await AesGcmEncryption.encryptBatch(
          items,
          secretKey,
        );
        expect(encrypted.length, items.length);
        for (final blob in encrypted) {
          // [12-byte nonce][ciphertext][16-byte auth tag], no version byte.
          expect(blob.length,
              greaterThanOrEqualTo(AesGcmEncryption.nonceSize +
                  AesGcmEncryption.authTagSize,),);
        }

        final decrypted = await AesGcmEncryption.decryptBatch(
          encrypted,
          secretKey,
        );
        expect(decrypted, equals(items));
      });

      test('encryptBatch rejects wrong key size like encrypt', () async {
        final wrongKey = Uint8List(16); // Too short

        expect(
          () => AesGcmEncryption.encryptBatch(['data'], wrongKey),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('encryptInIsolate roundtrips through decryptInIsolate', () async {
        final key = _generateKey();
        final encryptor = AES256Encryption(key);
        final items = <dynamic>[
          {
            'role': 'user',
            'content': 'Hello from the send path',
            'meta': {'localId': 'abc123'},
          },
          {'nested': {'list': [1, 2, 3]}},
        ];

        final encrypted = await encryptor.encryptInIsolate(items);

        // Same wire shape as encrypt(): leading version byte 0 per item.
        expect(encrypted.length, items.length);
        for (final blob in encrypted) {
          expect(blob[0], 0);
        }

        final decrypted = await encryptor.decryptInIsolate(encrypted);
        expect(decrypted, equals(items));
      });

      test('encryptInIsolate output decrypts on the main thread', () async {
        final key = _generateKey();
        final encryptor = AES256Encryption(key);
        final original = {'message': 'cross-isolate parity'};

        final encrypted = await encryptor.encryptInIsolate([original]);
        final decrypted = await AesGcmEncryption.decrypt(
          encrypted.first.sublist(1), // strip version byte
          key,
        );

        expect(decrypted, equals(original));
      });

      test('main-thread encrypt output decrypts through decryptInIsolate '
          '(reverse parity)', () async {
        final key = _generateKey();
        final encryptor = AES256Encryption(key);
        final original = {'message': 'fallback parity'};

        final encrypted = await encryptor.encrypt([original]);
        final decrypted = await encryptor.decryptInIsolate(encrypted);

        expect(decrypted, equals([original]));
      });

      test('encryptInIsolate with empty batch returns empty', () async {
        final encryptor = AES256Encryption(_generateKey());
        expect(await encryptor.encryptInIsolate([]), isEmpty);
      });

      test('encryptRawRecord stays wire-compatible across the isolate hop',
          () async {
        final key = _generateKey();
        final sessionEncryption = SessionEncryption(
          sessionId: 'test-session',
          encryptor: AES256Encryption(key),
          decryptor: AES256Encryption(key),
          cache: EncryptionCache(),
        );
        final record = {
          'type': 'user',
          'text': 'one tap, one logical message',
        };

        // Production send path: base64(version-byte + nonce+ct+tag).
        final encoded = await sessionEncryption.encryptRawRecord(record);
        final blob = Base64Utils.decode(encoded, Encoding.base64);
        expect(blob[0], 0);

        final decrypted = await AesGcmEncryption.decrypt(
          blob.sublist(1),
          key,
        );
        expect(decrypted, equals(record));
      });
    });
  });
}

/// Helper function to generate a random test key
Uint8List _generateKey() {
  final random = Random.secure();
  final key = Uint8List(32);
  for (int i = 0; i < 32; i++) {
    key[i] = random.nextInt(256);
  }
  return key;
}
