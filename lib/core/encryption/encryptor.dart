import 'dart:convert';
import 'dart:isolate';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../native/native_core.dart';
import '../services/logger_service.dart' show logger;

import 'aes_gcm.dart';
import 'crypto_secret_box.dart';
import 'json_text.dart';

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
    // Native core first. This is the path `SessionEncryption.decryptMetadata`
    // / `decryptAgentState` / `decryptRaw` take, i.e. the ~502 inline
    // pure-Dart AES-GCM decrypts a cold catalog runs at 251+ sessions — the
    // single largest measured UI-isolate block. The sync bridge is used
    // deliberately: these are small per-row payloads where a worker hop would
    // cost more than the cipher.
    if (data.isNotEmpty) {
      final native = NativeCore.instance.decryptAesGcmBatchSync(
        envelopes: data,
        key: _secretKey,
      );
      if (native != null && native.length == data.length) {
        final results = <dynamic>[];
        for (final json in native) {
          if (json == null) {
            // Same contract as below: an unreadable row is null, letting the
            // caller fall through to legacy/NaCl instead of throwing.
            results.add(null);
            continue;
          }
          try {
            results.add(jsonDecode(json));
          } catch (_) {
            results.add(null);
          }
        }
        return results;
      }
    }

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
  Future<List<dynamic>> decryptInIsolate(List<Uint8List> data) async {
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
        () => AesGcmEncryption.decryptBatch(stripped, keyLocal),
      );
    } catch (e, stack) {
      // Isolate spawn failed (e.g. certain test environments).
      // Fall back to main-thread decryption.
      logger.warning(
        'AES256Encryption: isolate spawn failed, '
        'falling back to main-thread decrypt',
        e,
        stack,
      );
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
      logger.warning(
        'AES256Encryption: isolate spawn failed, '
        'falling back to main-thread encrypt',
        e,
        stack,
      );
      return encrypt(data);
    }
    return [
      for (final item in encrypted)
        Uint8List(item.length + 1)
          ..[0] =
              0 // version byte, matching React Native format
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
      return EncodedDecryptResult(values: const [], decodeFailures: const []);
    }
    // Isolates are not supported on web — decrypt on the main thread in
    // chunks with an event-loop turn between them. Pure-Dart AES-GCM plus
    // utf8/jsonDecode over a whole socket batch is otherwise one long
    // synchronous block (sync-completing futures never reach the event
    // loop); chunking bounds each block to a few items so streaming
    // batches cannot starve the frame that must paint them. Mirrors the
    // per-item yields in CryptoSecretBox.decryptBatchInIsolate. Output is
    // identical to a single batch call: same value order, with
    // decode-failure indices rebased from chunk-local to batch-absolute.
    if (kIsWeb) {
      const webChunkSize = 8;
      final values = List<dynamic>.filled(encoded.length, null);
      final decodeFailures = <int>[];
      for (var start = 0; start < encoded.length; start += webChunkSize) {
        final end = min(start + webChunkSize, encoded.length);
        if (start > 0) {
          await Future<void>.delayed(Duration.zero);
        }
        final chunk = await AesGcmEncryption.decryptEncodedBatch(
          encoded.sublist(start, end),
          _secretKey,
        );
        values.setRange(start, end, chunk.values);
        for (final index in chunk.decodeFailures) {
          decodeFailures.add(start + index);
        }
      }
      return EncodedDecryptResult(
        values: values,
        decodeFailures: decodeFailures,
      );
    }
    // Native core first: `DartAesGcm` is a pure-Dart block cipher (the app
    // has no `cryptography_flutter`), so a whole catalog or socket batch is
    // a long CPU block that an isolate only *moves* — it still costs a spawn
    // plus a full copy of the payload on the UI isolate. Rust does the batch
    // with hardware AES in one crossing. Unavailable or failing native core
    // returns null and we continue to the proven Dart path below.
    final nativeValues = await NativeCore.instance.decryptAesGcmBase64Batch(
      key: _secretKey,
      envelopesBase64: encoded,
    );
    if (nativeValues != null && nativeValues.length == encoded.length) {
      final values = List<dynamic>.filled(encoded.length, null);
      final decodeFailures = <int>[];
      for (var i = 0; i < encoded.length; i++) {
        final json = nativeValues[i];
        if (json == null) {
          // Indistinguishable here between "bad base64" and "auth failed";
          // both mean this row must fall through to the legacy/NaCl path,
          // which is exactly what a decode failure signals.
          decodeFailures.add(i);
          continue;
        }
        try {
          values[i] = jsonDecode(json);
        } catch (_) {
          decodeFailures.add(i);
        }
      }
      return EncodedDecryptResult(
        values: values,
        decodeFailures: decodeFailures,
      );
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
      logger.warning(
        'AES256Encryption: isolate spawn failed, '
        'falling back to main-thread decrypt',
        e,
        stack,
      );
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

  /// Like [decryptEncodedInIsolate], but when the native core is available
  /// the JSON parse happens in Rust too and each value comes back as a
  /// [JsonText] — validated, not yet materialized — so no `jsonDecode` runs
  /// on the calling isolate for the batch. Consumers materialize it where
  /// they run (`processDecryptedMessages` does so inside its worker). Every
  /// other path (web, native unavailable, native fault) returns the same
  /// decoded values as [decryptEncodedInIsolate].
  ///
  /// Failure semantics are unchanged: a row that could not be decoded,
  /// authenticated or parsed is `null` and listed in
  /// [EncodedDecryptResult.decodeFailures] when its base64 was bad. The
  /// native path additionally logs one bounded per-class summary per batch
  /// instead of the old "base64 or auth, can't tell".
  Future<EncodedDecryptResult> decryptEncodedJsonInIsolate(
    List<String> encoded,
  ) async {
    if (encoded.isEmpty || kIsWeb) {
      return decryptEncodedInIsolate(encoded);
    }
    final native = await NativeCore.instance.decryptAesGcmBase64JsonBatch(
      key: _secretKey,
      envelopesBase64: encoded,
    );
    if (native == null ||
        native.values.length != encoded.length ||
        native.statuses.length != encoded.length) {
      return decryptEncodedInIsolate(encoded);
    }
    final values = List<dynamic>.filled(encoded.length, null);
    final decodeFailures = <int>[];
    Map<int, int>? failureClasses;
    for (var i = 0; i < encoded.length; i++) {
      final text = native.values[i];
      final status = native.statuses[i];
      if (text != null && status == NativeJsonRowStatus.ok) {
        values[i] = JsonText(text);
        continue;
      }
      if (status == NativeJsonRowStatus.badBase64) decodeFailures.add(i);
      failureClasses ??= <int, int>{};
      failureClasses[status] = (failureClasses[status] ?? 0) + 1;
    }
    if (failureClasses != null) {
      final summary = failureClasses.entries
          .map((e) => '${NativeJsonRowStatus.label(e.key)}=${e.value}')
          .join(' ');
      logger.warning(
        'AES256Encryption.decryptEncodedJsonInIsolate: '
        '${encoded.length} items, failures: $summary',
      );
    }
    return EncodedDecryptResult(values: values, decodeFailures: decodeFailures);
  }

  /// Release any cached platform resources.
  void dispose() {
    AesGcmEncryption.evictCachedKey(_secretKey);
  }
}
