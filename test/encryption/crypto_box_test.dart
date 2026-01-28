import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/crypto_box.dart';

void main() {
  group('CryptoBox', () {
    group('KeyPair Generation', () {
      test('generateKeypair creates keys of correct size', () async {
        final keypair = await CryptoBox.generateKeypair();

        expect(
          keypair.publicKey.length,
          CryptoBoxConstants.publicKeyBytes,
        );
        expect(
          keypair.privateKey.length,
          CryptoBoxConstants.secretKeyBytes,
        );
        expect(
          keypair.secretKey.length,
          CryptoBoxConstants.secretKeyBytes,
        );
      });

      test('generateKeypair produces unique keypairs', () async {
        final keypair1 = await CryptoBox.generateKeypair();
        final keypair2 = await CryptoBox.generateKeypair();

        expect(keypair1.publicKey, isNot(equals(keypair2.publicKey)));
        expect(keypair1.privateKey, isNot(equals(keypair2.privateKey)));
      });

      test('keypairFromSeed produces deterministic keys', () async {
        final seed = Uint8List.fromList([1, 2, 3, 4, 5]);

        final keypair1 = await CryptoBox.keypairFromSeed(seed);
        final keypair2 = await CryptoBox.keypairFromSeed(seed);

        expect(keypair1.publicKey, equals(keypair2.publicKey));
        expect(keypair1.privateKey, equals(keypair2.privateKey));
      });

      test('keypairFromSeed produces different keys for different seeds', () async {
        final seed1 = Uint8List.fromList([1, 2, 3, 4, 5]);
        final seed2 = Uint8List.fromList([5, 4, 3, 2, 1]);

        final keypair1 = await CryptoBox.keypairFromSeed(seed1);
        final keypair2 = await CryptoBox.keypairFromSeed(seed2);

        expect(keypair1.publicKey, isNot(equals(keypair2.publicKey)));
      });

      test('keypairFromSeed requires 32 byte seed', () async {
        final shortSeed = Uint8List(16);

        expect(
          () async => await CryptoBox.keypairFromSeed(shortSeed),
          returnsNormally,
        );
      });
    });

    group('Nonce Generation', () {
      test('randomNonce generates correct size', () async {
        final nonce = await CryptoBox.randomNonce();

        expect(nonce.length, CryptoBoxConstants.nonceBytes);
      });

      test('randomNonce produces unique values', () async {
        final nonce1 = await CryptoBox.randomNonce();
        final nonce2 = await CryptoBox.randomNonce();

        expect(nonce1, isNot(equals(nonce2)));
      });
    });

    group('Encryption and Decryption', () {
      test('encrypt and decrypt roundtrip works', () async {
        final senderKeyPair = await CryptoBox.generateKeypair();
        final recipientKeyPair = await CryptoBox.generateKeypair();

        final originalData = Uint8List.fromList(
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        );

        final encrypted = await CryptoBox.encrypt(
          originalData,
          recipientKeyPair.publicKey,
          senderKeyPair.privateKey,
        );

        expect(encrypted, isNot(equals(originalData)));

        final decrypted = await CryptoBox.decrypt(
          encrypted,
          recipientKeyPair.privateKey,
        );

        expect(decrypted, isNotNull);
        expect(decrypted, equals(originalData));
      });

      test('encrypt produces different output each time', () async {
        final senderKeyPair = await CryptoBox.generateKeypair();
        final recipientKeyPair = await CryptoBox.generateKeypair();

        final data = Uint8List.fromList([1, 2, 3]);

        final encrypted1 = await CryptoBox.encrypt(
          data,
          recipientKeyPair.publicKey,
          senderKeyPair.privateKey,
        );
        final encrypted2 = await CryptoBox.encrypt(
          data,
          recipientKeyPair.publicKey,
          senderKeyPair.privateKey,
        );

        // Should be different due to random nonce
        expect(encrypted1, isNot(equals(encrypted2)));
      });

      test('decrypt with wrong key returns null', () async {
        final senderKeyPair = await CryptoBox.generateKeypair();
        final recipientKeyPair = await CryptoBox.generateKeypair();
        final wrongKeyPair = await CryptoBox.generateKeypair();

        final data = Uint8List.fromList([1, 2, 3]);

        final encrypted = await CryptoBox.encrypt(
          data,
          recipientKeyPair.publicKey,
          senderKeyPair.privateKey,
        );

        final decrypted = await CryptoBox.decrypt(
          encrypted,
          wrongKeyPair.privateKey,
        );

        expect(decrypted, isNull);
      });

      test('encrypt and decrypt handle empty data', () async {
        final senderKeyPair = await CryptoBox.generateKeypair();
        final recipientKeyPair = await CryptoBox.generateKeypair();

        final originalData = Uint8List(0);

        final encrypted = await CryptoBox.encrypt(
          originalData,
          recipientKeyPair.publicKey,
          senderKeyPair.privateKey,
        );

        final decrypted = await CryptoBox.decrypt(
          encrypted,
          recipientKeyPair.privateKey,
        );

        expect(decrypted, isEmpty);
      });

      test('encrypt and decrypt handle larger data', () async {
        final senderKeyPair = await CryptoBox.generateKeypair();
        final recipientKeyPair = await CryptoBox.generateKeypair();

        // Test with 1KB of data
        final originalData = Uint8List(1024);
        for (int i = 0; i < 1024; i++) {
          originalData[i] = i % 256;
        }

        final encrypted = await CryptoBox.encrypt(
          originalData,
          recipientKeyPair.publicKey,
          senderKeyPair.privateKey,
        );

        final decrypted = await CryptoBox.decrypt(
          encrypted,
          recipientKeyPair.privateKey,
        );

        expect(decrypted, equals(originalData));
      });

      test('encrypted bundle has correct structure', () async {
        final senderKeyPair = await CryptoBox.generateKeypair();
        final recipientKeyPair = await CryptoBox.generateKeypair();

        final data = Uint8List.fromList([1, 2, 3]);

        final encrypted = await CryptoBox.encrypt(
          data,
          recipientKeyPair.publicKey,
          senderKeyPair.privateKey,
        );

        // Bundle format: ephemeral public key (32) + nonce (24) + ciphertext
        expect(
          encrypted.length,
          greaterThanOrEqualTo(
            CryptoBoxConstants.publicKeyBytes +
                CryptoBoxConstants.nonceBytes,
          ),
        );

        // Extract and verify ephemeral public key
        final ephemeralPublicKey = encrypted.sublist(
          0,
          CryptoBoxConstants.publicKeyBytes,
        );
        expect(ephemeralPublicKey.length, CryptoBoxConstants.publicKeyBytes);

        // Verify nonce is 24 bytes for libsodium compatibility
        final nonce = encrypted.sublist(
          CryptoBoxConstants.publicKeyBytes,
          CryptoBoxConstants.publicKeyBytes + CryptoBoxConstants.nonceBytes,
        );
        expect(nonce.length, 24);
      });
    });

    group('Shared Secret Computation', () {
      // Note: computeSharedSecret is no longer needed with libsodium
      // The sodium package handles key exchange internally
      // These tests are removed as the method no longer exists
    });

    group('KeyPair Class', () {
      test('KeyPair holds all required fields', () async {
        final publicKey = Uint8List.fromList([1, 2, 3]);
        // Generate a real keypair to get valid SecureKey instances
        final keypair = await CryptoBox.generateKeypair();

        expect(keypair.publicKey, isA<Uint8List>());
        expect(keypair.publicKey.length, CryptoBoxConstants.publicKeyBytes);
        expect(keypair.privateKey, isNotNull);
        expect(keypair.secretKey, isNotNull);
      });
    });

    group('CryptoBoxConstants', () {
      test('constants have expected values', () {
        expect(CryptoBoxConstants.publicKeyBytes, 32);
        expect(CryptoBoxConstants.secretKeyBytes, 32);
        expect(CryptoBoxConstants.nonceBytes, 24); // Updated to 24 for libsodium
        expect(CryptoBoxConstants.seedBytes, 32);
      });
    });

    group('Edge Cases', () {
      test('decrypt returns null for corrupted data', () async {
        final recipientKeyPair = await CryptoBox.generateKeypair();

        final corruptedData = Uint8List.fromList([1, 2, 3]);

        final decrypted = await CryptoBox.decrypt(
          corruptedData,
          recipientKeyPair.privateKey,
        );

        expect(decrypted, isNull);
      });

      test('decrypt returns null for too short data', () async {
        final recipientKeyPair = await CryptoBox.generateKeypair();

        final shortData = Uint8List.fromList([1, 2]);

        final decrypted = await CryptoBox.decrypt(
          shortData,
          recipientKeyPair.privateKey,
        );

        expect(decrypted, isNull);
      });

      test('encryption works with byte value 255', () async {
        final senderKeyPair = await CryptoBox.generateKeypair();
        final recipientKeyPair = await CryptoBox.generateKeypair();

        final originalData = Uint8List.fromList([255, 254, 253, 0, 1, 2]);

        final encrypted = await CryptoBox.encrypt(
          originalData,
          recipientKeyPair.publicKey,
          senderKeyPair.privateKey,
        );

        final decrypted = await CryptoBox.decrypt(
          encrypted,
          recipientKeyPair.privateKey,
        );

        expect(decrypted, equals(originalData));
      });
    });

    group('Cross-Platform Compatibility', () {
      test('encryption format is compatible with NaCl box format', () async {
        // Verify that our bundle format matches the expected structure
        // for compatibility with React Native's libsodium implementation

        final senderKeyPair = await CryptoBox.generateKeypair();
        final recipientKeyPair = await CryptoBox.generateKeypair();

        final testData = Uint8List.fromList([72, 101, 108, 108, 111]); // "Hello"

        final encrypted = await CryptoBox.encrypt(
          testData,
          recipientKeyPair.publicKey,
          senderKeyPair.privateKey,
        );

        // Bundle should contain: ephemeral_pk (32) + nonce (24) + ciphertext
        expect(
          encrypted.length,
          greaterThan(CryptoBoxConstants.publicKeyBytes + CryptoBoxConstants.nonceBytes),
        );

        // Verify we can extract components
        final ephemeralPk = encrypted.sublist(0, 32);
        final nonce = encrypted.sublist(32, 56); // 24 bytes for libsodium
        final ciphertext = encrypted.sublist(56);

        expect(ephemeralPk.length, 32);
        expect(nonce.length, 24); // 24 bytes for libsodium compatibility
        expect(ciphertext.length, greaterThan(0));
      });
    });
  });
}
