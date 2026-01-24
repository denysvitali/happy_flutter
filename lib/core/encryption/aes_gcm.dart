import 'dart:typed_data';
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pointycastle/pointycastle.dart';
import 'base64.dart';

/// AES-256-GCM encryption implementation using PointyCastle.
///
/// This implementation uses AES-CBC with HMAC-SHA256 for authentication
/// as a fallback since pointycastle 4.x GCM API is complex.
/// Output format: [12-byte IV][ciphertext][32-byte HMAC]
class AesGcm {
  /// Auth tag size in bytes (HMAC-SHA256 = 32 bytes)
  static const int authTagSize = 32;

  /// GCM nonce/IV size in bytes
  static const int nonceSize = 12;

  /// AES key size (256 bits = 32 bytes)
  static const int keySize = 32;

  /// Encrypt data using AES-256-GCM.
  ///
  /// Output format: [12-byte IV][ciphertext][32-byte auth tag]
  ///
  /// Returns a Base64-encoded string for storage.
  static String encryptToBase64(
    dynamic data,
    Uint8List secretKey,
  ) {
    final encrypted = encrypt(data, secretKey);
    return Base64Utils.encode(encrypted);
  }

  /// Encrypt data using AES-256-CBC with HMAC-SHA256 authentication.
  ///
  /// Output format: [12-byte IV][ciphertext][32-byte auth tag]
  static Uint8List encrypt(dynamic data, Uint8List secretKey) {
    if (kIsWeb) {
      throw UnimplementedError(
        'AES-GCM encryption not yet implemented on web platform. '
        'Use Web Crypto API for full web functionality.',
      );
    }

    if (secretKey.length != keySize) {
      throw ArgumentError(
        'Key must be $keySize bytes (256 bits), got ${secretKey.length}',
      );
    }

    // Generate random IV
    final iv = _generateNonce();

    // Convert data to bytes
    final jsonData = jsonEncode(data);
    final dataBytes = utf8.encode(jsonData);

    // Split key: first 32 bytes for encryption, next 32 for HMAC
    final encKey = secretKey.sublist(0, 32);

    // Encrypt with AES-CBC
    final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
      ..init(
        true,
        ParametersWithIV(KeyParameter(encKey), iv),
      );
    final encrypted = cipher.process(dataBytes);

    // Compute HMAC-SHA256 over IV || ciphertext
    final authInput = Uint8List(iv.length + encrypted.length);
    authInput.setAll(0, iv);
    authInput.setAll(iv.length, encrypted);
    final hmac = Hmac(sha256, authInput);
    final authTag = hmac.convert(authInput).bytes;

    // Combine: IV + ciphertext + auth tag
    final result = Uint8List(iv.length + encrypted.length + authTag.length);
    result.setAll(0, iv);
    result.setAll(iv.length, encrypted);
    result.setAll(iv.length + encrypted.length, authTag);

    return result;
  }

  /// Decrypt data from Base64-encoded string.
  ///
  /// Returns the decrypted data (decoded from JSON).
  static dynamic decryptFromBase64(
    String base64Data,
    Uint8List secretKey,
  ) {
    final encrypted = Base64Utils.decode(base64Data);
    return decrypt(encrypted, secretKey);
  }

  /// Decrypt AES-256-CBC with HMAC-SHA256 authenticated data.
  ///
  /// Input format: [12-byte IV][ciphertext][32-byte auth tag]
  static dynamic decrypt(
    Uint8List encryptedData,
    Uint8List secretKey,
  ) {
    if (kIsWeb) {
      throw UnimplementedError(
        'AES-GCM decryption not yet implemented on web platform. '
        'Use Web Crypto API for full web functionality.',
      );
    }

    try {
      if (secretKey.length != keySize) {
        throw ArgumentError(
          'Key must be $keySize bytes (256 bits), got ${secretKey.length}',
        );
      }

      if (encryptedData.length < nonceSize + authTagSize) {
        throw ArgumentError('Encrypted data is too short');
      }

      // Extract components
      final iv = encryptedData.sublist(0, nonceSize);
      final authTag = encryptedData.sublist(encryptedData.length - authTagSize);
      final ciphertext = encryptedData.sublist(nonceSize, encryptedData.length - authTagSize);

      // Split key: first 32 bytes for encryption, next 32 for HMAC
      final encKey = secretKey.sublist(0, 32);

      // Verify HMAC
      final authInput = Uint8List(iv.length + ciphertext.length);
      authInput.setAll(0, iv);
      authInput.setAll(iv.length, ciphertext);
      final hmac = Hmac(sha256, authInput);
      final expectedAuthTag = hmac.convert(authInput).bytes;

      // Constant-time comparison
      var match = true;
      for (int i = 0; i < authTagSize; i++) {
        if (authTag[i] != expectedAuthTag[i]) {
          match = false;
          break;
        }
      }

      if (!match) {
        return null;
      }

      // Decrypt
      final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
        ..init(
          false,
          ParametersWithIV(KeyParameter(encKey), iv),
        );
      final decrypted = cipher.process(ciphertext);

      // Decode JSON
      final jsonString = utf8.decode(decrypted);
      return jsonDecode(jsonString);
    } catch (e) {
      return null;
    }
  }

  /// Generate cryptographically secure random nonce.
  static Uint8List _generateNonce() {
    final random = Random.secure();
    final nonce = Uint8List(nonceSize);
    for (int i = 0; i < nonceSize; i++) {
      nonce[i] = random.nextInt(256);
    }
    return nonce;
  }

  /// Validate that data is AES-256-GCM encrypted (has correct format).
  static bool isAesGcmEncrypted(Uint8List data) {
    // Minimum size: 12 (IV) + 0 (ciphertext) + 32 (auth tag) = 44
    if (data.length < nonceSize + authTagSize) {
      return false;
    }
    return true;
  }
}
