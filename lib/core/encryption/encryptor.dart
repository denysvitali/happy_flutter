import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../services/logger_service.dart' show logger;

import 'aes_gcm.dart';
import 'crypto_secret_box.dart';

/// Encryptor and Decryptor interface.
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
    final scope = CryptoSecretBox.currentDiagnosticScope;
    // [CryptoSecretBox.decryptBatchInIsolate] handles all three cases:
    //   - web: stays inline (kIsWeb branch inside)
    //   - batch >= threshold on native: spawns Isolate.run with a
    //     top-level worker that takes only sendable POD args
    //   - small batch / isolate spawn failure: inline with periodic yields
    return CryptoSecretBox.decryptBatchInIsolate(
      data,
      _secretKey,
      scope: scope,
    );
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
        // Recoverable failure (corrupt ciphertext, key mismatch on legacy
        // payloads, etc). Returning null lets the caller fall through to
        // legacy/NaCl decryption or treat the message as undecryptable
        // without crashing.
        logger.warning('AES256Encryption.decrypt failed', e, stack);
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

  /// Encrypt a batch of items in a background isolate.
  ///
  /// Mirror of [decryptInIsolate]: AES-256-GCM is pure-Dart crypto with no
  /// platform channels or FFI, so it is fully isolate-safe. On web (no
  /// isolate support) or when spawning fails, falls back to main-thread
  /// [encrypt]. Returns items prefixed with the same version byte as
  /// [encrypt].
  Future<List<Uint8List>> encryptInIsolate(List<dynamic> data) async {
    if (data.isEmpty) return const [];
    // Isolates are not supported on web — use main-thread encryption.
    if (kIsWeb) return encrypt(data);
    List<Uint8List> encrypted;
    try {
      // Hoist `_secretKey` into a local so the closure captures only
      // sendable Uint8Lists — never `this`. See [decryptInIsolate] for
      // the production "object is unsendable" failure mode this avoids.
      final keyLocal = _secretKey;
      encrypted = await Isolate.run(
        () => AesGcmEncryption.encryptBatch(data, keyLocal),
      );
    } catch (e, stack) {
      // Isolate spawn failed (e.g. certain test environments).
      // Fall back to main-thread encryption.
      logger.warning('AES256Encryption: isolate spawn failed, '
          'falling back to main-thread encrypt', e, stack);
      return encrypt(data);
    }
    return [
      for (final item in encrypted)
        Uint8List(item.length + 1)
          ..[0] = 0 // version byte, matching React Native format
          ..setAll(1, item),
    ];
  }

  /// Decode-and-decrypt a batch of base64 envelopes in a background
  /// isolate.
  ///
  /// Worker-side extension of [decryptInIsolate]: the caller passes raw
  /// base64 ciphertext strings (the wire envelope's `c` field) and
  /// receives decoded JSON bodies. Base64 decoding and the version-byte
  /// strip happen inside the worker too, so a large page no longer spends
  /// caller-isolate time on either. Wire format is untouched: items are
  /// `base64(0x00 || nonce || ct || tag)` exactly as produced by
  /// [encrypt] / [encryptInIsolate].
  ///
  /// Per-item null/failure semantics match the old two-step pipeline
  /// ([decrypt] over [Base64Utils.decode]-ed bytes); base64 decode
  /// failures are reported separately via
  /// [EncodedDecryptResult.decodeFailures] so callers can keep their
  /// decode-site diagnostics.
  Future<EncodedDecryptResult> decryptEncodedInIsolate(
    List<String> encoded,
  ) async {
    if (encoded.isEmpty) {
      return EncodedDecryptResult(
        values: const [],
        decodeFailures: const [],
      );
    }
    // Isolates are not supported on web — use main-thread decryption.
    if (kIsWeb) {
      return AesGcmEncryption.decryptEncodedBatch(encoded, _secretKey);
    }
    EncodedDecryptResult result;
    try {
      // Hoist `_secretKey` into a local so the closure captures only
      // sendable data — see [decryptInIsolate].
      final keyLocal = _secretKey;
      result = await Isolate.run(
        () => AesGcmEncryption.decryptEncodedBatch(encoded, keyLocal),
      );
    } catch (e, stack) {
      // Isolate spawn failed (e.g. certain test environments).
      // Fall back to main-thread decryption.
      logger.warning('AES256Encryption: isolate spawn failed, '
          'falling back to main-thread decrypt', e, stack);
      return AesGcmEncryption.decryptEncodedBatch(encoded, _secretKey);
    }
    final decodeFailed = Set<int>.of(result.decodeFailures);
    var failCount = 0;
    for (var i = 0; i < encoded.length; i++) {
      if (decodeFailed.contains(i)) continue;
      if (result.values[i] == null) failCount++;
    }
    if (failCount > 0) {
      logger.warning(
        'AES256Encryption.decryptEncodedInIsolate: $failCount of '
        '${encoded.length} items failed to decrypt',
      );
    }
    return result;
  }

  /// Release any cached platform resources.
  void dispose() {
    AesGcmEncryption.evictCachedKey(_secretKey);
  }
}
