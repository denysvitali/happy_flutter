import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import '../services/logger_service.dart' show logger;
import 'base64.dart';

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
class AesGcmEncryption {
  /// Shared cryptographic random instance
  static final Random _random = Random.secure();

  /// Cached AES-256-GCM cipher instance — holds only algorithm parameters,
  /// no key material, and is safe to reuse across calls.
  static final _cipher = AesGcm.with256bits();

  /// Cached SecretKey per raw key bytes to avoid per-message allocation.
  /// Key: base64-encoded raw key, Value: platform SecretKey object.
  static final _secretKeyCache = <String, SecretKey>{};

  /// Auth tag size in bytes (GCM standard = 16 bytes)
  static const int authTagSize = 16;

  /// GCM nonce/IV size in bytes
  static const int nonceSize = 12;

  /// AES key size (256 bits = 32 bytes)
  static const int keySize = 32;

  /// Encrypt data using true AES-256-GCM.
  ///
  /// Output format: [12-byte IV][ciphertext + 16-byte auth tag]
  ///
  /// Returns a Base64-encoded string for storage
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

    // Create cipher and get cached SecretKey
    final cipher = _cipher;
    final secretKeyObj = await _cachedSecretKey(secretKey);

    // Encrypt using AES-256-GCM
    // The SecretBox contains: ciphertext + auth tag (automatically appended)
    final secretBox = await cipher.encrypt(
      dataBytes,
      secretKey: secretKeyObj,
      nonce: nonce,
    );

