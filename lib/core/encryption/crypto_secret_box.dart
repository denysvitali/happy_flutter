import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium.dart';

import '../services/logger_service.dart' show logger;
import 'sodium_singleton.dart';

/// CryptoSecretBox encryption using libsodium (crypto_secretbox_easy)
/// Compatible with React Native's @more-tech/react-native-libsodium
class CryptoSecretBox {
  static const int _nonceSize = 24; // crypto_secretbox_NONCEBYTES (libsodium)
  static const int _keySize = 32; // crypto_secretbox_KEYBYTES

  /// Cached SecureKey per raw key bytes to avoid per-message allocation
  /// and native memory churn. Key: base64-encoded raw key.
  static final _secureKeyCache = <String, SecureKey>{};

  /// Get or create a cached SecureKey for the given raw key bytes.
  static Future<SecureKey> _cachedSecureKey(Uint8List secretKey) async {
    final key = secretKey.length >= _keySize
        ? secretKey.sublist(0, _keySize)
        : Uint8List.fromList(secretKey);

    final cacheKey = base64.encode(key);
    final cached = _secureKeyCache[cacheKey];
    if (cached != null) return cached;

    final sodium = await sodiumSingleton;
    final secureKey = SecureKey.fromList(sodium, key);
    _secureKeyCache[cacheKey] = secureKey;
    return secureKey;
  }

  /// Evict and dispose a cached SecureKey (call when session is
  /// disposed).
  static void evictCachedKey(Uint8List secretKey) {
    final key = secretKey.length >= _keySize
        ? secretKey.sublist(0, _keySize)
        : Uint8List.fromList(secretKey);
    final cacheKey = base64.encode(key);
    final cached = _secureKeyCache.remove(cacheKey);
    cached?.dispose();
  }

  static Future<Uint8List> encrypt(dynamic data, Uint8List secretKey) async {
    final sodium = await sodiumSingleton;
    final nonce = sodium.randombytes.buf(_nonceSize);
    final jsonData = jsonEncode(data);
    final dataBytes = utf8.encode(jsonData);

    final secureKey = await _cachedSecureKey(secretKey);

    // Encrypt using libsodium crypto_secretbox_easy
    final encrypted = sodium.crypto.secretBox.easy(
      message: dataBytes,
      nonce: nonce,
      key: secureKey,
    );

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
    try {
      if (encryptedData.length < _nonceSize + 16) {
        return null;
      }

      final nonce = encryptedData.sublist(0, _nonceSize);
      final encrypted = encryptedData.sublist(_nonceSize);

      final sodium = await sodiumSingleton;
      final secureKey = await _cachedSecureKey(secretKey);

      // Decrypt using libsodium crypto_secretbox.openEasy
      final decrypted = sodium.crypto.secretBox.openEasy(
        cipherText: encrypted,
        nonce: nonce,
        key: secureKey,
      );

      final jsonString = utf8.decode(decrypted);
      return jsonDecode(jsonString);
    } catch (e) {
      logger.warning('CryptoSecretBox.decrypt failed', e);
      return null;
    }
  }
}
