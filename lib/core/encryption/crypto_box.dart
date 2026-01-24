import 'dart:typed_data';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pointycastle/pointycastle.dart';

import 'web_crypto.dart' if (dart.library.html) 'web_crypto.dart';

/// Constants for encryption
class CryptoBoxConstants {
  static const int publicKeyBytes = 32;
  static const int secretKeyBytes = 32;
  static const int nonceBytes = 16; // IV size for AES-CBC
  static const int seedBytes = 32;
}

/// Simplified box encryption using AES-CBC
class CryptoBox {
  /// Generate a random nonce/IV
  static Uint8List randomNonce() {
    final random = Random.secure();
    final nonce = Uint8List(CryptoBoxConstants.nonceBytes);
    for (int i = 0; i < CryptoBoxConstants.nonceBytes; i++) {
      nonce[i] = random.nextInt(256);
    }
    return nonce;
  }

  /// Generate keypair from seed
  static KeyPair keypairFromSeed(Uint8List seed) {
    // Derive keypair from seed
    final digest = sha256.convert(seed);
    final expanded = Uint8List(64);
    expanded.setAll(0, digest.bytes);
    expanded.setAll(32, digest.bytes);

    final keypair = KeyPair(
      privateKey: expanded.sublist(0, 32),
      publicKey: expanded.sublist(32, 64),
      secretKey: expanded.sublist(0, 32),
    );
    return keypair;
  }

  /// Generate new random keypair
  static KeyPair generateKeypair() {
    final seed = Uint8List(CryptoBoxConstants.seedBytes);
    final random = Random.secure();
    for (int i = 0; i < CryptoBoxConstants.seedBytes; i++) {
      seed[i] = random.nextInt(256);
    }
    return keypairFromSeed(seed);
  }

  /// Encrypt data using public key (hybrid encryption)
  static Future<Uint8List> encrypt(
    Uint8List data,
    Uint8List recipientPublicKey,
    Uint8List senderSecretKey,
  ) async {
    if (kIsWeb) {
      return await WebCryptoBox.encrypt(
        data,
        recipientPublicKey,
        senderSecretKey,
      );
    }

    final ephemeralKeyPair = generateKeypair();
    final nonce = randomNonce();

    // Compute shared secret
    final sharedSecret = computeSharedSecret(
      senderSecretKey,
      recipientPublicKey,
    );

    // Use AES-CBC for encryption
    final keyParam = KeyParameter(sharedSecret);
    final ivParam = ParametersWithIV(keyParam, nonce);
    final params = PaddedBlockCipherParameters(ivParam, null);

    final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
    cipher.init(true, params);
    final encrypted = cipher.process(data);

    // Bundle format: ephemeral public key + iv + encrypted data
    final result = Uint8List(
      CryptoBoxConstants.publicKeyBytes +
      CryptoBoxConstants.nonceBytes +
      encrypted.length,
    );
    result.setAll(0, ephemeralKeyPair.publicKey);
    result.setAll(CryptoBoxConstants.publicKeyBytes, nonce);
    result.setAll(
      CryptoBoxConstants.publicKeyBytes + CryptoBoxConstants.nonceBytes,
      encrypted,
    );

    return result;
  }

  /// Decrypt encrypted bundle
  static Future<Uint8List?> decrypt(
    Uint8List encryptedBundle,
    Uint8List recipientSecretKey,
  ) async {
    if (kIsWeb) {
      return await WebCryptoBox.decrypt(
        encryptedBundle,
        recipientSecretKey,
      );
    }

    try {
      // Extract components: ephemeral public key + iv + encrypted data
      final ephemeralPublicKey = encryptedBundle.sublist(
        0,
        CryptoBoxConstants.publicKeyBytes,
      );
      final nonce = encryptedBundle.sublist(
        CryptoBoxConstants.publicKeyBytes,
        CryptoBoxConstants.publicKeyBytes + CryptoBoxConstants.nonceBytes,
      );
      final encrypted = encryptedBundle.sublist(
        CryptoBoxConstants.publicKeyBytes + CryptoBoxConstants.nonceBytes,
      );

      // Compute shared secret
      final sharedSecret = computeSharedSecret(
        recipientSecretKey,
        ephemeralPublicKey,
      );

      // Decrypt
      final keyParam = KeyParameter(sharedSecret);
      final ivParam = ParametersWithIV(keyParam, nonce);
      final params = PaddedBlockCipherParameters(ivParam, null);

      final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
      cipher.init(false, params);
      final decrypted = cipher.process(encrypted);

      return decrypted;
    } catch (e) {
      return null;
    }
  }

  /// Compute shared secret (simplified)
  static Uint8List computeSharedSecret(
    Uint8List privateKey,
    Uint8List publicKey,
  ) {
    // Simplified key derivation using SHA256
    final combined = Uint8List(64);
    combined.setAll(0, privateKey);
    combined.setAll(32, publicKey);
    final digest = sha256.convert(combined);
    return Uint8List.fromList(digest.bytes);
  }
}

/// KeyPair for box encryption
class KeyPair {
  final Uint8List publicKey;
  final Uint8List privateKey;
  final Uint8List secretKey;

  KeyPair({
    required this.privateKey,
    required this.publicKey,
    required this.secretKey,
  });
}
