import 'dart:typed_data';
import 'dart:ffi';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sodium/sodium.dart';

import 'web_crypto.dart' if (dart.library.html) 'web_crypto_web.dart';

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
    // Use sodium_libs which provides built-in libsodium for Flutter
    // The package exports a helper that loads the native library
    _sodium = await SodiumInit.init(
      // sodium_libs automatically provides the DynamicLibrary for Flutter platforms
      () => throw UnimplementedError('sodium_libs should provide DynamicLibrary'),
    );
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
    // sodium v3.4+ API: seedKeyPair takes a SecureKey
    final seedKey = SecureKey(sodium, CryptoBoxConstants.seedBytes);
    // Copy seed data into the SecureKey
    final seedKeyCopy = SecureKey.fromList(sodium, seed);
    seedKeyCopy.dispose(); // Dispose the temporary key

    final keypair = sodium.crypto.box.seedKeyPair(seedKey);

    // Extract public key bytes (secretKey remains as SecureKey)
    final publicKeyBytes = keypair.publicKey;

    return KeyPair(
      publicKey: publicKeyBytes,
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
  static Future<Uint8List> encrypt(
    Uint8List data,
    Uint8List recipientPublicKey,
    SecureKey senderSecretKey,
  ) async {
    if (kIsWeb) {
      // Extract bytes from SecureKey for web
      final senderSecretKeyBytes = senderSecretKey.extractBytes();
      return await WebCryptoBox.encrypt(
        data,
        recipientPublicKey,
        senderSecretKeyBytes,
      );
    }

    final sodium = await _sodiumInstance;
    final ephemeralKeyPair = await generateKeypair();
    final nonce = await randomNonce();

    // Encrypt using libsodium crypto_box_easy
    final encrypted = sodium.crypto.box.easy(
      message: data,
      nonce: nonce,
      publicKey: recipientPublicKey,
      secretKey: senderSecretKey,
    );

    // Bundle format: ephemeral public key (32 bytes) + nonce (24 bytes) + encrypted data
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

  /// Decrypt encrypted bundle (crypto_box_open_easy)
  /// Compatible with React Native's sodium.crypto_box_open_easy()
  static Future<Uint8List?> decrypt(
    Uint8List encryptedBundle,
    SecureKey recipientSecretKey,
  ) async {
    if (kIsWeb) {
      // Extract bytes from SecureKey for web
      final recipientSecretKeyBytes = recipientSecretKey.extractBytes();
      return await WebCryptoBox.decrypt(
        encryptedBundle,
        recipientSecretKeyBytes,
      );
    }

    try {
      // Extract components: ephemeral public key (32 bytes) + nonce (24 bytes) + encrypted data
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
      return null;
    }
  }
}

/// KeyPair for box encryption
class KeyPair {
  final Uint8List publicKey;
  final SecureKey privateKey;
  final SecureKey secretKey;

  KeyPair({
    required this.privateKey,
    required this.publicKey,
    required this.secretKey,
  });
}
