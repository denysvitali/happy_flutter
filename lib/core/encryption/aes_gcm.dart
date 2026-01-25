import 'dart:typed_data';
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cryptography/cryptography.dart';
import 'base64.dart';
import 'web_crypto.dart' if (dart.library.html) 'web_crypto_web.dart';

/// True AES-256-GCM encryption implementation.
///
/// This implementation uses the `cryptography` package which provides
/// native AES-256-GCM encryption on mobile platforms (iOS/Android) and
/// falls back to a pure Dart implementation on web.
///
/// Compatible with React Native's `rn-encryption` library.
/// Format: Base64-encoded [12-byte IV/nonce][ciphertext][16-byte auth tag]
///
/// Key differences from the old fake implementation:
/// - Uses actual AES-256-GCM mode (not AES-CBC + HMAC)
/// - 12-byte nonce/IV (GCM standard)
/// - 16-byte authentication tag (built into GCM, not 32-byte HMAC)
/// - Returns Base64-encoded string (matching rn-encryption format)
class AesGcm {
  /// Auth tag size in bytes (GCM standard = 16 bytes)
  static const int authTagSize = 16;

  /// GCM nonce/IV size in bytes
  static const int nonceSize = 12;

  /// AES key size (256 bits = 32 bytes)
  static const int keySize = 32;

  /// The AES-256-GCM cipher instance for mobile platforms
  static final _cipher = AesGcm.with256bits();

  /// Encrypt data using true AES-256-GCM.
  ///
  /// Output format: [12-byte IV][ciphertext + 16-byte auth tag]
  ///
  /// Returns a Base64-encoded string for storage (compatible with rn-encryption).
  static Future<String> encryptToBase64(
    dynamic data,
    Uint8List secretKey,
  ) async {
    final encrypted = await encrypt(data, secretKey);
    return Base64Utils.encode(encrypted);
  }

  /// Encrypt data using true AES-256-GCM.
  ///
  /// Output format: [12-byte IV][ciphertext with auth tag appended]
  ///
  /// The authentication tag is automatically appended to the ciphertext
  /// by the GCM mode, so we don't need to handle it separately.
  static Future<Uint8List> encrypt(dynamic data, Uint8List secretKey) async {
    if (kIsWeb) {
      // Use Web Crypto API for web platform
      final jsonData = jsonEncode(data);
      final dataBytes = utf8.encode(jsonData);
      return await WebAesGcm.encrypt(dataBytes, secretKey);
    }

    if (secretKey.length != keySize) {
      throw ArgumentError(
        'Key must be $keySize bytes (256 bits), got ${secretKey.length}',
      );
    }

    // Generate random nonce (IV)
    final nonce = _generateNonce();

    // Convert data to bytes
    final jsonData = jsonEncode(data);
    final dataBytes = utf8.encode(jsonData);

    // Encrypt using AES-256-GCM
    // The SecretBox contains: ciphertext + auth tag (automatically appended)
    final secretBox = await _cipher.encrypt(
      dataBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    // Combine: nonce + ciphertext + auth tag
    // Note: secretBox.ciphertext already contains the auth tag appended
    final result = Uint8List(nonce.length + secretBox.ciphertext.length);
    result.setAll(0, nonce);
    result.setAll(nonce.length, secretBox.ciphertext);

    return result;
  }

  /// Decrypt data from Base64-encoded string.
  ///
  /// Returns the decrypted data (decoded from JSON).
  static Future<dynamic> decryptFromBase64(
    String base64Data,
    Uint8List secretKey,
  ) async {
    final encrypted = Base64Utils.decode(base64Data);
    return await decrypt(encrypted, secretKey);
  }

  /// Decrypt true AES-256-GCM encrypted data.
  ///
  /// Input format: [12-byte IV][ciphertext with auth tag]
  ///
  /// Returns the decrypted data (decoded from JSON), or null if decryption fails.
  static Future<dynamic> decrypt(
    Uint8List encryptedData,
    Uint8List secretKey,
  ) async {
    if (kIsWeb) {
      // Use Web Crypto API for web platform
      final decrypted = await WebAesGcm.decrypt(encryptedData, secretKey);
      if (decrypted == null) return null;
      final jsonString = utf8.decode(decrypted);
      return jsonDecode(jsonString);
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
      final nonce = encryptedData.sublist(0, nonceSize);
      final ciphertextWithTag = encryptedData.sublist(nonceSize);

      // Decrypt using AES-256-GCM
      // The SecretBox expects ciphertext with auth tag already appended
      final secretBox = SecretBox(
        ciphertextWithTag,
        nonce: nonce,
        mac: Mac.empty, // MAC is embedded in the ciphertext for GCM
      );

      final decrypted = await _cipher.decrypt(
        secretBox,
        secretKey: secretKey,
      );

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
    // Minimum size: 12 (IV) + 0 (ciphertext) + 16 (auth tag) = 28
    if (data.length < nonceSize + authTagSize) {
      return false;
    }
    return true;
  }
}
