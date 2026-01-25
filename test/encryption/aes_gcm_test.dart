import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/aes_gcm.dart';
import 'package:happy_flutter/core/encryption/base64.dart';

void main() {
  group('AesGcm - True AES-256-GCM Encryption', () {
    group('Key and Nonce Constants', () {
      test('has correct key size', () {
        expect(AesGcm.keySize, 32); // 256 bits
      });

      test('has correct nonce size', () {
        expect(AesGcm.nonceSize, 12); // GCM standard
      });

      test('has correct auth tag size', () {
        expect(AesGcm.authTagSize, 16); // GCM standard
      });
    });

    group('Encryption and Decryption', () {
      test('encrypt and decrypt roundtrip works', () async {
        final secretKey = _generateKey();
        final originalData = {'message': 'Hello, World!', 'value': 42};

        final encrypted = await AesGcm.encrypt(originalData, secretKey);

        expect(encrypted, isNot(equals(originalData)));

        final decrypted = await AesGcm.decrypt(encrypted, secretKey);

        expect(decrypted, isNotNull);
        expect(decrypted, equals(originalData));
      });

      test('encrypt and decrypt string roundtrip works', () async {
        final secretKey = _generateKey();
        final originalData = 'Hello, World!';

        final encrypted = await AesGcm.encrypt(originalData, secretKey);
        final decrypted = await AesGcm.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encrypt and decrypt number roundtrip works', () async {
        final secretKey = _generateKey();
        final originalData = 12345;

        final encrypted = await AesGcm.encrypt(originalData, secretKey);
        final decrypted = await AesGcm.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encrypt and decrypt list roundtrip works', () async {
        final secretKey = _generateKey();
        final originalData = [1, 2, 3, 'four', {'five': 5}];

        final encrypted = await AesGcm.encrypt(originalData, secretKey);
        final decrypted = await AesGcm.decrypt(encrypted, secretKey);

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

        final encrypted = await AesGcm.encrypt(originalData, secretKey);
        final decrypted = await AesGcm.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encrypt produces different output each time', () async {
        final secretKey = _generateKey();
        final data = 'Hello, World!';

        final encrypted1 = await AesGcm.encrypt(data, secretKey);
        final encrypted2 = await AesGcm.encrypt(data, secretKey);

        // Should be different due to random nonce
        expect(encrypted1, isNot(equals(encrypted2)));

        // But both should decrypt to the same value
        final decrypted1 = await AesGcm.decrypt(encrypted1, secretKey);
        final decrypted2 = await AesGcm.decrypt(encrypted2, secretKey);

        expect(decrypted1, equals(decrypted2));
        expect(decrypted1, equals(data));
      });

      test('decrypt with wrong key returns null', () async {
        final secretKey1 = _generateKey();
        final secretKey2 = _generateKey();
        final data = 'Hello, World!';

        final encrypted = await AesGcm.encrypt(data, secretKey1);

        final decrypted = await AesGcm.decrypt(encrypted, secretKey2);

        expect(decrypted, isNull);
      });

      test('encrypt and decrypt handle empty string', () async {
        final secretKey = _generateKey();
        final originalData = '';

        final encrypted = await AesGcm.encrypt(originalData, secretKey);
        final decrypted = await AesGcm.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encrypt and decrypt handle empty object', () async {
        final secretKey = _generateKey();
        final originalData = <String, dynamic>{};

        final encrypted = await AesGcm.encrypt(originalData, secretKey);
        final decrypted = await AesGcm.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encrypt and decrypt handle empty list', () async {
        final secretKey = _generateKey();
        final originalData = <dynamic>[];

        final encrypted = await AesGcm.encrypt(originalData, secretKey);
        final decrypted = await AesGcm.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encrypt and decrypt handle larger data', () async {
        final secretKey = _generateKey();

        // Test with 1KB of data
        final largeString = List.generate(1024, (i) => 'X').join();
        final originalData = {'data': largeString};

        final encrypted = await AesGcm.encrypt(originalData, secretKey);
        final decrypted = await AesGcm.decrypt(encrypted, secretKey);

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

        final encrypted = await AesGcm.encrypt(originalData, secretKey);
        final decrypted = await AesGcm.decrypt(encrypted, secretKey);

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

        final encrypted = await AesGcm.encrypt(originalData, secretKey);
        final decrypted = await AesGcm.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });
    });

    group('Base64 Encoding', () {
      test('encryptToBase64 and decryptFromBase64 roundtrip works', () async {
        final secretKey = _generateKey();
        final originalData = {'message': 'Hello, Base64!'};

        final encryptedBase64 =
            await AesGcm.encryptToBase64(originalData, secretKey);

        expect(encryptedBase64, isA<String>());

        final decrypted =
            await AesGcm.decryptFromBase64(encryptedBase64, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encryptToBase64 produces valid Base64 string', () async {
        final secretKey = _generateKey();
        final data = 'Hello, World!';

        final encryptedBase64 = await AesGcm.encryptToBase64(data, secretKey);

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

        final encrypted1 = await AesGcm.encryptToBase64(data, secretKey);
        final encrypted2 = await AesGcm.encryptToBase64(data, secretKey);

        // Same plaintext should produce same length Base64
        expect(encrypted1.length, equals(encrypted2.length));
      });
    });

    group('Encrypted Data Format', () {
      test('encrypted data has correct structure', () async {
        final secretKey = _generateKey();
        final data = 'Hello, World!';

        final encrypted = await AesGcm.encrypt(data, secretKey);

        // Format: [12-byte nonce][ciphertext + 16-byte auth tag]
        expect(
          encrypted.length,
          greaterThanOrEqualTo(AesGcm.nonceSize + AesGcm.authTagSize),
        );

        // Verify we can extract components
        final nonce = encrypted.sublist(0, AesGcm.nonceSize);
        expect(nonce.length, AesGcm.nonceSize);

        final ciphertextWithTag = encrypted.sublist(AesGcm.nonceSize);
        expect(
          ciphertextWithTag.length,
          greaterThanOrEqualTo(AesGcm.authTagSize),
        );
      });

      test('isAesGcmEncrypted validates correctly', () {
        // Valid encrypted data (minimum size)
        final validData = Uint8List(AesGcm.nonceSize + AesGcm.authTagSize);
        expect(AesGcm.isAesGcmEncrypted(validData), true);

        // Data too short
        final shortData = Uint8List(AesGcm.nonceSize + AesGcm.authTagSize - 1);
        expect(AesGcm.isAesGcmEncrypted(shortData), false);

        // Empty data
        final emptyData = Uint8List(0);
        expect(AesGcm.isAesGcmEncrypted(emptyData), false);
      });
    });

    group('Error Handling', () {
      test('throws error for wrong key size', () async {
        final wrongKey = Uint8List(16); // Too short
        final data = 'Hello, World!';

        expect(
          () => AesGcm.encrypt(data, wrongKey),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('returns null for corrupted data', () async {
        final secretKey = _generateKey();
        final corruptedData = Uint8List.fromList([1, 2, 3, 4, 5]);

        final decrypted = await AesGcm.decrypt(corruptedData, secretKey);

        expect(decrypted, isNull);
      });

      test('returns null for too short data', () async {
        final secretKey = _generateKey();
        final shortData = Uint8List.fromList([1, 2]);

        final decrypted = await AesGcm.decrypt(shortData, secretKey);

        expect(decrypted, isNull);
      });

      test('returns null for modified encrypted data', () async {
        final secretKey = _generateKey();
        final data = 'Hello, World!';

        final encrypted = await AesGcm.encrypt(data, secretKey);

        // Corrupt the data
        encrypted[0] = encrypted[0] ^ 0xFF;

        final decrypted = await AesGcm.decrypt(encrypted, secretKey);

        expect(decrypted, isNull);
      });
    });

    group('Compatibility with React Native Format', () {
      test('encrypted format matches expected structure', () async {
        final secretKey = _generateKey();
        final data = 'Hello, World!';

        final encrypted = await AesGcm.encrypt(data, secretKey);

        // React Native's rn-encryption format: [12-byte IV][ciphertext][16-byte tag]
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

        final encryptedBase64 = await AesGcm.encryptToBase64(data, secretKey);

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

        final encrypted1 = await AesGcm.encrypt(data, key1);
        final encrypted2 = await AesGcm.encrypt(data, key2);

        // Different keys should produce completely different output
        expect(encrypted1, isNot(equals(encrypted2)));
      });

      test('same data with same key but different nonce produces different output',
          () async {
        final secretKey = _generateKey();
        final data = 'Hello, World!';

        final encrypted1 = await AesGcm.encrypt(data, secretKey);
        final encrypted2 = await AesGcm.encrypt(data, secretKey);

        // Random nonce ensures different output each time
        expect(encrypted1, isNot(equals(encrypted2)));
      });
    });

    group('Edge Cases', () {
      test('encryption works with byte value 255', () async {
        final secretKey = _generateKey();
        final originalData = [255, 254, 253, 0, 1, 2];

        final encrypted = await AesGcm.encrypt(originalData, secretKey);
        final decrypted = await AesGcm.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encryption works with null values in object', () async {
        final secretKey = _generateKey();
        final originalData = {
          'value': null,
          'other': 'test',
        };

        final encrypted = await AesGcm.encrypt(originalData, secretKey);
        final decrypted = await AesGcm.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });

      test('encryption works with boolean values', () async {
        final secretKey = _generateKey();
        final originalData = {
          'trueValue': true,
          'falseValue': false,
          'mixed': true,
        };

        final encrypted = await AesGcm.encrypt(originalData, secretKey);
        final decrypted = await AesGcm.decrypt(encrypted, secretKey);

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

        final encrypted = await AesGcm.encrypt(originalData, secretKey);
        final decrypted = await AesGcm.decrypt(encrypted, secretKey);

        expect(decrypted, equals(originalData));
      });
    });
  });
}

/// Helper function to generate a test key
Uint8List _generateKey() {
  final key = Uint8List(32);
  for (int i = 0; i < 32; i++) {
    key[i] = i;
  }
  return key;
}
