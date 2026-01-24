import 'dart:typed_data';

class WebCryptoKeyPair {
  final Uint8List publicKey;
  final Uint8List privateKey;
  WebCryptoKeyPair({required this.publicKey, required this.privateKey});
}

class WebCryptoBox {
  static Uint8List randomNonce() {
    throw UnsupportedError('WebCrypto requires dart:js_interop');
  }

  static Future<WebCryptoKeyPair> generateKeypair() async {
    throw UnsupportedError('WebCrypto requires dart:js_interop');
  }

  static Future<Uint8List> encrypt(
    Uint8List data,
    Uint8List recipientPublicKey,
    Uint8List senderPrivateKey,
  ) async {
    throw UnsupportedError('WebCrypto requires dart:js_interop');
  }

  static Future<Uint8List?> decrypt(
    Uint8List encryptedData,
    Uint8List recipientPrivateKey,
  ) async {
    throw UnsupportedError('WebCrypto requires dart:js_interop');
  }
}

class WebCryptoSecretBox {
  static Future<Uint8List> encrypt(
    dynamic data,
    Uint8List secretKey,
  ) async {
    throw UnsupportedError('WebCrypto requires dart:js_interop');
  }

  static Future<dynamic> decrypt(
    Uint8List encryptedData,
    Uint8List secretKey,
  ) async {
    throw UnsupportedError('WebCrypto requires dart:js_interop');
  }

  static Future<Uint8List> deriveKey(
    Uint8List sharedSecret,
    Uint8List info,
    Uint8List salt,
  ) async {
    throw UnsupportedError('WebCrypto requires dart:js_interop');
  }
}
