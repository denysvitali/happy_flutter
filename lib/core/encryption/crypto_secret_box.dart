import 'dart:typed_data';
import 'dart:convert';
import 'dart:ffi';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sodium/sodium.dart';
import 'web_crypto.dart' if (dart.library.html) 'web_crypto_web.dart';

/// CryptoSecretBox encryption using libsodium (crypto_secretbox_easy)
/// Compatible with React Native's @more-tech/react-native-libsodium
class CryptoSecretBox {
  static const int _nonceSize = 24; // crypto_secretbox_NONCEBYTES (libsodium)
  static const int _keySize = 32; // crypto_secretbox_KEYBYTES
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

  static Future<Uint8List> encrypt(dynamic data, Uint8List secretKey) async {
    if (kIsWeb) {
      return await WebCryptoSecretBox.encrypt(data, secretKey);
    }

    final sodium = await _sodiumInstance;
    final nonce = sodium.randombytes.buf(_nonceSize);
    final jsonData = jsonEncode(data);
    final dataBytes = utf8.encode(jsonData);

    final key = secretKey.length >= _keySize
        ? secretKey.sublist(0, _keySize)
        : Uint8List.fromList(secretKey);

    // Create SecureKey from the key bytes
    final secureKey = SecureKey.fromList(sodium, key);

    // Encrypt using libsodium crypto_secretbox_easy
    final encrypted = sodium.crypto.secretBox.easy(
      message: dataBytes,
      nonce: nonce,
      key: secureKey,
    );

    // Dispose the secure key
    secureKey.dispose();

    // Bundle format: nonce + encrypted data
    final result = Uint8List(nonce.length + encrypted.length);
    result.setAll(0, nonce);
    result.setAll(nonce.length, encrypted);

    return result;
  }

  static Future<dynamic> decrypt(Uint8List encryptedData, Uint8List secretKey) async {
    if (kIsWeb) {
      return await WebCryptoSecretBox.decrypt(encryptedData, secretKey);
    }

    try {
      if (encryptedData.length < _nonceSize + 16) {
        return null;
      }

      final nonce = encryptedData.sublist(0, _nonceSize);
      final encrypted = encryptedData.sublist(_nonceSize);

      final key = secretKey.length >= _keySize
          ? secretKey.sublist(0, _keySize)
          : Uint8List.fromList(secretKey);

      final sodium = await _sodiumInstance;

      // Create SecureKey from the key bytes
      final secureKey = SecureKey.fromList(sodium, key);

      // Decrypt using libsodium crypto_secretbox.openEasy
      final decrypted = sodium.crypto.secretBox.openEasy(
        cipherText: encrypted,
        nonce: nonce,
        key: secureKey,
      );

      // Dispose the secure key
      secureKey.dispose();

      final jsonString = utf8.decode(decrypted);
      return jsonDecode(jsonString);
    } catch (e) {
      return null;
    }
  }

}
