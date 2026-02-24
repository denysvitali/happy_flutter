import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:sodium/sodium.dart';

import 'sodium_loader.dart';

/// Constants for encryption (libsodium compatible)
class CryptoBoxConstants {
  static const int publicKeyBytes = 32; // crypto_box_PUBLICKEYBYTES
  static const int secretKeyBytes = 32; // crypto_box_SECRETKEYBYTES
  static const int nonceBytes = 24; // crypto_box_NONCEBYTES (libsodium)
  static const int seedBytes = 32; // crypto_box_SEEDBYTES
  static const int macBytes = 16; // crypto_box_MACBYTES
}

/// CryptoBox encryption using libsodium (crypto_box_easy)
/// Compatible with React Native's @more-tech/react-native-libsodium
class CryptoBox {
  static Sodium? _sodium;

  /// Initialize sodium (lazy initialization)
  static Future<Sodium> get _sodiumInstance async {
    if (_sodium != null) return _sodium!;
    _sodium = await loadSodium();
    return _sodium!;
  }

  /// Generate a random nonce (24 bytes for libsodium compatibility)
  static Future<Uint8List> randomNonce() async {
    final sodium = await _sodiumInstance;
    final nonce = sodium.randombytes.buf(CryptoBoxConstants.nonceBytes);
    return nonce;
  }

  /// Generate keypair from seed (libsodium compatible)
  static Future<KeyPair> keypairFromSeed(Uint8List seed) async {
    final sodium = await _sodiumInstance;
    final seedKey = SecureKey.fromList(sodium, seed);
    final keypair = sodium.crypto.box.seedKeyPair(seedKey);
    seedKey.dispose();
    return KeyPair(
      publicKey: keypair.publicKey,
      privateKey: keypair.secretKey,
      secretKey: keypair.secretKey,
    );
  }

  /// Generate new random keypair
  static Future<KeyPair> generateKeypair() async {
    final sodium = await _sodiumInstance;
    final keypair = sodium.crypto.box.keyPair();

    return KeyPair(
      publicKey: keypair.publicKey,
      privateKey: keypair.secretKey,
      secretKey: keypair.secretKey,
    );
  }

  /// Encrypt data using public key (crypto_box_easy)
  /// Compatible with React Native's sodium.crypto_box_easy()
  /// Uses an ephemeral keypair so no sender secret key is needed.
  static Future<Uint8List> encrypt(
    Uint8List data,
    Uint8List recipientPublicKey,
  ) async {
    final sodium = await _sodiumInstance;
    final ephemeralKeyPair = await generateKeypair();
    final nonce = await randomNonce();

    try {
      // Encrypt using libsodium crypto_box_easy with the ephemeral key
      final encrypted = sodium.crypto.box.easy(
        message: data,
        nonce: nonce,
        publicKey: recipientPublicKey,
        secretKey: ephemeralKeyPair.secretKey,
      );

      // Bundle: ephemeral public key (32 bytes) + nonce (24 bytes) + ciphertext
      final result = Uint8List(
        CryptoBoxConstants.publicKeyBytes +
            CryptoBoxConstants.nonceBytes +
            encrypted.length,
      )
        ..setAll(0, ephemeralKeyPair.publicKey)
        ..setAll(CryptoBoxConstants.publicKeyBytes, nonce)
        ..setAll(
          CryptoBoxConstants.publicKeyBytes + CryptoBoxConstants.nonceBytes,
          encrypted,
        );

      return result;
    } finally {
      // Always dispose the ephemeral keypair to prevent memory leaks
      ephemeralKeyPair.dispose();
    }
  }

  /// Decrypt encrypted bundle (crypto_box_open_easy)
  /// Compatible with React Native's sodium.crypto_box_open_easy()
  static Future<Uint8List?> decrypt(
    Uint8List encryptedBundle,
    SecureKey recipientSecretKey,
  ) async {
    try {
      // Extract components: ephemeral public key (32 bytes)
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

      final sodium = await _sodiumInstance;

      // Decrypt using libsodium crypto_box.openEasy
      final decrypted = sodium.crypto.box.openEasy(
        cipherText: encrypted,
        nonce: nonce,
        publicKey: ephemeralPublicKey,
        secretKey: recipientSecretKey,
      );

      return decrypted;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CryptoBox.decrypt failed: $e');
      }
      return null;
    }
  }
}

/// KeyPair for box encryption
class KeyPair {

  KeyPair({
    required this.privateKey,
    required this.publicKey,
    required this.secretKey,
  });
  final Uint8List publicKey;
  final SecureKey privateKey;
  final SecureKey secretKey;

  /// Disposes the secure keys to free native memory.
  /// Call this when the keypair is no longer needed.
  void dispose() {
    privateKey.dispose();
    // Only dispose secretKey if it's a different object from privateKey
    // to avoid double-dispose of the same native memory.
    if (!identical(privateKey, secretKey)) {
      secretKey.dispose();
    }
  }
}
