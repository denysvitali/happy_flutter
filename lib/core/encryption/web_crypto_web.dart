import 'dart:convert';
import 'dart:typed_data';

/// Web platform crypto implementation stub.
///
/// This is a placeholder implementation. The web crypto implementation
/// requires proper JS interop setup which is disabled for now.
/// The app uses native mobile implementations (sodium_libs) instead.

/// Web Crypto Box implementation stub
class WebCryptoBox {
  static const int publicKeyBytes = 32;
  static const int secretKeyBytes = 32;
  static const int nonceBytes = 24;

  static Uint8List randomNonce() {
    throw UnimplementedError('Web crypto not implemented');
  }

  static Future<WebCryptoKeyPair> generateKeypair() async {
    throw UnimplementedError('Web crypto not implemented');
  }

  static Future<Uint8List> encrypt(
    Uint8List data,
    Uint8List recipientPublicKey,
    Uint8List senderPrivateKey,
  ) async {
    throw UnimplementedError('Web crypto not implemented');
  }

  static Future<Uint8List?> decrypt(
    Uint8List encryptedBundle,
    Uint8List recipientPrivateKey,
  ) async {
    throw UnimplementedError('Web crypto not implemented');
  }
}

/// Web Crypto SecretBox implementation stub
class WebCryptoSecretBox {
  static const int nonceBytes = 24;
  static const int keyBytes = 32;

  static Future<Uint8List> encrypt(
    dynamic data,
    Uint8List secretKey,
  ) async {
    throw UnimplementedError('Web crypto not implemented');
  }

  static Future<dynamic> decrypt(
    Uint8List encryptedData,
    Uint8List secretKey,
  ) async {
    throw UnimplementedError('Web crypto not implemented');
  }

  static Uint8List randomNonce() {
    throw UnimplementedError('Web crypto not implemented');
  }
}

/// Web crypto key pair stub
class WebCryptoKeyPair {
  final Uint8List publicKey;
  final Uint8List privateKey;

  WebCryptoKeyPair({required this.publicKey, required this.privateKey});
}

/// AES-GCM encryption stub for web
class WebAesGcm {
  static const int authTagSize = 16;
  static const int nonceSize = 12;
  static const int keySize = 32;

  static Future<Uint8List> encrypt(
    Uint8List data,
    Uint8List secretKey,
  ) async {
    throw UnimplementedError('Web AES-GCM not implemented');
  }

  static Future<Uint8List?> decrypt(
    Uint8List encryptedData,
    Uint8List secretKey,
  ) async {
    throw UnimplementedError('Web AES-GCM not implemented');
  }

  static bool isAesGcmEncrypted(Uint8List data) {
    if (data.length < nonceSize + authTagSize) {
      return false;
    }
    return true;
  }
}
