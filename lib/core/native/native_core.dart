import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../services/logger_service.dart' show logger;
import '../services/opentelemetry_service.dart';
import '../encryption/json_text.dart' show NativeJsonRowStatus;
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

  Future<void>? _initFuture;
  bool _available = false;
  String _status = 'not_attempted';

  /// Whether the native core loaded and may be used.
  bool get isAvailable => _available;

  /// Attempt to load the native library exactly once per process.
  ///
  /// Safe to call from anywhere; failures are logged at info level because a
  /// platform without the library is an expected configuration, not an error.
  /// Concurrent and repeat callers share one in-flight attempt, so a second
  /// call cannot observe a half-settled status.
  Future<void> ensureInitialized() => _initFuture ??= _initialize();

  Future<void> _initialize() async {
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
      _status = _available ? 'ready' : 'probe_false';
      logger.info('[NativeCore] native core ready');
    } catch (e) {
      _available = false;
      // Keep the reason coarse: it becomes a metric label, so it must stay
      // low-cardinality and must never carry payload or path detail.
      _status = e.toString().contains('not been initialized')
          ? 'bridge_uninitialized'
          : 'library_missing';
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

  /// Batch decrypt **and** JSON-parse base64 envelopes in one crossing.
  ///
  /// Each row comes back as validated JSON text (or `null`) plus a
  /// [NativeJsonRowStatus] code, so the caller can defer materialization to
  /// a worker isolate and log the exact failure class. `null` for the whole
  /// call means the native core did not run — fall back to the Dart path.
  Future<({List<String?> values, Uint8List statuses})?>
  decryptAesGcmBase64JsonBatch({
    required List<int> key,
    required List<String> envelopesBase64,
    List<int> associatedData = const <int>[],
  }) async {
    if (!_available) return null;
    if (envelopesBase64.isEmpty) {
      return (values: const <String?>[], statuses: Uint8List(0));
    }
    try {
      final batch = await rust_crypto.decryptAesGcmBase64JsonBatch(
        key: key,
        envelopesBase64: envelopesBase64,
        associatedData: associatedData,
      );
      return (values: batch.values, statuses: batch.statuses);
    } catch (e, stack) {
      _available = false;
      logger.warning(
        '[NativeCore] batch decrypt+parse failed, reverting to the Dart path',
        e,
        stack,
      );
      return null;
    }
  }

  /// Batch-decrypt raw envelopes on the calling isolate.
  ///
  /// The per-row callers (`decryptMetadata`, `decryptAgentState`,
  /// `decryptRaw` — ~502 of them for a cold catalog at 251+ sessions) each
  /// hand over one small payload, where a worker-thread hop would cost more
  /// than the cipher itself. This stays synchronous and still replaces a
  /// pure-Dart block cipher with hardware AES. Large batches should use
  /// [decryptAesGcmBase64Batch], which leaves the UI isolate entirely.
  ///
  /// Returns `null` when the native core is unavailable or threw — the
  /// caller's signal to run the Dart path.
  List<String?>? decryptAesGcmBatchSync({
    required List<Uint8List> envelopes,
    required List<int> key,
    List<int> associatedData = const <int>[],
  }) {
    if (!_available) return null;
    if (envelopes.isEmpty) return const <String?>[];
    try {
      return rust_crypto.decryptAesGcmBatchSync(
        key: key,
        envelopes: envelopes,
        associatedData: associatedData,
      );
    } catch (e, stack) {
      _available = false;
      logger.warning(
        '[NativeCore] sync batch decrypt failed, reverting to the Dart path',
        e,
        stack,
      );
      return null;
    }
  }

  /// At-rest batch decrypt: `[nonce][ciphertext][tag]`, no version byte, with
  /// [associatedData] bound as GCM AAD.
  List<String?>? decryptAtRestBatchSync({
    required List<Uint8List> payloads,
    required List<int> key,
    required List<int> associatedData,
  }) {
    if (!_available) return null;
    if (payloads.isEmpty) return const <String?>[];
    try {
      return rust_crypto.decryptAtRestBatchSync(
        key: key,
        payloads: payloads,
        associatedData: associatedData,
      );
    } catch (e, stack) {
      _available = false;
      logger.warning('[NativeCore] at-rest decrypt failed', e, stack);
      return null;
    }
  }

  /// At-rest batch encrypt. [nonces] must each be 12 CSPRNG bytes; nonce
  /// generation stays on the Dart side so the native core holds no ambient
  /// randomness.
  ///
  /// The caller that matters here is the suspend flush, which encrypts the
  /// whole message-cache window synchronously on the UI isolate before the
  /// process can be killed — multi-MB pure-Dart `encryptSync` was measured in
  /// the hundreds of milliseconds there.
  List<Uint8List?>? encryptAtRestBatchSync({
    required List<String> plaintexts,
    required List<Uint8List> nonces,
    required List<int> key,
    required List<int> associatedData,
  }) {
    if (!_available) return null;
    if (plaintexts.isEmpty) return const <Uint8List?>[];
    try {
      return rust_crypto.encryptAtRestBatchSync(
        key: key,
        plaintexts: plaintexts,
        nonces: nonces,
        associatedData: associatedData,
      );
    } catch (e, stack) {
      _available = false;
      logger.warning('[NativeCore] at-rest encrypt failed', e, stack);
      return null;
    }
  }

  /// Publish whether the native core loaded, once telemetry is up.
  ///
  /// [ensureInitialized] runs before `OpenTelemetryService().initialize()` on
  /// the startup path, so its log never reaches the collector — which left no
  /// fleet-wide way to tell whether the library actually loads on real
  /// devices, i.e. whether any of this is doing anything. Call this after
  /// telemetry is ready.
  void reportAvailability() {
    logger.info('[NativeCore] status=$_status available=$_available');
    try {
      OpenTelemetryService().recordCount(
        'app.native_core.status',
        attributes: {'available': _available.toString(), 'status': _status},
        description:
            'Whether the Rust hot-path core loaded on this launch — the '
            'denominator for judging native-path performance work',
      );
    } catch (_) {
      // Telemetry must never break startup.
    }
  }

  @visibleForTesting
  String get debugStatus => _status;

  @visibleForTesting
  void debugSetAvailable({required bool available}) {
    _initFuture = Future<void>.value();
    _available = available;
    _status = available ? 'ready' : 'library_missing';
  }

  @visibleForTesting
  void debugReset() {
    _initFuture = null;
    _available = false;
    _status = 'not_attempted';
  }
}
