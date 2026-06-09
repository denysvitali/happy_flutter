// NaCl batch-decrypt worker that runs inside `Isolate.run()`.
//
// Architecture context
// --------------------
// The NaCl FFI library backs `SecureKey` with native memory that cannot
// cross isolate boundaries. The `no_isolate_in_crypto_test.dart`
// architecture guard forbids importing `dart:isolate` next to
// `CryptoSecretBox`/`CryptoBox`/`sodiumSingleton` precisely because
// shipping a `SecureKey` (or anything that transitively holds one)
// through an isolate message would corrupt it.
//
// This file is the *one* allowed exception: it owns the worker
// function and the boundary code. The worker takes ONLY sendable
// plain-old-data (PODs) — `Uint8List` ciphertext + `Uint8List` raw key
// bytes — and rebuilds its own `Sodium`, `SecureKey`, and cipher state
// inside the worker isolate. Nothing native is shared across the
// boundary.
//
// The fix mirrors the pattern applied to `_offline_tts_service_native`
// and `AES256Encryption.decryptInIsolate` to dodge
// "Illegal argument in isolate message: object is unsendable
// Library:'dart:async' Class: _Future" (GlitchTip HAPPY_FLUTTER-3C5).

import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sodium/sodium.dart' show SecureKey;

import 'sodium_loader.dart';

/// Minimum batch size that justifies the ~10–50ms isolate-spawn cost.
///
/// Below this threshold the caller decrypts inline with periodic
/// `Future.delayed(Duration.zero)` yields to keep the UI thread
/// responsive without paying for an isolate round-trip.
const int kNaClIsolateBatchThreshold = 20;

/// Sendable request payload for [_naclDecryptBatchWorker].
///
/// Only PODs (`Uint8List`, `List<Uint8List>`) live on this object so the
/// Dart isolate message protocol can serialize it without dragging
/// the caller's `_Future`/`Encryptor`/`SecureKey` into the wire.
class _NaClBatchRequest {
  const _NaClBatchRequest({
    required this.cipherTexts,
    required this.secretKey,
    required this.nonceSize,
    required this.macSize,
  });

  final List<Uint8List> cipherTexts;
  final Uint8List secretKey;
  final int nonceSize;
  final int macSize;
}

/// Top-level worker that runs inside `Isolate.run()`.
///
/// Initialises a fresh `Sodium` instance (cheap on warm boot; cached by
/// `package:sodium_libs` across calls in long-lived isolates, but we
/// spawn a new isolate per batch so each run pays the full cost — keep
/// the batch threshold high), builds a worker-local `SecureKey`, and
/// returns the decrypted JSON values (or `null` per item on failure).
///
/// IMPORTANT: This is a TOP-LEVEL function. Do not move it into a
/// class instance — `Isolate.run` would then capture the receiver and
/// pull non-sendable Futures into the isolate message.
Future<List<dynamic>> _naclDecryptBatchWorker(
  _NaClBatchRequest req,
) async {
  final sodium = await loadSodium();
  final secureKey = SecureKey.fromList(sodium, req.secretKey);
  try {
    final results = <dynamic>[];
    for (final cipher in req.cipherTexts) {
      try {
        if (cipher.length < req.nonceSize + req.macSize) {
          results.add(null);
          continue;
        }
        final nonce = cipher.sublist(0, req.nonceSize);
        final encrypted = cipher.sublist(req.nonceSize);
        final decrypted = sodium.crypto.secretBox.openEasy(
          cipherText: encrypted,
          nonce: nonce,
          key: secureKey,
        );
        results.add(jsonDecode(utf8.decode(decrypted)));
      } catch (_) {
        // Per-item failure: surface as `null` so callers can route the
        // failure through their own diagnostics on the main isolate
        // (we have no access to `logger` / Sentry from inside an
        // isolate). The main thread re-decrypts the failed items via
        // `CryptoSecretBox.decrypt` to harvest the structured failure
        // reason.
        results.add(null);
      }
    }
    return results;
  } finally {
    // SecureKey holds native memory; release deterministically when
    // the worker exits. The isolate also tears down on return, but
    // explicit dispose is the documented contract.
    secureKey.dispose();
  }
}

/// Decrypt a batch of NaCl secret-box ciphertexts inside `Isolate.run`.
///
/// Returns the decoded JSON value (or `null` per failed item).
///
/// The caller is expected to:
///   1. Pre-filter on `cipher.length >= [kNaClIsolateBatchThreshold]`.
///   2. Replay any `null` results through `CryptoSecretBox.decrypt`
///      on the main isolate to capture structured failure diagnostics
///      (envelope detection, Sentry scope, etc).
Future<List<dynamic>> decryptNaClBatchInIsolate({
  required List<Uint8List> cipherTexts,
  required Uint8List secretKey,
  required int nonceSize,
  required int macSize,
}) {
  final req = _NaClBatchRequest(
    cipherTexts: cipherTexts,
    secretKey: secretKey,
    nonceSize: nonceSize,
    macSize: macSize,
  );
  return Isolate.run(() => _naclDecryptBatchWorker(req));
}
