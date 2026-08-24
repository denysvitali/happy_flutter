import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../services/logger_service.dart' show logger;
import 'generated/frb_generated.dart';
import 'generated/api/crypto_api.dart' as rust_crypto;

/// Gateway to the Rust hot-path core (`rust/happy_core`).
///
/// Flutter is the view layer; the CPU-bound work that used to block the Dart
/// UI isolate runs here instead. Production telemetry motivating this: frozen
/// frames on the chat route ran ~487 ms p95 while frame *build* and *raster*
/// were only ~9.6 ms each — ~96 % of every frozen frame was the UI isolate
/// blocked on pure computation.
///
/// **Availability is never assumed.** The native library is only present once
/// a platform's build wires it in, so every entry point is nullable and every
/// caller must keep its existing Dart path as the fallback. A missing or
/// broken library degrades to "slow but correct", never to a crash and never
/// to a wrong decryption.
class NativeCore {
  NativeCore._();

  static final NativeCore instance = NativeCore._();

  bool _initAttempted = false;
  bool _available = false;

  /// Whether the native core loaded and may be used.
  bool get isAvailable => _available;

  /// Attempt to load the native library exactly once per process.
  ///
  /// Safe to call from anywhere; failures are logged at info level because a
  /// platform without the library is an expected configuration, not an error.
  Future<void> ensureInitialized() async {
    if (_initAttempted) return;
    _initAttempted = true;
    try {
      await RustLib.init();
    } catch (_) {
      // `RustLib.init()` throws if the bridge is already initialized (hot
      // restart, a second entry point, or a test that re-runs this). That is
      // not a failure, and it must not be read as one — the probe below is
      // the only authoritative availability signal.
    }
    try {
      // Cheap round-trip: proves symbols actually resolve, not merely that
      // the library file was found.
      _available = rust_crypto.nativeCoreReady();
      logger.info('[NativeCore] native core ready');
    } catch (e) {
      _available = false;
      logger.info(
        '[NativeCore] native core unavailable, using the Dart path: $e',
      );
    }
  }

  /// Batch-decrypt base64 `[version][nonce][ct][tag]` envelopes.
  ///
  /// Returns one slot per input — the decrypted UTF-8 JSON string, or `null`
  /// where that row failed — preserving index alignment so callers can
  /// scatter results back by position and fall through to the legacy/NaCl
  /// path for the failures, exactly as the Dart implementation does.
  ///
  /// Returns `null` (the whole call, not a row) when the native core is
  /// unavailable or threw, which is the caller's signal to run the Dart
  /// implementation instead.
  Future<List<String?>?> decryptAesGcmBase64Batch({
    required List<int> key,
    required List<String> envelopesBase64,
    List<int> associatedData = const <int>[],
  }) async {
    if (!_available) return null;
    if (envelopesBase64.isEmpty) return const <String?>[];
    try {
      return await rust_crypto.decryptAesGcmBase64Batch(
        key: key,
        envelopesBase64: envelopesBase64,
        associatedData: associatedData,
      );
    } catch (e, stack) {
      // Never let a native fault break decryption: report it and let the
      // caller fall back. Latch it off so one bad platform build cannot cost
      // an FFI attempt on every subsequent batch.
      _available = false;
      logger.warning(
        '[NativeCore] batch decrypt failed, reverting to the Dart path',
        e,
        stack,
      );
      return null;
    }
  }

  @visibleForTesting
  void debugSetAvailable({required bool available}) {
    _initAttempted = true;
    _available = available;
  }

  @visibleForTesting
  void debugReset() {
    _initAttempted = false;
    _available = false;
  }
}
