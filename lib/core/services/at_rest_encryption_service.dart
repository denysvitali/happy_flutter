import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../native/native_core.dart';
import 'logger_service.dart' show logger;

/// Device/app-bound authenticated encryption for sensitive MMKV payloads.
///
/// A random AES-256 key is generated once and held by the platform secure
/// storage. Ciphertexts are bound to their storage domain with associated
/// data, preventing a valid blob from being moved between sessions or into
/// the outbox.
class AtRestEncryptionService {
  factory AtRestEncryptionService() => _instance;
  AtRestEncryptionService._({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Creates an in-memory protector with caller-owned key material.
  ///
  /// This is used by storage fakes and isolated contract tests; production
  /// persistence must use the singleton whose key is held in secure storage.
  AtRestEncryptionService.memoryOnly(Uint8List key)
    : _secureStorage = const FlutterSecureStorage(),
      _key = Uint8List.fromList(key) {
    if (key.length != _keyLength) {
      throw ArgumentError.value(key.length, 'key.length', 'must be 32');
    }
  }

  static final AtRestEncryptionService _instance = AtRestEncryptionService._();

  static const String envelopePrefix = 'happy-at-rest:v1:';
  static const String _secureStorageKey = 'happy_at_rest_payload_key_v1';
  static const int _keyLength = 32;
  static const int _nonceLength = 12;
  static const int _macLength = 16;

  static final DartAesGcm _cipher = DartAesGcm.with256bits();
  static final Random _random = Random.secure();

  final FlutterSecureStorage _secureStorage;
  Uint8List? _key;
  Future<void>? _initializing;

  bool get isReady => _key != null;

  /// Copies the active key for one queued isolate operation.
  ///
  /// The worker must pass this copy to [protectAtRestPayloadForWorker], which
  /// overwrites it after use. The service's durable key never leaves secure
  /// storage except for its process-local working copy.
  Uint8List? copyKeyForWorker() {
    final key = _key;
    return key == null ? null : Uint8List.fromList(key);
  }

  Future<void> initialize() {
    final current = _initializing;
    if (current != null) return current;
    final initializing = _initialize();
    _initializing = initializing;
    return initializing.whenComplete(() {
      if (_key == null && identical(_initializing, initializing)) {
        _initializing = null;
      }
    });
  }

  Future<void> _initialize() async {
    if (_key != null) return;
    try {
      String? stored;
      try {
        stored = await _secureStorage.read(key: _secureStorageKey);
      } catch (error) {
        if (!_isUnreadableSecureValue(error)) rethrow;
        // Android Keystore invalidation can make a value permanently
        // unreadable after a device/security change. Remove only that known
        // corrupt value; transient secure-storage errors remain retryable.
        await _secureStorage.delete(key: _secureStorageKey);
      }
      if (stored != null) {
        try {
          final decoded = base64Decode(stored);
          if (decoded.length == _keyLength) {
            _key = Uint8List.fromList(decoded);
            return;
          }
        } catch (_) {
          // Invalid legacy/corrupt value is replaced below. Ciphertexts made
          // with the lost key will fail authentication and be discarded.
        }
        await _secureStorage.delete(key: _secureStorageKey);
      }

      final generated = Uint8List(_keyLength);
      for (var i = 0; i < generated.length; i++) {
        generated[i] = _random.nextInt(256);
      }
      // Do not use a key until its durable secure-storage write succeeds.
      await _secureStorage.write(
        key: _secureStorageKey,
        value: base64Encode(generated),
      );
      _key = generated;
    } catch (error, stack) {
      logger.error(
        '[AtRestEncryption] secure key initialization failed',
        error,
        stack,
      );
      rethrow;
    }
  }

  bool _isUnreadableSecureValue(Object error) {
    final text = error.toString();
    return error is PlatformException &&
        error.message == 'read' &&
        (text.contains('IllegalBlockSizeException') ||
            text.contains('BadPaddingException') ||
            text.contains('WRONG_FINAL_BLOCK_LENGTH') ||
            text.contains('AEADBadTagException'));
  }

  bool isProtected(String value) => value.startsWith(envelopePrefix);

  String? protectString(String plaintext, {required String associatedData}) {
    final key = _key;
    if (key == null) return null;
    try {
      return _protectStringWithKey(
        plaintext,
        associatedData: associatedData,
        key: key,
      );
    } catch (error, stack) {
      logger.warning(
        '[AtRestEncryption] payload encryption failed',
        error,
        stack,
      );
      return null;
    }
  }

  static String _protectStringWithKey(
    String plaintext, {
    required String associatedData,
    required Uint8List key,
  }) {
    if (key.length != _keyLength) {
      throw ArgumentError.value(key.length, 'key.length', 'must be 32');
    }
    final nonce = Uint8List(_nonceLength);
    for (var i = 0; i < nonce.length; i++) {
      nonce[i] = _random.nextInt(256);
    }
    // Native core first. The suspend flush seals the whole message-cache
    // window synchronously on the UI isolate, where pure-Dart `encryptSync`
    // over a multi-MB payload was measured in the hundreds of milliseconds.
    // Byte layout is identical ([nonce][ciphertext][tag], AAD-bound), so the
    // envelope stays readable by the Dart path and by older builds.
    final nativeSealed = NativeCore.instance.encryptAtRestBatchSync(
      plaintexts: [plaintext],
      nonces: [nonce],
      key: key,
      associatedData: utf8.encode(associatedData),
    );
    if (nativeSealed != null &&
        nativeSealed.length == 1 &&
        nativeSealed.single != null) {
      return '$envelopePrefix${base64Encode(nativeSealed.single!)}';
    }

    final keyData = SecretKeyData(Uint8List.fromList(key));
    try {
      final box = _cipher.encryptSync(
        utf8.encode(plaintext),
        secretKeyData: keyData,
        nonce: nonce,
        aad: utf8.encode(associatedData),
      );
      final bytes =
          Uint8List(
              box.nonce.length + box.cipherText.length + box.mac.bytes.length,
            )
            ..setAll(0, box.nonce)
            ..setAll(box.nonce.length, box.cipherText)
            ..setAll(box.nonce.length + box.cipherText.length, box.mac.bytes);
      return '$envelopePrefix${base64Encode(bytes)}';
    } finally {
      keyData.destroy();
    }
  }

  String? unprotectString(String protected, {required String associatedData}) {
    final key = _key;
    if (key == null || !isProtected(protected)) return null;
    try {
      return _unprotectStringWithKey(
        protected,
        associatedData: associatedData,
        key: key,
      );
    } catch (error) {
      logger.warning(
        '[AtRestEncryption] payload authentication failed: '
        '${error.runtimeType}',
      );
      return null;
    }
  }

  static String? _unprotectStringWithKey(
    String protected, {
    required String associatedData,
    required Uint8List key,
  }) {
    if (!protected.startsWith(envelopePrefix) || key.length != _keyLength) {
      return null;
    }
    final payload = base64Decode(protected.substring(envelopePrefix.length));
    if (payload.length < _nonceLength + _macLength) return null;
    final nativeOpened = NativeCore.instance.decryptAtRestBatchSync(
      payloads: [payload],
      key: key,
      associatedData: utf8.encode(associatedData),
    );
    if (nativeOpened != null && nativeOpened.length == 1) {
      final opened = nativeOpened.single;
      // A null here means authentication genuinely failed for this payload,
      // which is the same answer the Dart path gives — but fall through so
      // the existing throw/log behaviour stays the single source of truth.
      if (opened != null) return opened;
    }

    final keyData = SecretKeyData(Uint8List.fromList(key));
    try {
      final bytes = payload;
      final nonce = bytes.sublist(0, _nonceLength);
      final mac = Mac(bytes.sublist(bytes.length - _macLength));
      final ciphertext = bytes.sublist(_nonceLength, bytes.length - _macLength);
      final cleartext = _cipher.decryptSync(
        SecretBox(ciphertext, nonce: nonce, mac: mac),
        secretKeyData: keyData,
        aad: utf8.encode(associatedData),
      );
      return utf8.decode(cleartext);
    } finally {
      keyData.destroy();
    }
  }
}

/// Encrypts one payload in an isolate and destroys the caller's key copy.
///
/// This intentionally performs no logging because isolate workers cannot use
/// the process logger safely. A `null` result is reported by the caller.
String? protectAtRestPayloadForWorker(
  String plaintext, {
  required String associatedData,
  required Uint8List key,
}) {
  try {
    return AtRestEncryptionService._protectStringWithKey(
      plaintext,
      associatedData: associatedData,
      key: key,
    );
  } catch (_) {
    return null;
  } finally {
    key.fillRange(0, key.length, 0);
  }
}

/// Decrypts one payload in an isolate and destroys the caller's key copy.
String? unprotectAtRestPayloadForWorker(
  String protected, {
  required String associatedData,
  required Uint8List key,
}) {
  try {
    return AtRestEncryptionService._unprotectStringWithKey(
      protected,
      associatedData: associatedData,
      key: key,
    );
  } catch (_) {
    return null;
  } finally {
    key.fillRange(0, key.length, 0);
  }
}
