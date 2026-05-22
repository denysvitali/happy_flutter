import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sodium/sodium.dart';

import '../services/logger_service.dart' show logger;
import 'sodium_singleton.dart';

/// Identifies the envelope the failing ciphertext appears to use.
///
/// `aesV0` is the new AES-256-GCM bundle (1-byte version `0` prefix
/// followed by IV + ciphertext + tag).  When such a payload is fed into
/// the legacy NaCl decryptor we want to know — it means the wrong
/// decryptor was picked for a wire payload, not that the user lost a
/// key.
///
/// `naclSecretBox` is the legacy libsodium `crypto_secretbox_easy`
/// bundle (24-byte nonce + ciphertext + 16-byte MAC).
enum DecryptEnvelope {
  aesV0,
  naclSecretBox,
  unknown,
}

extension DecryptEnvelopeWire on DecryptEnvelope {
  String get wire {
    switch (this) {
      case DecryptEnvelope.aesV0:
        return 'aes-v0';
      case DecryptEnvelope.naclSecretBox:
        return 'nacl-secret-box';
      case DecryptEnvelope.unknown:
        return 'unknown';
    }
  }
}

/// Aggregated diagnostic payload for a decrypt failure (one row per
/// `(scope, keyFp, envelope, stage)`).  Used both by the in-process
/// Sentry hook and by tests that need to assert what we *would* report
/// without invoking the real Sentry SDK.
class DecryptFailureDiagnostic {
  DecryptFailureDiagnostic({
    required this.scope,
    required this.keyFp,
    required this.envelope,
    required this.stage,
    required this.reason,
    required this.cipherLen,
    required this.count,
  });

  /// Optional batch scope — e.g. a session id, machine id, or RPC
  /// route — used to deduplicate Sentry captures when a single key
  /// rotation invalidates an entire batch.  `null` when the caller did
  /// not provide one (single-payload code paths).
  final String? scope;
  final String keyFp;
  final DecryptEnvelope envelope;
  final String stage;
  final String reason;
  final int cipherLen;
  final int count;

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (scope != null) 'scope': scope,
        'key_fp': keyFp,
        'envelope': envelope.wire,
        'stage': stage,
        'reason': reason,
        'cipher_len': cipherLen,
        'count': count,
      };
}

/// CryptoSecretBox encryption using libsodium (crypto_secretbox_easy)
/// Compatible with React Native's @more-tech/react-native-libsodium
class CryptoSecretBox {
  static const int _nonceSize = 24; // crypto_secretbox_NONCEBYTES (libsodium)
  static const int _keySize = 32; // crypto_secretbox_KEYBYTES
  static const int _macSize = 16; // crypto_secretbox_MACBYTES

  /// Cached SecureKey per raw key bytes to avoid per-message allocation
  /// and native memory churn. Key: base64-encoded raw key.
  static final _secureKeyCache = <String, SecureKey>{};

  /// Rate-limits Sentry captures so a key-rotation that fails on 100
  /// historical messages does not produce 100 events.  Keyed by
  /// `<scope>|<keyFingerprint>|<envelope>|<stage>` so two consecutive
  /// failures with the same scope+key produce ONE Sentry capture.
  static final _sentryCaptureCooldown = <String, DateTime>{};
  static const _sentryCooldown = Duration(minutes: 5);

  /// Sink for tests to observe what would be reported without invoking
  /// the real Sentry SDK.  Always emitted, even when the Sentry capture
  /// is throttled — the `count` field carries the absorbed multiplier.
  @visibleForTesting
  static void Function(DecryptFailureDiagnostic diagnostic)? debugSink;

  /// Zone-local key for stashing the current diagnostic scope (session
  /// id, machine id, RPC route) across the polymorphic `Encryptor`
  /// boundary without changing the interface.
  static const _scopeZoneKey = #happy_flutter_decrypt_scope;

  /// Read the current diagnostic scope from the surrounding Zone.
  /// Returns null when the caller did not wrap their work in
  /// [withDiagnosticScope].
  static String? get currentDiagnosticScope {
    final value = Zone.current[_scopeZoneKey];
    return value is String ? value : null;
  }