    // Combine: nonce + ciphertext + auth tag
    // secretBox.cipherText is ciphertext only; mac.bytes is the 16-byte tag
    final cipherText = secretBox.cipherText;
    final macBytes = secretBox.mac.bytes;
    final result = Uint8List(nonce.length + cipherText.length + macBytes.length)
      ..setAll(0, nonce)
      ..setAll(nonce.length, cipherText)
      ..setAll(nonce.length + cipherText.length, macBytes);

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
    return decrypt(encrypted, secretKey);
  }

  /// Decrypt true AES-256-GCM encrypted data.
  ///
  /// Input format: [12-byte IV][ciphertext with auth tag]
  ///
  /// Returns the decrypted data (decoded from JSON), or null if
  static Future<dynamic> decrypt(
    Uint8List encryptedData,
    Uint8List secretKey,
  ) async {
    try {
      if (secretKey.length != keySize) {
        throw ArgumentError(
          'Key must be $keySize bytes (256 bits), got ${secretKey.length}',
        );
      }

      if (encryptedData.length < nonceSize + authTagSize) {
        throw ArgumentError('Encrypted data is too short');
      }

      // Extract nonce (first 12 bytes), ciphertext, and auth tag (last 16)
      final nonce = encryptedData.sublist(0, nonceSize);
      final ciphertext = encryptedData.sublist(
        nonceSize,
        encryptedData.length - authTagSize,
      );
      final authTagBytes = encryptedData.sublist(
        encryptedData.length - authTagSize,
      );
      final mac = Mac(authTagBytes);

      // Create cipher and get cached SecretKey
      final cipher = _cipher;
      final secretKeyObj = await _cachedSecretKey(secretKey);

      // Decrypt using AES-256-GCM with proper MAC verification
      final secretBox = SecretBox(ciphertext, nonce: nonce, mac: mac);

      final decrypted = await cipher.decrypt(
        secretBox,
        secretKey: secretKeyObj,
      );

      // Decode JSON
      final jsonString = utf8.decode(decrypted);
      return jsonDecode(jsonString);
    } catch (e, stack) {
      logger.error('AesGcmEncryption.decrypt failed', e, stack);
      return null;
    }
  }

  /// Generate cryptographically secure random nonce.
  static Uint8List _generateNonce() {
    final nonce = Uint8List(nonceSize);
    for (var i = 0; i < nonceSize; i++) {
      nonce[i] = _random.nextInt(256);
    }
    return nonce;
  }

  /// Get or create a cached SecretKey for the given raw key bytes.
  static Future<SecretKey> _cachedSecretKey(Uint8List secretKey) async {
    final cacheKey = base64.encode(secretKey);
    var cached = _secretKeyCache[cacheKey];
    if (cached != null) return cached;
    cached = await _cipher.newSecretKeyFromBytes(secretKey);
    _secretKeyCache[cacheKey] = cached;
    return cached;
  }

  /// Evict a cached SecretKey (call when the session is disposed).
  static void evictCachedKey(Uint8List secretKey) {
    _secretKeyCache.remove(base64.encode(secretKey));
  }

  /// Batch-encrypt items with AES-256-GCM without using static caches.
  ///
  /// Designed to run inside [Isolate.run] — creates its own cipher and key
  /// instances. Each input is any JSON-encodable value; it is JSON-encoded
  /// here so the encode cost moves off the calling isolate too. Each output
  /// is `[12-byte nonce][ciphertext][16-byte auth tag]` (no version byte),
  /// the exact layout [decryptBatch] consumes.
  ///
  /// JSON-encode failures propagate: encryption has no null-tolerant
  /// fallback contract — a non-encodable payload is a caller bug that must
  /// surface as a failed send, not a silently dropped one.
  static Future<List<Uint8List>> encryptBatch(
    List<dynamic> items,
    Uint8List secretKey,
  ) async {
    final cipher = AesGcm.with256bits();
    final key = await cipher.newSecretKeyFromBytes(secretKey);
    final random = Random.secure();
    final results = <Uint8List>[];
    for (final item in items) {
      final dataBytes = utf8.encode(jsonEncode(item));
      final nonce = Uint8List(nonceSize);
      for (var i = 0; i < nonceSize; i++) {
        nonce[i] = random.nextInt(256);
      }
      final secretBox = await cipher.encrypt(
        dataBytes,
        secretKey: key,
        nonce: nonce,
      );
      final cipherText = secretBox.cipherText;
      final macBytes = secretBox.mac.bytes;
      results.add(
        Uint8List(nonce.length + cipherText.length + macBytes.length)
          ..setAll(0, nonce)
          ..setAll(nonce.length, cipherText)
          ..setAll(nonce.length + cipherText.length, macBytes),
      );
    }
    return results;
  }

  /// Batch-decrypt AES-256-GCM items without using static caches.
  ///
  /// Designed to run inside [Isolate.run] — creates its own cipher
  /// and key instances. Each item is
  /// `[12-byte nonce][ciphertext][16-byte auth tag]` (no version byte).
  ///
  /// Returns decoded JSON values (`null` for failed items).
  static Future<List<dynamic>> decryptBatch(
    List<Uint8List> items,
    Uint8List secretKey,
  ) async {
    final cipher = AesGcm.with256bits();
    final key = await cipher.newSecretKeyFromBytes(secretKey);
    final results = <dynamic>[];
    for (final item in items) {
      try {
        if (item.length < nonceSize + authTagSize) {
          results.add(null);
          continue;
        }
        final nonce = item.sublist(0, nonceSize);
        final ciphertext = item.sublist(
          nonceSize,
          item.length - authTagSize,
        );
        final tag = item.sublist(item.length - authTagSize);
        final box = SecretBox(
          ciphertext,
          nonce: nonce,
          mac: Mac(tag),
        );
        final decrypted = await cipher.decrypt(
          box,
          secretKey: key,
        );
        results.add(jsonDecode(utf8.decode(decrypted)));
      } catch (e) {
        // Running inside Isolate.run — logger singleton is unavailable.
        // The caller (AES256Encryption.decryptInIsolate) logs batch failures.
        results.add(null);
      }
    }
    return results;
  }

  /// Batch-decrypt AES-256-GCM items with per-item keys.
  ///
  /// Like [decryptBatch] but each item may use a different key.
  /// [items] and [keys] must have the same length.
  static Future<List<dynamic>> decryptMultiKeyBatch(
    List<Uint8List> items,
    List<Uint8List> keys,
  ) async {
    final cipher = AesGcm.with256bits();
    final keyCache = <String, SecretKey>{};
    final results = <dynamic>[];
    for (var i = 0; i < items.length; i++) {
      try {
        final item = items[i];
        if (item.length < nonceSize + authTagSize) {
          results.add(null);
          continue;
        }
        final rawKey = keys[i];
        final cacheKey = base64.encode(rawKey);
        final sk = keyCache[cacheKey] ??=
            await cipher.newSecretKeyFromBytes(rawKey);
        final nonce = item.sublist(0, nonceSize);
        final ciphertext = item.sublist(
          nonceSize,
          item.length - authTagSize,
        );
        final tag = item.sublist(item.length - authTagSize);
        final box = SecretBox(
          ciphertext,
          nonce: nonce,
          mac: Mac(tag),
        );
        final decrypted = await cipher.decrypt(
          box,
          secretKey: sk,
        );
        results.add(jsonDecode(utf8.decode(decrypted)));
      } catch (e) {
        // Running inside Isolate.run — logger singleton is unavailable.
        // The caller (AES256Encryption.decryptInIsolate) logs batch failures.
        results.add(null);
      }
    }
    return results;
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
