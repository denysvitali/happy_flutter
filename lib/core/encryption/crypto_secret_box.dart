import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

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

    if (kIsWeb) {
      throw UnsupportedError('Sodium is not supported on web platform');
    }

    // Load the platform-specific libsodium dynamic library.
    DynamicLibrary loader() {
      if (Platform.isAndroid) {
        return DynamicLibrary.open('libsodium.so');
      } else if (Platform.isIOS || Platform.isMacOS) {
        return DynamicLibrary.open('libsodium.dylib');
      } else if (Platform.isLinux) {
        return DynamicLibrary.open('libsodium.so');
      } else if (Platform.isWindows) {
        return DynamicLibrary.open('libsodium.dll');
      }
      throw UnsupportedError(
        'Unsupported platform for sodium: ${Platform.operatingSystem}',
      );
    }

    _sodium = await SodiumInit.init(loader);
    return _sodium!;
  }

  static Future<Uint8List> encrypt(dynamic data, Uint8List secretKey) async {
    if (kIsWeb) {
      return WebCryptoSecretBox.encrypt(data, secretKey);
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
    final result = Uint8List(nonce.length + encrypted.length)
      ..setAll(0, nonce)
      ..setAll(nonce.length, encrypted);

    return result;
  }

  static Future<dynamic> decrypt(
    Uint8List encryptedData,
    Uint8List secretKey,
  ) async {
    if (kIsWeb) {
      return WebCryptoSecretBox.decrypt(encryptedData, secretKey);
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
