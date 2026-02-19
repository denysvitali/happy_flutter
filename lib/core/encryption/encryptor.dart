import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium.dart';

import 'aes_gcm.dart';
import 'crypto_box.dart';
import 'crypto_secret_box.dart';
import 'text.dart';

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

/// NaCl Box encryption (public key)
class BoxEncryption implements Encryptor {

  /// Legacy synchronous constructor - not supported, use create() instead
  factory BoxEncryption(Uint8List seed) {
    throw UnimplementedError('Use BoxEncryption.create(seed) instead');
  }

  BoxEncryption._(this._privateKey, this._publicKey);
  late final SecureKey _privateKey;
  late final Uint8List _publicKey;

  /// Factory constructor that initializes async
  static Future<BoxEncryption> create(Uint8List seed) async {
    final keypair = await CryptoBox.keypairFromSeed(seed);
    return BoxEncryption._(keypair.secretKey, keypair.publicKey);
  }

  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    final results = <Uint8List>[];
    for (final item in data) {
      final jsonBytes = TextUtils.encodeUtf8(jsonEncode(item));
      final encrypted = await CryptoBox.encrypt(jsonBytes, _publicKey);
      results.add(encrypted);
    }
    return results;
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    final results = <dynamic>[];
    for (final item in data) {
      final decrypted = await CryptoBox.decrypt(item, _privateKey);
      if (decrypted == null) {
        results.add(null);
        continue;
      }
      try {
        final jsonString = TextUtils.decodeUtf8(decrypted);
        results.add(jsonDecode(jsonString));
      } catch (e) {
        results.add(null);
      }
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
        results.add(null);
      }
    }
    return results;
  }
}
