import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

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
    // Isolates are not supported on web — use per-item decryption.
    if (kIsWeb) {
      final results = <dynamic>[];
      for (var i = 0; i < data.length; i++) {
        final decrypted =
            await CryptoSecretBox.decrypt(data[i], _secretKey);
        results.add(decrypted);
        if (i > 0 && i % 10 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
      return results;
    }
    // Use isolate-based batch decryption to avoid blocking the main
    // isolate on NaCl FFI calls (crypto_secretbox_open_easy).
    // Fall back to per-item decryption with yields if isolate spawn fails.
    try {
      return await CryptoSecretBox.decryptBatchInIsolate(data, _secretKey);
    } catch (_) {
      // Isolate unavailable (e.g. certain test environments) — fall back
      // to the slower per-item approach with event-loop yields.
      final results = <dynamic>[];
      for (var i = 0; i < data.length; i++) {
        final decrypted =
            await CryptoSecretBox.decrypt(data[i], _secretKey);
        results.add(decrypted);
        if (i > 0 && i % 10 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
      return results;
    }
  }

  /// Release any cached native resources.
  void dispose() {
    CryptoSecretBox.evictCachedKey(_secretKey);
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
      } catch (e, stack) {
        logger.error('AES256Encryption.decrypt failed', e, stack);
        results.add(null);
      }
    }
    return results;
  }

  /// Decrypt a batch of items in a background isolate.
  ///
  /// AES-256-GCM uses pure-Dart crypto (`DartAesGcm`) — no platform
  /// channels or FFI — so it is fully isolate-safe. On web, falls back to
  /// main-thread decryption since isolates are not supported.
  Future<List<dynamic>> decryptInIsolate(
    List<Uint8List> data,
  ) async {
    final stripped = <Uint8List>[];
    final validIndices = <int>[];
    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      if (item.isNotEmpty && item[0] == 0) {
        stripped.add(item.sublist(1));
        validIndices.add(i);
      }
    }
    if (stripped.isEmpty) {
      return List<dynamic>.filled(data.length, null);
    }
    // Isolates are not supported on web — use main-thread decryption.
    if (kIsWeb) {
      return decrypt(data);
    }
    List<dynamic> isolateResults;
    try {
      // Hoist `_secretKey` into a local so the closure captures only
      // sendable Uint8Lists — never `this`. Dart's closure-capture
      // analysis would otherwise pull `this` (an `AES256Encryption`)
      // plus any caller-scope state the compiler infers it depends on
      // into the isolate message; depending on how the call site holds
      // the decryptor (e.g. via a `SessionEncryption` that itself
      // holds Futures), that capture has shown up as
      // "Illegal argument in isolate message: object is unsendable
      // Library:'dart:async' Class: _Future" on production builds.
      // Mirrors the fix applied to `_offline_tts_service_native.dart`.
      final keyLocal = _secretKey;
      isolateResults = await Isolate.run(
        () => AesGcmEncryption.decryptBatch(
          stripped,
          keyLocal,
        ),
      );
    } catch (e, stack) {
      // Isolate spawn failed (e.g. certain test environments).
      // Fall back to main-thread decryption.
      logger.warning('AES256Encryption: isolate spawn failed, '
          'falling back to main-thread decrypt', e, stack);
      return decrypt(data);
    }
    final results = List<dynamic>.filled(data.length, null);
    var failCount = 0;
    for (var i = 0; i < validIndices.length; i++) {
      results[validIndices[i]] = isolateResults[i];
      if (isolateResults[i] == null) failCount++;
    }
    if (failCount > 0) {
      logger.warning(
        'AES256Encryption.decryptInIsolate: $failCount of '
        '${stripped.length} items failed to decrypt',
      );
    }
    return results;
  }

  /// Release any cached platform resources.
  void dispose() {
    AesGcmEncryption.evictCachedKey(_secretKey);
  }
}
