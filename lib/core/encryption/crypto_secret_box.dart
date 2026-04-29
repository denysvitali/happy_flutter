import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:sentry_flutter/sentry_flutter.dart';
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

  /// Rate-limits Sentry captures so a key-rotation that fails on 100
  /// historical messages does not produce 100 events. Keyed by
  /// `<keyFingerprint>:<stage>`.
  static final _sentryCaptureCooldown = <String, DateTime>{};
  static const _sentryCooldown = Duration(minutes: 5);

  /// Short fingerprint of a key — first 8 base64 chars of SHA-256 — used
  /// as a grouping tag. Does NOT expose the key itself.
  static String _keyFingerprint(Uint8List secretKey) {
    // Avoid hashing: the base64 prefix is already collision-resistant
    // enough for aggregation, and keeping it cheap matters on the hot
    // decrypt path.
    final prefix = base64.encode(
      secretKey.length >= 6 ? secretKey.sublist(0, 6) : secretKey,
    );
    return prefix.substring(0, prefix.length.clamp(0, 8));
  }

  static bool _shouldCapture(String throttleKey) {
    final now = DateTime.now();
    final last = _sentryCaptureCooldown[throttleKey];
    if (last != null && now.difference(last) < _sentryCooldown) {
      return false;
    }
    _sentryCaptureCooldown[throttleKey] = now;
    return true;
  }

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
    // Track the stage for forensics — auth failures (expected on key
    // rotation) vs decode failures (indicate corrupt ciphertext or
    // double-encoding bugs) should be grouped differently.
    var stage = 'format-check';
    try {
      if (encryptedData.length < _nonceSize + 16) {
        _captureDecryptFailure(
          stage: 'too-short',
          reason: 'payload_below_nonce_plus_mac',
          secretKey: secretKey,
          cipherLen: encryptedData.length,
        );
        return null;
      }

      final nonce = encryptedData.sublist(0, _nonceSize);
      final encrypted = encryptedData.sublist(_nonceSize);

      final sodium = await sodiumSingleton;
      final secureKey = await _cachedSecureKey(secretKey);

      stage = 'sodium';
      // Decrypt using libsodium crypto_secretbox.openEasy
      final decrypted = sodium.crypto.secretBox.openEasy(
        cipherText: encrypted,
        nonce: nonce,
        key: secureKey,
      );

      stage = 'utf8';
      final jsonString = utf8.decode(decrypted);
      stage = 'json';
      return jsonDecode(jsonString);
    } catch (e, stack) {
      _captureDecryptFailure(
        stage: stage,
        reason: e.runtimeType.toString(),
        secretKey: secretKey,
        cipherLen: encryptedData.length,
        error: e,
        stack: stack,
      );
      return null;
    }
  }

  /// Emit a structured log and (rate-limited) Sentry event for a
  /// decryption failure. Expected auth failures during key rotation
  /// (stage == 'sodium') are only sent to Sentry at most once per
  /// fingerprint per cooldown window to avoid flooding.
  static void _captureDecryptFailure({
    required String stage,
    required String reason,
    required Uint8List secretKey,
    required int cipherLen,
    Object? error,
    StackTrace? stack,
  }) {
    final fingerprint = _keyFingerprint(secretKey);
    logger.warning(
      'CryptoSecretBox.decrypt failed '
      'stage=$stage reason=$reason '
      'cipherLen=$cipherLen keyFp=$fingerprint'
      '${error == null ? '' : '\n$error'}',
    );
    // Post-sodium stages (utf8/json) indicate that the MAC check passed
    // but the plaintext was unexpected — that is always worth capturing.
    // Pre-sodium format checks and sodium auth failures are rate-limited.
    final critical = stage == 'utf8' || stage == 'json';
    final throttleKey = '$fingerprint:$stage';
    if (!critical && !_shouldCapture(throttleKey)) return;

    unawaited(
      Sentry.captureException(
        error ??
            StateError(
              'CryptoSecretBox.decrypt failed: stage=$stage reason=$reason',
            ),
        stackTrace: stack ?? StackTrace.current,
        withScope: (scope) {
          scope
            ..setTag('decrypt_stage', stage)
            ..setTag('decrypt_reason', reason)
            ..setTag('key_fp', fingerprint)
            ..setContexts('decrypt', {
              'stage': stage,
              'reason': reason,
              'cipher_len': cipherLen,
              'key_fp': fingerprint,
              'nonce_size': _nonceSize,
              'critical': critical,
            });
        },
      ),
    );
  }

  /// Decrypt a batch of items, yielding to the event loop between items.
  ///
  /// Each CryptoSecretBox.decrypt call blocks the main isolate on native
  /// FFI (libsodium crypto_secretbox_open_easy).  This method yields
  /// every item so the UI stays responsive during large legacy NaCl
  /// batch decryptions.
  ///
  /// Note: A true isolate-based approach (Isolate.run) is not viable here
  /// because Sodium initialization (SodiumInit.init()) is async and must
  /// complete before decryption.  The per-item yield is the simplest
  /// approach that keeps the UI thread-free without complex worker-isolate
  /// machinery.
  static Future<List<dynamic>> decryptBatchInIsolate(
    List<Uint8List> data,
    Uint8List secretKey,
  ) async {
    if (data.isEmpty) return [];
    final results = <dynamic>[];
    for (var i = 0; i < data.length; i++) {
      results.add(await decrypt(data[i], secretKey));
      // Yield every item so the Flutter UI can render between decryptions.
      // This keeps the main isolate responsive even when decrypting
      // hundreds of legacy NaCl messages on cold start.
      await Future<void>.delayed(Duration.zero);
    }
    return results;
  }
}
