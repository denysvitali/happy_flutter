import 'dart:typed_data';

import '../services/logger_service.dart' show logger;

import 'aes_gcm.dart';
import 'crypto_secret_box.dart';

/// Encryptor and Decryptor interface
abstract interface class Encryptor {
  Future<List<Uint8List>> encrypt(List<dynamic> data);
  Future<List<dynamic>> decrypt(List<Uint8List> data);
}

/// Alias for Encryptor (combined interface)
typedef Decryptor = Encryptor;

/// NaCl Secret Box encryption (symmetric)
class SecretBoxEncryption implements Encryptor {

  SecretBoxEncryption(this._secretKey);
  final Uint8List _secretKey;

  /// Expose key for isolate-based decryption.
  Uint8List get secretKey => _secretKey;

  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    final results = <Uint8List>[];
    for (final item in data) {
      final encrypted = await CryptoSecretBox.encrypt(item, _secretKey);
      results.add(encrypted);
    }
    return results;
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    final results = <dynamic>[];
    for (final item in data) {
      final decrypted = await CryptoSecretBox.decrypt(item, _secretKey);
      results.add(decrypted);
    }
    return results;
  }
}

/// AES-256-GCM encryption using PointyCastle.
///
/// Compatible with React Native's `rn-encryption` library.
/// Format: [1-byte version (0)][12-byte IV][ciphertext][16-byte auth tag]
class AES256Encryption implements Encryptor {

  AES256Encryption(this._secretKey);
  final Uint8List _secretKey;

  /// Expose key for isolate-based decryption.
  Uint8List get secretKey => _secretKey;

  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    final results = <Uint8List>[];
    for (final item in data) {
      // Encrypt with AES-GCM
      final encrypted = await AesGcmEncryption.encrypt(item, _secretKey);
      // Add version byte prefix (matching React Native format)
      final output = Uint8List(encrypted.length + 1);
      output[0] = 0; // version byte
      output.setAll(1, encrypted);
      results.add(output);
    }
    return results;
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    final results = <dynamic>[];
    for (final item in data) {
      try {
        if (item.isEmpty || item[0] != 0) {
          results.add(null);
          continue;
        }
        // Strip version byte and decrypt
        final decrypted = await AesGcmEncryption.decrypt(
          item.sublist(1),
          _secretKey,
        );
        results.add(decrypted);
      } catch (e) {
        logger.warning('AES256Encryption.decrypt failed', e);
        results.add(null);
      }
    }
    return results;
  }
}