  /// Run [body] with a diagnostic scope attached to the surrounding
  /// Zone.  Any call to [decrypt] inside [body] (including through the
  /// polymorphic `Encryptor` interface) will tag failures with this
  /// scope for Sentry grouping.
  ///
  /// Nesting replaces the scope for the inner body; the outer scope is
  /// restored on return.
  static Future<T> withDiagnosticScope<T>(
    String scope,
    Future<T> Function() body,
  ) {
    return runZoned<Future<T>>(
      body,
      zoneValues: <Object?, Object?>{_scopeZoneKey: scope},
    );
  }

  /// Short fingerprint of a key — first 8 base64 chars of the leading
  /// raw bytes — used as a grouping tag.  Does NOT expose the key
  /// itself; only the first 6 bytes (48 bits) are mixed in, far below
  /// the 256-bit key entropy.
  static String _keyFingerprint(Uint8List secretKey) {
    final prefix = base64.encode(
      secretKey.length >= 6 ? secretKey.sublist(0, 6) : secretKey,
    );
    return prefix.substring(0, prefix.length.clamp(0, 8));
  }

  /// Best-effort envelope detection from the leading bytes of a
  /// payload.  Cheap heuristic — meant for diagnostics only.  An AES-v0
  /// bundle starts with `0x00` then a 12-byte IV; a NaCl secret box
  /// bundle starts with a 24-byte random nonce.  This is ambiguous (a
  /// NaCl nonce could legitimately start with `0x00`) so callers should
  /// treat the result as a strong hint, not a guarantee.
  @visibleForTesting
  static DecryptEnvelope detectEnvelope(Uint8List encryptedData) {
    if (encryptedData.length < _nonceSize + _macSize) {
      return DecryptEnvelope.unknown;
    }
    // AES-v0 bundle is `[1-byte version=0][12-byte IV][ciphertext]
    // [16-byte tag]`.  If a payload starts with `0x00`, has the right
    // length for an AES bundle, AND is shorter than a typical NaCl
    // ciphertext for the same plaintext (NaCl carries a 24-byte nonce
    // and a 16-byte MAC up front), it is likely an AES envelope routed
    // to the wrong decryptor.  This is a heuristic — a legitimate NaCl
    // nonce can start with `0x00` — so the caller should treat the
    // result as a diagnostic hint, not a guarantee.
    if (encryptedData[0] == 0 &&
        encryptedData.length >= 1 + 12 + 16 &&
        encryptedData.length < 1024) {
      return DecryptEnvelope.aesV0;
    }
    return DecryptEnvelope.naclSecretBox;
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

  /// Reset throttle state — for tests only.
  @visibleForTesting
  static void resetThrottle() {
    _sentryCaptureCooldown.clear();
  }

  /// Synthesize a decrypt failure as if it had come from the real
  /// libsodium path.  Intended for tests that need to exercise the
  /// batch-grouping / fingerprint / envelope reporting logic without
  /// linking against native libsodium.
  ///
  /// Returns the `(diagnostic, wouldSentry)` pair so callers can
  /// assert both what was reported AND whether the per-batch throttle
  /// suppressed a Sentry capture.
  @visibleForTesting
  static ({DecryptFailureDiagnostic diagnostic, bool wouldSentry})
      simulateDecryptFailureForTest({
    required Uint8List secretKey,
    required Uint8List cipher,
    required String stage,
    required String reason,
    String? scope,
  }) {
    final envelope = detectEnvelope(cipher);
    final fingerprint = _keyFingerprint(secretKey);
    final critical = stage == 'utf8' || stage == 'json';
    final throttleKey = '${scope ?? '_'}|$fingerprint|${envelope.wire}|$stage';
    final wouldSentry = critical || _shouldCapture(throttleKey);

    final diagnostic = DecryptFailureDiagnostic(
      scope: scope,
      keyFp: fingerprint,
      envelope: envelope,
      stage: stage,
      reason: reason,
      cipherLen: cipher.length,
      count: 1,
    );
    debugSink?.call(diagnostic);
    return (diagnostic: diagnostic, wouldSentry: wouldSentry);
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

  /// Decrypt a single payload.  `scope` identifies the logical batch
  /// (e.g. session id, machine id, RPC route) so Sentry captures are
  /// grouped per scope rather than per ciphertext: a single rotated
  /// key over a 100-message batch produces ONE Sentry event instead of
  /// 100.
  static Future<dynamic> decrypt(
    Uint8List encryptedData,
    Uint8List secretKey, {
    String? scope,
  }) async {
    // Fall back to the Zone-attached scope so polymorphic call sites
    // that go through the `Encryptor` interface still get grouped
    // captures.
    final effectiveScope = scope ?? currentDiagnosticScope;
    // Track the stage for forensics — auth failures (expected on key
    // rotation) vs decode failures (indicate corrupt ciphertext or
    // double-encoding bugs) should be grouped differently.
    var stage = 'format-check';
    try {
      if (encryptedData.length < _nonceSize + _macSize) {
        _captureDecryptFailure(
          stage: 'too-short',
          reason: 'payload_below_nonce_plus_mac',
          secretKey: secretKey,
          cipherLen: encryptedData.length,
          envelope: detectEnvelope(encryptedData),
          scope: effectiveScope,
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
        envelope: detectEnvelope(encryptedData),
        scope: effectiveScope,
        error: e,
        stack: stack,
      );
      return null;
    }
  }

  /// Emit a structured log and (rate-limited) Sentry event for a
  /// decryption failure.
  ///
  /// Grouping key: `<scope>|<keyFp>|<envelope>|<stage>`.  Two
  /// consecutive failures with the same group produce ONE Sentry
  /// capture inside the cooldown window; the second call still emits a
  /// debug sink event and an info log so test assertions and local
  /// debugging see every failure.
  ///
  /// Post-sodium stages (`utf8` / `json`) are always captured because
  /// the MAC check has already passed — anything weird at that point
  /// indicates a real bug, not a missing key.
  static void _captureDecryptFailure({
    required String stage,
    required String reason,
    required Uint8List secretKey,
    required int cipherLen,
    required DecryptEnvelope envelope,
    String? scope,
    Object? error,
    StackTrace? stack,
  }) {
    final fingerprint = _keyFingerprint(secretKey);
    final critical = stage == 'utf8' || stage == 'json';
    final throttleKey = '${scope ?? '_'}|$fingerprint|${envelope.wire}|$stage';
    final captureNow = critical || _shouldCapture(throttleKey);

    final diagnostic = DecryptFailureDiagnostic(
      scope: scope,
      keyFp: fingerprint,
      envelope: envelope,
      stage: stage,
      reason: reason,
      cipherLen: cipherLen,
      count: 1,
    );
    debugSink?.call(diagnostic);

    // Sodium auth failures during a key rotation are expected; demote
    // the suppressed-capture case to info so dev-logs/Sentry
    // breadcrumbs stay quiet while we still get one warning per batch.
    final structured = 'CryptoSecretBox.decrypt failed '
        'scope=${scope ?? '-'} stage=$stage reason=$reason '
        'cipherLen=$cipherLen keyFp=$fingerprint '
        'envelope=${envelope.wire}'
        '${error == null ? '' : '\n$error'}';
    if (captureNow) {
      logger.warning(structured);
    } else {
      logger.info(structured);
      return;
    }

    unawaited(
      Sentry.captureException(
        error ??
            StateError(
              'CryptoSecretBox.decrypt failed: stage=$stage reason=$reason',
            ),
        stackTrace: stack ?? StackTrace.current,
        withScope: (sentryScope) {
          sentryScope
            ..setTag('decrypt_stage', stage)
            ..setTag('decrypt_reason', reason)
            ..setTag('decrypt_envelope', envelope.wire)
            ..setTag('key_fp', fingerprint);
          if (scope != null) {
            sentryScope.setTag('decrypt_scope', scope);
          }
          sentryScope.setContexts('decrypt', diagnostic.toMap()
            ..['nonce_size'] = _nonceSize
            ..['critical'] = critical);
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
    Uint8List secretKey, {
    String? scope,
  }) async {
    if (data.isEmpty) return [];
    final results = <dynamic>[];
    for (var i = 0; i < data.length; i++) {
      results.add(await decrypt(data[i], secretKey, scope: scope));
      // Yield every item so the Flutter UI can render between decryptions.
      // This keeps the main isolate responsive even when decrypting
      // hundreds of legacy NaCl messages on cold start.
      await Future<void>.delayed(Duration.zero);
    }
    return results;
  }
}
