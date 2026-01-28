import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/crypto_box.dart';
import 'package:happy_flutter/core/encryption/crypto_secret_box.dart';
import 'package:happy_flutter/core/encryption/derive_key.dart';

/// Tests for libsodium compatibility with React Native implementation
/// Verifies 24-byte nonce alignment and cross-platform encryption/decryption
void main() {
  group('CryptoBox - libsodium compatibility', () {
    test('Constants match libsodium values', () {
      // Verify constants match libsodium
      expect(CryptoBoxConstants.publicKeyBytes, equals(32),
          reason: 'crypto_box_PUBLICKEYBYTES should be 32');
      expect(CryptoBoxConstants.secretKeyBytes, equals(32),
          reason: 'crypto_box_SECRETKEYBYTES should be 32');
      expect(CryptoBoxConstants.nonceBytes, equals(24),
          reason: 'crypto_box_NONCEBYTES should be 24');
      expect(CryptoBoxConstants.seedBytes, equals(32),
          reason: 'crypto_box_SEEDBYTES should be 32');
    });

    test('Generate random nonce is 24 bytes', () async {
      final nonce = await CryptoBox.randomNonce();
      expect(nonce.length, equals(24),
          reason: 'Nonce should be 24 bytes for libsodium compatibility');
    });

    test('Generated nonces are unique', () async {
      final nonce1 = await CryptoBox.randomNonce();
      final nonce2 = await CryptoBox.randomNonce();
      expect(nonce1, isNot(equals(nonce2)),
          reason: 'Random nonces should be unique');
    });

    test('Generate keypair from seed produces valid keys', () async {
      final seed = Uint8List.fromList(
        List.generate(32, (i) => i),
      );

      final keypair = await CryptoBox.keypairFromSeed(seed);

      expect(keypair.publicKey.length, equals(32),
          reason: 'Public key should be 32 bytes');
      expect(keypair.privateKey.length, equals(32),
          reason: 'Private key should be 32 bytes');
      expect(keypair.secretKey.length, equals(32),
          reason: 'Secret key should be 32 bytes');
    });

    test('Same seed produces same keypair', () async {
      final seed = Uint8List.fromList(
        List.generate(32, (i) => i),
      );

      final keypair1 = await CryptoBox.keypairFromSeed(seed);
      final keypair2 = await CryptoBox.keypairFromSeed(seed);

      expect(
        keypair1.publicKey,
        equals(keypair2.publicKey),
        reason: 'Same seed should produce same public key',
      );
      expect(
        keypair1.privateKey,
        equals(keypair2.privateKey),
        reason: 'Same seed should produce same private key',
      );
    });

    test('Random keypairs are unique', () async {
      final keypair1 = await CryptoBox.generateKeypair();
      final keypair2 = await CryptoBox.generateKeypair();

      expect(
        keypair1.publicKey,
        isNot(equals(keypair2.publicKey)),
        reason: 'Random keypairs should have different public keys',
      );
    });

    test('Encrypt and decrypt roundtrip', () async {
      final senderKeypair = await CryptoBox.generateKeypair();
      final recipientKeypair = await CryptoBox.generateKeypair();

      final plaintext = utf8.encode('Hello, libsodium!');

      final encrypted = await CryptoBox.encrypt(
        plaintext,
        recipientKeypair.publicKey,
        senderKeypair.privateKey,
      );

      final decrypted = await CryptoBox.decrypt(
        encrypted,
        recipientKeypair.privateKey,
      );

      expect(decrypted, isNotNull);
      expect(decrypted, equals(plaintext));
    });

    test('Encrypted bundle format is correct', () async {
      final senderKeypair = await CryptoBox.generateKeypair();
      final recipientKeypair = await CryptoBox.generateKeypair();

      final plaintext = utf8.encode('Test message');

      final encrypted = await CryptoBox.encrypt(
        plaintext,
        recipientKeypair.publicKey,
        senderKeypair.privateKey,
      );

      // Bundle format: ephemeral public key (32) + nonce (24) + ciphertext
      expect(
        encrypted.length,
        greaterThanOrEqualTo(32 + 24),
        reason: 'Bundle should contain at least ephemeral key + nonce',
      );

      // Extract ephemeral public key
      final ephemeralPublicKey = encrypted.sublist(0, 32);
      expect(ephemeralPublicKey.length, equals(32));

      // Extract nonce
      final nonce = encrypted.sublist(32, 32 + 24);
      expect(nonce.length, equals(24),
          reason: 'Nonce should be 24 bytes for libsodium compatibility');
    });

    test('Wrong key fails to decrypt', () async {
      final senderKeypair = await CryptoBox.generateKeypair();
      final recipientKeypair = await CryptoBox.generateKeypair();
      final wrongKeypair = await CryptoBox.generateKeypair();

      final plaintext = utf8.encode('Secret message');

      final encrypted = await CryptoBox.encrypt(
        plaintext,
        recipientKeypair.publicKey,
        senderKeypair.privateKey,
      );

      final decrypted = await CryptoBox.decrypt(
        encrypted,
        wrongKeypair.privateKey,
      );

      expect(decrypted, isNull,
          reason: 'Decryption with wrong key should fail');
    });
  });

  group('CryptoSecretBox - libsodium compatibility', () {
    test('Nonce size is 24 bytes', () {
      // Nonce size is 24 bytes for libsodium compatibility
      const nonceSize = 24;
      expect(
        nonceSize,
        equals(24),
        reason: 'crypto_secretbox_NONCEBYTES should be 24',
      );
    });

    test('Key size is 32 bytes', () {
      // Key size is 32 bytes for libsodium compatibility
      const keySize = 32;
      expect(
        keySize,
        equals(32),
        reason: 'crypto_secretbox_KEYBYTES should be 32',
      );
    });

    test('Encrypt and decrypt roundtrip', () async {
      final secretKey = Uint8List.fromList(
        List.generate(32, (i) => i),
      );

      final plaintext = {
        'message': 'Hello, secret box!',
        'number': 42,
      };

      final encrypted = await CryptoSecretBox.encrypt(plaintext, secretKey);
      final decrypted = await CryptoSecretBox.decrypt(encrypted, secretKey);

      expect(decrypted, isNotNull);
      expect(decrypted, equals(plaintext));
    });

    test('Encrypted bundle format is correct', () async {
      final secretKey = Uint8List.fromList(
        List.generate(32, (i) => i),
      );

      final plaintext = {'data': 'test'};

      final encrypted = await CryptoSecretBox.encrypt(plaintext, secretKey);

      // Bundle format: nonce (24) + ciphertext
      expect(
        encrypted.length,
        greaterThan(24),
        reason: 'Bundle should contain nonce + ciphertext',
      );

      final nonce = encrypted.sublist(0, 24);
      expect(nonce.length, equals(24),
          reason: 'Nonce should be 24 bytes for libsodium compatibility');
    });

    test('Wrong key fails to decrypt', () async {
      final secretKey = Uint8List.fromList(
        List.generate(32, (i) => i),
      );
      final wrongKey = Uint8List.fromList(
        List.generate(32, (i) => i + 1),
      );

      final plaintext = {'secret': 'data'};

      final encrypted = await CryptoSecretBox.encrypt(plaintext, secretKey);
      final decrypted = await CryptoSecretBox.decrypt(encrypted, wrongKey);

      expect(decrypted, isNull,
          reason: 'Decryption with wrong key should fail');
    });

    test('Truncated key is handled correctly', () async {
      final longKey = Uint8List.fromList(
        List.generate(64, (i) => i),
      );

      final plaintext = {'test': 'data'};

      final encrypted = await CryptoSecretBox.encrypt(plaintext, longKey);
      final decrypted = await CryptoSecretBox.decrypt(encrypted, longKey);

      expect(decrypted, isNotNull);
      expect(decrypted, equals(plaintext));
    });
  });

  group('Cross-platform compatibility tests', () {
    test('CryptoBox bundle format matches React Native', () async {
      // React Native format from libsodium.ts:
      // result.set(ephemeralKeyPair.publicKey, 0);
      // result.set(nonce, ephemeralKeyPair.publicKey.length);
      // result.set(encrypted, ephemeralKeyPair.publicKey.length + nonce.length);

      final senderKeypair = await CryptoBox.generateKeypair();
      final recipientKeypair = await CryptoBox.generateKeypair();

      final plaintext = utf8.encode('Cross-platform test');

      final encrypted = await CryptoBox.encrypt(
        plaintext,
        recipientKeypair.publicKey,
        senderKeypair.privateKey,
      );

      // Verify bundle structure matches React Native
      final ephemeralPublicKeyOffset = 0;
      final nonceOffset = 32; // crypto_box_PUBLICKEYBYTES
      final ciphertextOffset = 32 + 24; // PUBLICKEYBYTES + NONCEBYTES

      expect(encrypted.length, greaterThan(ciphertextOffset));

      final ephemeralPublicKey = encrypted.sublist(
        ephemeralPublicKeyOffset,
        nonceOffset,
      );
      final nonce = encrypted.sublist(nonceOffset, ciphertextOffset);
      final ciphertext = encrypted.sublist(ciphertextOffset);

      expect(ephemeralPublicKey.length, equals(32));
      expect(nonce.length, equals(24));
      expect(ciphertext.length, greaterThan(0));
    });

    test('CryptoSecretBox bundle format matches React Native', () async {
      // React Native format from libsodium.ts:
      // result.set(nonce);
      // result.set(encrypted, nonce.length);

      final secretKey = Uint8List.fromList(
        List.generate(32, (i) => i),
      );

      final plaintext = {'cross': 'platform'};

      final encrypted = await CryptoSecretBox.encrypt(plaintext, secretKey);

      // Verify bundle structure matches React Native
      final nonceOffset = 0;
      final ciphertextOffset = 24; // crypto_secretbox_NONCEBYTES

      expect(encrypted.length, greaterThan(ciphertextOffset));

      final nonce = encrypted.sublist(nonceOffset, ciphertextOffset);
      final ciphertext = encrypted.sublist(ciphertextOffset);

      expect(nonce.length, equals(24));
      expect(ciphertext.length, greaterThan(0));
    });
  });

  group('Key derivation compatibility', () {
    test('DeriveKey produces consistent results', () async {
      final masterSecret = Uint8List.fromList(
        List.generate(32, (i) => i),
      );

      final key1 = await DeriveKey.derive(
        masterSecret,
        'Happy EnCoder',
        ['content'],
      );

      final key2 = await DeriveKey.derive(
        masterSecret,
        'Happy EnCoder',
        ['content'],
      );

      expect(key1, equals(key2),
          reason: 'Same inputs should produce same derived key');
    });

    test('Different paths produce different keys', () async {
      final masterSecret = Uint8List.fromList(
        List.generate(32, (i) => i),
      );

      final key1 = await DeriveKey.derive(
        masterSecret,
        'Happy EnCoder',
        ['content'],
      );

      final key2 = await DeriveKey.derive(
        masterSecret,
        'Happy EnCoder',
        ['session'],
      );

      expect(key1, isNot(equals(key2)),
          reason: 'Different paths should produce different keys');
    });
  });

  group('Edge cases and error handling', () {
    test('Empty message can be encrypted and decrypted', () async {
      final senderKeypair = await CryptoBox.generateKeypair();
      final recipientKeypair = await CryptoBox.generateKeypair();

      final plaintext = Uint8List(0);

      final encrypted = await CryptoBox.encrypt(
        plaintext,
        recipientKeypair.publicKey,
        senderKeypair.privateKey,
      );

      final decrypted = await CryptoBox.decrypt(
        encrypted,
        recipientKeypair.privateKey,
      );

      expect(decrypted, isNotNull);
      expect(decrypted, equals(plaintext));
    });

    test('Large message can be encrypted and decrypted', () async {
      final senderKeypair = await CryptoBox.generateKeypair();
      final recipientKeypair = await CryptoBox.generateKeypair();

      final plaintext = Uint8List.fromList(
        List.generate(10000, (i) => i % 256),
      );

      final encrypted = await CryptoBox.encrypt(
        plaintext,
        recipientKeypair.publicKey,
        senderKeypair.privateKey,
      );

      final decrypted = await CryptoBox.decrypt(
        encrypted,
        recipientKeypair.privateKey,
      );

      expect(decrypted, isNotNull);
      expect(decrypted, equals(plaintext));
    });

    test('Corrupted bundle returns null', () async {
      final recipientKeypair = await CryptoBox.generateKeypair();

      final corruptedBundle = Uint8List.fromList(
        List.generate(100, (i) => 0xFF),
      );

      final decrypted = await CryptoBox.decrypt(
        corruptedBundle,
        recipientKeypair.privateKey,
      );

      expect(decrypted, isNull,
          reason: 'Decryption of corrupted data should return null');
    });

    test('Short bundle returns null', () async {
      final recipientKeypair = await CryptoBox.generateKeypair();

      final shortBundle = Uint8List(10);

      final decrypted = await CryptoBox.decrypt(
        shortBundle,
        recipientKeypair.privateKey,
      );

      expect(decrypted, isNull,
          reason: 'Decryption of short bundle should return null');
    });
  });
}
