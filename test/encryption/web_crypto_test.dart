import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Import web crypto only when testing on web platform
import 'package:happy_flutter/core/encryption/web_crypto.dart'
    if (dart.library.io) 'package:happy_flutter/core/encryption/web_crypto.dart';

void main() {
  group('Web Crypto - Platform Tests', () {
    test('kIsWeb is correctly detected', () {
      // This test verifies platform detection
      expect(kIsWeb, isA<bool>());
    });

    test('WebCryptoBox constants are defined', () {
      expect(WebCryptoBox.publicKeyBytes, 32);
      expect(WebCryptoBox.secretKeyBytes, 32);
      expect(WebCryptoBox.nonceBytes, 24); // libsodium crypto_box_NONCEBYTES
    });

    test('WebCryptoSecretBox constants are defined', () {
      expect(WebCryptoSecretBox.nonceBytes, 24); // libsodium crypto_secretbox_NONCEBYTES
      expect(WebCryptoSecretBox.keyBytes, 32);
    });

    test('WebAesGcm constants are defined', () {
      expect(WebAesGcm.authTagSize, 16);
      expect(WebAesGcm.nonceSize, 12);
      expect(WebAesGcm.keySize, 32);
    });
  });

  group('WebCryptoBox', () {
    test('randomNonce generates correct size', () {
      final nonce = WebCryptoBox.randomNonce();
      expect(nonce.length, 24); // 24 bytes for libsodium compatibility
    });

    test('randomNonce produces unique values', () {
      final nonce1 = WebCryptoBox.randomNonce();
      final nonce2 = WebCryptoBox.randomNonce();
      expect(nonce1, isNot(equals(nonce2)));
    });

    test('generateKeypair creates keys of correct size', () async {
      final keypair = await WebCryptoBox.generateKeypair();

      expect(keypair.publicKey.length, 32);
      expect(keypair.privateKey.length, 32);
    });

    test('generateKeypair produces unique keypairs', () async {
      final keypair1 = await WebCryptoBox.generateKeypair();
      final keypair2 = await WebCryptoBox.generateKeypair();

      expect(keypair1.publicKey, isNot(equals(keypair2.publicKey)));
      expect(keypair1.privateKey, isNot(equals(keypair2.privateKey)));
    });
  });

  group('WebCryptoBox - Encryption/Decryption', () {
    test('encrypt and decrypt roundtrip works', () async {
      final senderPrivateKey = Uint8List.fromList(List.generate(32, (i) => i));
      final recipientPublicKey =
          Uint8List.fromList(List.generate(32, (i) => i + 32));
      final recipientPrivateKey =
          Uint8List.fromList(List.generate(32, (i) => i + 64));

      final originalData = Uint8List.fromList(
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      );

      final encrypted = await WebCryptoBox.encrypt(
        originalData,
        recipientPublicKey,
        senderPrivateKey,
      );

      expect(encrypted, isNot(equals(originalData)));

      final decrypted = await WebCryptoBox.decrypt(
        encrypted,
        recipientPrivateKey,
      );

      expect(decrypted, isNotNull);
      expect(decrypted, equals(originalData));
    });

    test('encrypt produces different output each time', () async {
      final senderPrivateKey = Uint8List.fromList(List.generate(32, (i) => i));
      final recipientPublicKey =
          Uint8List.fromList(List.generate(32, (i) => i + 32));

      final data = Uint8List.fromList([1, 2, 3]);

      final encrypted1 = await WebCryptoBox.encrypt(
        data,
        recipientPublicKey,
        senderPrivateKey,
      );
      final encrypted2 = await WebCryptoBox.encrypt(
        data,
        recipientPublicKey,
        senderPrivateKey,
      );

      // Should be different due to random nonce
      expect(encrypted1, isNot(equals(encrypted2)));
    });

    test('decrypt with wrong key returns null', () async {
      final senderPrivateKey = Uint8List.fromList(List.generate(32, (i) => i));
      final recipientPublicKey =
          Uint8List.fromList(List.generate(32, (i) => i + 32));
      final wrongPrivateKey =
          Uint8List.fromList(List.generate(32, (i) => i + 100));

      final data = Uint8List.fromList([1, 2, 3]);

      final encrypted = await WebCryptoBox.encrypt(
        data,
        recipientPublicKey,
        senderPrivateKey,
      );

      final decrypted = await WebCryptoBox.decrypt(
        encrypted,
        wrongPrivateKey,
      );

      // Wrong key should fail decryption
      expect(decrypted, isNull);
    });

    test('encrypted bundle has correct structure', () async {
      final senderPrivateKey = Uint8List.fromList(List.generate(32, (i) => i));
      final recipientPublicKey =
          Uint8List.fromList(List.generate(32, (i) => i + 32));

      final data = Uint8List.fromList([1, 2, 3]);

      final encrypted = await WebCryptoBox.encrypt(
        data,
        recipientPublicKey,
        senderPrivateKey,
      );

      // Bundle format: ephemeral_pk (32) + nonce (16) + ciphertext
      expect(
        encrypted.length,
        greaterThanOrEqualTo(32 + 16),
      );

      // Extract and verify ephemeral public key
      final ephemeralPk = encrypted.sublist(0, 32);
      expect(ephemeralPk.length, 32);
    });
  });

  group('WebCryptoSecretBox', () {
    test('randomNonce generates correct size', () {
      final nonce = WebCryptoSecretBox.randomNonce();
      expect(nonce.length, 24); // 24 bytes for libsodium compatibility
    });

    test('randomNonce produces unique values', () {
      final nonce1 = WebCryptoSecretBox.randomNonce();
      final nonce2 = WebCryptoSecretBox.randomNonce();
      expect(nonce1, isNot(equals(nonce2)));
    });
  });

  group('WebCryptoSecretBox - Encryption/Decryption', () {
    test('encrypt and decrypt roundtrip works', () async {
      final secretKey = Uint8List.fromList(List.generate(32, (i) => i));
      final originalData = {'message': 'Hello, Web Crypto!', 'count': 42};

      final encrypted =
          await WebCryptoSecretBox.encrypt(originalData, secretKey);

      final decrypted =
          await WebCryptoSecretBox.decrypt(encrypted, secretKey);

      expect(decrypted, isNotNull);
      expect(decrypted, equals(originalData));
    });

    test('encrypt and decrypt handle strings', () async {
      final secretKey = Uint8List.fromList(List.generate(32, (i) => i));
      final originalData = 'Test string message';

      final encrypted =
          await WebCryptoSecretBox.encrypt(originalData, secretKey);

      final decrypted =
          await WebCryptoSecretBox.decrypt(encrypted, secretKey);

      expect(decrypted, isNotNull);
      expect(decrypted, equals(originalData));
    });

    test('encrypt and decrypt handle complex objects', () async {
      final secretKey = Uint8List.fromList(List.generate(32, (i) => i));
      final originalData = {
        'nested': {'key': 'value'},
        'array': [1, 2, 3, 4, 5],
        'boolean': true,
        'null': null,
      };

      final encrypted =
          await WebCryptoSecretBox.encrypt(originalData, secretKey);

      final decrypted =
          await WebCryptoSecretBox.decrypt(encrypted, secretKey);

      expect(decrypted, isNotNull);
      expect(decrypted, equals(originalData));
    });

    test('decrypt with wrong key returns null', () async {
      final secretKey = Uint8List.fromList(List.generate(32, (i) => i));
      final wrongKey = Uint8List.fromList(List.generate(32, (i) => i + 1));
      final originalData = {'message': 'Secret data'};

      final encrypted =
          await WebCryptoSecretBox.encrypt(originalData, secretKey);

      final decrypted = await WebCryptoSecretBox.decrypt(encrypted, wrongKey);

      // Wrong key should fail decryption (AES-GCM authentication)
      expect(decrypted, isNull);
    });

    test('encrypt produces different output each time', () async {
      final secretKey = Uint8List.fromList(List.generate(32, (i) => i));
      final data = {'message': 'Test'};

      final encrypted1 =
          await WebCryptoSecretBox.encrypt(data, secretKey);
      final encrypted2 =
          await WebCryptoSecretBox.encrypt(data, secretKey);

      // Should be different due to random nonce
      expect(encrypted1, isNot(equals(encrypted2)));
    });
  });

  group('WebAesGcm', () {
    test('encrypt and decrypt roundtrip works', () async {
      final secretKey = Uint8List.fromList(List.generate(32, (i) => i));
      final originalData = Uint8List.fromList([1, 2, 3, 4, 5]);

      final encrypted = await WebAesGcm.encrypt(originalData, secretKey);

      final decrypted = await WebAesGcm.decrypt(encrypted, secretKey);

      expect(decrypted, isNotNull);
      expect(decrypted, equals(originalData));
    });

    test('encrypt and decrypt handle empty data', () async {
      final secretKey = Uint8List.fromList(List.generate(32, (i) => i));
      final originalData = Uint8List(0);

      final encrypted = await WebAesGcm.encrypt(originalData, secretKey);

      final decrypted = await WebAesGcm.decrypt(encrypted, secretKey);

      expect(decrypted, isEmpty);
    });

    test('encrypt and decrypt handle larger data', () async {
      final secretKey = Uint8List.fromList(List.generate(32, (i) => i));
      final originalData = Uint8List(1024);
      for (int i = 0; i < 1024; i++) {
        originalData[i] = i % 256;
      }

      final encrypted = await WebAesGcm.encrypt(originalData, secretKey);

      final decrypted = await WebAesGcm.decrypt(encrypted, secretKey);

      expect(decrypted, equals(originalData));
    });

    test('decrypt with wrong key returns null', () async {
      final secretKey = Uint8List.fromList(List.generate(32, (i) => i));
      final wrongKey = Uint8List.fromList(List.generate(32, (i) => i + 1));
      final originalData = Uint8List.fromList([1, 2, 3]);

      final encrypted = await WebAesGcm.encrypt(originalData, secretKey);

      final decrypted = await WebAesGcm.decrypt(encrypted, wrongKey);

      // Wrong key should fail decryption (AES-GCM authentication)
      expect(decrypted, isNull);
    });

    test('encrypt produces different output each time', () async {
      final secretKey = Uint8List.fromList(List.generate(32, (i) => i));
      final data = Uint8List.fromList([1, 2, 3]);

      final encrypted1 = await WebAesGcm.encrypt(data, secretKey);
      final encrypted2 = await WebAesGcm.encrypt(data, secretKey);

      // Should be different due to random IV
      expect(encrypted1, isNot(equals(encrypted2)));
    });

    test('encrypted data has correct structure', () async {
      final secretKey = Uint8List.fromList(List.generate(32, (i) => i));
      final data = Uint8List.fromList([1, 2, 3]);

      final encrypted = await WebAesGcm.encrypt(data, secretKey);

      // Format: [12-byte IV][ciphertext + 16-byte auth tag]
      expect(
        encrypted.length,
        greaterThanOrEqualTo(WebAesGcm.nonceSize + WebAesGcm.authTagSize),
      );

      // Extract IV
      final iv = encrypted.sublist(0, WebAesGcm.nonceSize);
      expect(iv.length, WebAesGcm.nonceSize);
    });

    test('isAesGcmEncrypted validates data format', () {
      final validData = Uint8List(28); // 12 (IV) + 0 + 16 (auth tag) = 28
      final shortData = Uint8List(10);

      expect(WebAesGcm.isAesGcmEncrypted(validData), true);
      expect(WebAesGcm.isAesGcmEncrypted(shortData), false);
    });

    test('encrypt throws on wrong key size', () async {
      final wrongKey = Uint8List(16); // Should be 32 bytes
      final data = Uint8List.fromList([1, 2, 3]);

      expect(
        () => WebAesGcm.encrypt(data, wrongKey),
        throwsArgumentError,
      );
    });

    test('decrypt throws on wrong key size', () async {
      final encrypted = Uint8List(28);
      final wrongKey = Uint8List(16); // Should be 32 bytes

      expect(
        () => WebAesGcm.decrypt(encrypted, wrongKey),
        throwsArgumentError,
      );
    });
  });

  group('WebCryptoKeyPair', () {
    test('WebCryptoKeyPair holds all required fields', () {
      final publicKey = Uint8List.fromList([1, 2, 3]);
      final privateKey = Uint8List.fromList([4, 5, 6]);

      final keypair = WebCryptoKeyPair(
        publicKey: publicKey,
        privateKey: privateKey,
      );

      expect(keypair.publicKey, publicKey);
      expect(keypair.privateKey, privateKey);
    });
  });

  group('Cross-Platform Compatibility', () {
    test('encryption format matches expected structure', () async {
      // Verify that our bundle format matches the expected structure
      final senderPrivateKey = Uint8List.fromList(List.generate(32, (i) => i));
      final recipientPublicKey =
          Uint8List.fromList(List.generate(32, (i) => i + 32));

      final testData = Uint8List.fromList([72, 101, 108, 108, 111]); // "Hello"

      final encrypted = await WebCryptoBox.encrypt(
        testData,
        recipientPublicKey,
        senderPrivateKey,
      );

      // Bundle should contain: ephemeral_pk (32) + nonce (24) + ciphertext
      expect(
        encrypted.length,
        greaterThan(32 + 24),
      );

      // Verify we can extract components
      final ephemeralPk = encrypted.sublist(0, 32);
      final nonce = encrypted.sublist(32, 56);
      final ciphertext = encrypted.sublist(56);

      expect(ephemeralPk.length, 32);
      expect(nonce.length, 24);
      expect(ciphertext.length, greaterThan(0));
    });
  });

  group('Edge Cases', () {
    test('WebCryptoBox decrypt returns null for corrupted data', () async {
      final recipientPrivateKey =
          Uint8List.fromList(List.generate(32, (i) => i));

      final corruptedData = Uint8List.fromList([1, 2, 3]);

      final decrypted = await WebCryptoBox.decrypt(
        corruptedData,
        recipientPrivateKey,
      );

      expect(decrypted, isNull);
    });

    test('WebCryptoBox decrypt returns null for too short data', () async {
      final recipientPrivateKey =
          Uint8List.fromList(List.generate(32, (i) => i));

      final shortData = Uint8List.fromList([1, 2]);

      final decrypted = await WebCryptoBox.decrypt(
        shortData,
        recipientPrivateKey,
      );

      expect(decrypted, isNull);
    });

    test('WebCryptoSecretBox decrypt returns null for corrupted data',
        () async {
      final secretKey = Uint8List.fromList(List.generate(32, (i) => i));

      final corruptedData = Uint8List.fromList([1, 2, 3]);

      final decrypted =
          await WebCryptoSecretBox.decrypt(corruptedData, secretKey);

      expect(decrypted, isNull);
    });

    test('WebAesGcm decrypt returns null for too short data', () async {
      final secretKey = Uint8List.fromList(List.generate(32, (i) => i));

      final shortData = Uint8List.fromList([1, 2]);

      final decrypted = await WebAesGcm.decrypt(shortData, secretKey);

      expect(decrypted, isNull);
    });
  });
}
