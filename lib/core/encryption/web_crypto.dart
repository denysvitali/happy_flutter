import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

/// Web platform crypto implementation using Web Crypto API
///
/// This provides browser-compatible encryption using SubtleCrypto.
/// Uses AES-GCM for authenticated encryption compatible with mobile.

/// Stub implementations for non-web platforms
///
/// On web, this is replaced by web_crypto_web.dart which contains
/// the actual Web Crypto API implementations.

/// Web Crypto Box stub for non-web platforms
class WebCryptoBox {
  static const int publicKeyBytes = 32;
  static const int secretKeyBytes = 32;
  static const int nonceBytes = 24;

  static Uint8List randomNonce() {
    throw UnsupportedError('WebCryptoBox is only supported on web platform');
  }

  static Future<WebCryptoKeyPair> generateKeypair() async {
    throw UnsupportedError('WebCryptoBox is only supported on web platform');
  }

  static Future<Uint8List> encrypt(
    Uint8List data,
    Uint8List recipientPublicKey,
    Uint8List senderPrivateKey,
  ) async {
    throw UnsupportedError('WebCryptoBox is only supported on web platform');
  }

  static Future<Uint8List?> decrypt(
    Uint8List encryptedBundle,
    Uint8List recipientPrivateKey,
  ) async {
    throw UnsupportedError('WebCryptoBox is only supported on web platform');
  }
}

/// Web Crypto SecretBox stub for non-web platforms
class WebCryptoSecretBox {
  static const int nonceBytes = 24;
  static const int keyBytes = 32;

  static Future<Uint8List> encrypt(
    dynamic data,
    Uint8List secretKey,
  ) async {
    throw UnsupportedError('WebCryptoSecretBox is only supported on web platform');
  }

  static Future<dynamic> decrypt(
    Uint8List encryptedData,
    Uint8List secretKey,
  ) async {
    throw UnsupportedError('WebCryptoSecretBox is only supported on web platform');
  }

  static Uint8List randomNonce() {
    throw UnsupportedError('WebCryptoSecretBox is only supported on web platform');
  }
}

/// Web AES-GCM stub for non-web platforms
class WebAesGcm {
  static const int authTagSize = 16;
  static const int nonceSize = 12;
  static const int keySize = 32;

  static Future<Uint8List> encrypt(
    Uint8List data,
    Uint8List secretKey,
  ) async {
    throw UnsupportedError('WebAesGcm is only supported on web platform');
  }

  static Future<Uint8List?> decrypt(
    Uint8List encryptedData,
    Uint8List secretKey,
  ) async {
    throw UnsupportedError('WebAesGcm is only supported on web platform');
  }

  static bool isAesGcmEncrypted(Uint8List data) {
    throw UnsupportedError('WebAesGcm is only supported on web platform');
  }
}

/// Web crypto key pair for asymmetric encryption
class WebCryptoKeyPair {
  final Uint8List publicKey;
  final Uint8List privateKey;

  WebCryptoKeyPair({required this.publicKey, required this.privateKey});
}
