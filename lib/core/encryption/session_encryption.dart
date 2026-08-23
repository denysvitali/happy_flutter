import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:typed_data';

import '../services/failure_telemetry.dart';
import '../services/logger_service.dart' show logger;
import '../services/message_processing_service.dart';
import '../wire/wire_parsers.dart';

import 'base64.dart';
import 'crypto_secret_box.dart';
import 'encryption_cache.dart';
import 'encryptor.dart';
import 'message_processor.dart';

/// Extracts the base64 ciphertext from a message content value.
/// Supports the old JSON-wrapper format `{'t': 'encrypted', 'c': '<b64>'}`
/// and the new server format where content is the plain base64 string.
String _base64FromContent(dynamic contentRaw) {
  if (contentRaw is Map<String, dynamic>) {
    return contentRaw['c'] as String? ?? '';
  }
  if (contentRaw is String) {
    // The server sometimes JSON-encodes the content field, producing either:
    //   '{"t":"encrypted","c":"<base64>"}' — try JSON decode → extract 'c'
    //   '"<base64>"'                       — try JSON decode → bare string
    try {
      final decoded = jsonDecode(contentRaw);
      if (decoded is Map<String, dynamic>) {
        return decoded['c'] as String? ?? '';
      }
      if (decoded is String) {
        return decoded;
      }
    } catch (_) {
      // Not JSON — treat as raw base64 string
    }
    return contentRaw;
  }
  return '';
}

/// Build a cache key that changes when a message payload changes.
///
/// Some backends update an existing message record in place (same `id`,
/// different encrypted `content`). Caching only by `id` keeps stale content.
String _messageCacheKey(Map<String, dynamic> message) {
  final messageId = message['id'] as String? ?? '';
  if (messageId.isEmpty) return '';
  final signature = _messageContentSignature(message['content']);
  return '$messageId:$signature';
}

/// Collision-resistant signature for a string.
///
/// Dart's `String.hashCode` is not guaranteed to be collision-free.
/// Instead we combine length + head (first 32 chars) + tail (last 32
/// chars) which is unique in practice for base64 ciphertext because
/// the nonce/IV prefix and auth tag suffix differ per encryption.
String _stableSignature(String s) {
  final len = s.length;
  if (len <= 64) return '$len:$s';
  return '$len:${s.substring(0, 32)}:'
      '${s.substring(len - 32)}';
}

String _messageContentSignature(dynamic contentRaw) {
  final base64Payload = _base64FromContent(contentRaw);
  if (base64Payload.isNotEmpty) {
    return 'enc:${_stableSignature(base64Payload)}';
  }
  if (contentRaw is String) {
    return 'str:${_stableSignature(contentRaw)}';
  }
  if (contentRaw is Map || contentRaw is List) {
    try {
      final encoded = jsonEncode(contentRaw);
      return 'json:${_stableSignature(encoded)}';
    } catch (_) {
      // Fall through to raw hash.
    }
  }
  return 'raw:${contentRaw?.hashCode ?? 0}';
}

/// Classifies a message content value in a single pass.
///
/// Supports the old JSON-wrapper format `{'t': 'encrypted', 'c': ...}`,
/// JSON-encoded wrapper strings, JSON-encoded bare base64 strings, and
/// raw base64 strings — the exact union of shapes the previous two-pass
/// pipeline accepted.
///
/// - [Classification.wasEncrypted]: the flag `processDecryptedMessages`
///   consumes (drives the undecryptable-bubble vs silent-drop decision).
/// - [Classification.routeToDecrypt]: whether the row enters the decrypt
///   batch.
/// - [Classification.b64]: ciphertext payload when routed to decrypt.
/// - [Classification.passthrough]: caller-facing content for rows that
///   are not routed to decrypt.
///
/// The two flags intentionally diverge for strings holding *valid JSON*
/// of a non-map/non-string shape (e.g. `'[1,2,3]'`): the historical
/// classifier reported them as plain content while the decrypt router
/// still attempted them as base64 — a guaranteed decode failure that is
/// preserved verbatim rather than silently promoted to pass-through.
typedef Classification = ({
  bool wasEncrypted,
  bool routeToDecrypt,
  String b64,
  dynamic passthrough,
});

Classification _classifyContent(dynamic contentRaw) {
  if (contentRaw is Map<String, dynamic>) {
    final encrypted = contentRaw['t'] == 'encrypted';
    return (
      wasEncrypted: encrypted,
      routeToDecrypt: encrypted,
      b64: encrypted ? contentRaw['c'] as String? ?? '' : '',
      passthrough: contentRaw,
    );
  }
  if (contentRaw is String && contentRaw.isNotEmpty) {
    try {
      final decoded = jsonDecode(contentRaw);
      if (decoded is Map<String, dynamic>) {
        final encrypted = decoded['t'] == 'encrypted';
        return (
          wasEncrypted: encrypted,
          routeToDecrypt: encrypted,
          b64: encrypted ? decoded['c'] as String? ?? '' : '',
          passthrough: decoded,
        );
      }
      if (decoded is String) {
        // JSON-encoded bare base64 string.
        return (
          wasEncrypted: true,
          routeToDecrypt: true,
          b64: decoded,
          passthrough: decoded,
        );
      }
      return (
        wasEncrypted: false,
        routeToDecrypt: true,
        b64: contentRaw,
        passthrough: contentRaw,
      );
    } catch (_) {
      // Not JSON — treat as raw base64 string.
      return (
        wasEncrypted: true,
        routeToDecrypt: true,
        b64: contentRaw,
        passthrough: contentRaw,
      );
    }
  }
  return (
    wasEncrypted: false,
    routeToDecrypt: false,
    b64: '',
    passthrough: contentRaw,
  );
}

/// Session-specific encryption management
class SessionEncryption {
  SessionEncryption({
    required String sessionId,
    required Encryptor encryptor,
    required Decryptor decryptor,
    required EncryptionCache cache,
  }) : _sessionId = sessionId,
       _encryptor = encryptor,
       _decryptor = decryptor,
       _cache = cache;
  final String _sessionId;
  final Encryptor _encryptor;
  final Decryptor _decryptor;
  final EncryptionCache _cache;

  /// Whether this session is backed by the AES-256-GCM decryptor. When
  /// `false`, the session fell back to legacy NaCl and may need a key
  /// refresh before it can decrypt newer AES envelopes.
  bool get canDecryptAes => _decryptor is AES256Encryption;

  /// Bounded envelope tag for the decrypt-failure counter.  Derived from
  /// the decryptor this session was opened with, not from the ciphertext.
  DecryptEnvelopeTag get _envelopeTag =>
      canDecryptAes ? kEnvelopeAes : kEnvelopeNacl;

  /// Batch decrypt messages
  Future<List<DecryptedMessage?>> decryptMessages(
    List<Map<String, dynamic>> messages,
  ) async {
    return (await _decryptMessagesPass(messages)).results;
  }

  /// Single classification + cache + decrypt pass over a page.
  ///
  /// Everything the caller isolate computes per row happens exactly once:
  /// content classification (which also yields the `wasEncrypted` flags
  /// consumed by [processDecryptedMessages]), the cache-key signature,
  /// and the base64 payload extraction for rows that need decryption —
  /// the previous pipeline computed all three twice per decrypted row.
  Future<({List<DecryptedMessage?> results, List<bool> wasEncrypted})>
      _decryptMessagesPass(List<Map<String, dynamic>> messages) async {
    final results = List<DecryptedMessage?>.filled(messages.length, null);
    final wasEncrypted = List<bool>.filled(messages.length, false);
    final toDecrypt =
        <({int index, Map<String, dynamic> message, String cacheKey,
            String b64})>[];

    // Failure counters are aggregated across the whole batch and emitted
    // once at the end.  A rotated key fails every message on a 500-message
    // page; one counter add per message would be a per-message attribute-map
    // allocation storm on the decrypt hot path.  The batch is the honest
    // granularity anyway — the failures share one cause.
    var freshFailures = 0;
    var cachedFailures = 0;

    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      if (message.isEmpty) {
        results[i] = null;
        continue;
      }

      final classified = _classifyContent(message['content']);
      wasEncrypted[i] = classified.wasEncrypted;

      // Check cache first
      final cacheKey = _messageCacheKey(message);
      if (cacheKey.isNotEmpty) {
        final cached = _cache.getCachedMessage(cacheKey);
        if (cached != null) {
          // A cached entry with null content is a *memoized* decrypt
          // failure: the page re-renders the same error bubble without
          // re-attempting crypto.  Counted separately so the dashboards
          // can tell a fresh outage from replayed damage.
          if (cached.content == null) cachedFailures++;
          results[i] = cached;
          continue;
        }
      }

      if (classified.routeToDecrypt) {
        toDecrypt.add((
          index: i,
          message: message,
          cacheKey: cacheKey,
          b64: classified.b64,
        ));
      } else {
        // Not encrypted — pass through the wire content so that
        // processDecryptedMessages can handle it normally instead
        // of silently dropping it (content: null + wasEncrypted=false
        // previously caused a silent skip).
        results[i] = DecryptedMessage(
          id: message['id'] as String? ?? '',
          seq: message['seq'] as int? ?? 0,
          localId: message['localId'] as String?,
          content: classified.passthrough,
          createdAt: _parseCreatedAt(message['createdAt']),
        );
        if (cacheKey.isNotEmpty) {
          _cache.setCachedMessage(cacheKey, results[i]!);
        }
      }
    }

    // Batch decrypt uncached messages
    if (toDecrypt.isNotEmpty) {
      List<dynamic> decrypted;

      // AES-256-GCM (pure Dart, no platform channels) runs in a
      // background isolate — now including the base64 decode and
      // version-byte strip, so the caller hands off raw ciphertext
      // strings only. NaCl/libsodium (FFI) stays on the main isolate
      // and decodes inline.
      if (_decryptor is AES256Encryption) {
        final encoded = <String>[for (final item in toDecrypt) item.b64];
        final result = await _decryptor.decryptEncodedInIsolate(encoded);
        decrypted = result.values;
        for (final idx in result.decodeFailures) {
          final failedB64 = toDecrypt[idx].b64;
          final codes = failedB64.codeUnits.take(10).toList();
          logger.warning(
            '[decryptMessages] base64 decode failed '
            'id=${toDecrypt[idx].message['id']} '
            'len=${failedB64.length} codes=$codes',
          );
        }
      } else {
        final encrypted = <Uint8List>[];
        for (final item in toDecrypt) {
          try {
            encrypted.add(Base64Utils.decode(item.b64, Encoding.base64));
          } on FormatException {
            final codes = item.b64.codeUnits.take(10).toList();
            logger.warning(
              '[decryptMessages] base64 decode failed '
              'id=${item.message['id']} '
              'len=${item.b64.length} codes=$codes',
            );
            encrypted.add(Uint8List(0));
          }
        }
        // Tag this NaCl batch with a session-scoped diagnostic key so
        // Sentry only captures one failure per (session, fingerprint)
        // when a stale key invalidates the whole fetch.
        decrypted = await CryptoSecretBox.withDiagnosticScope(
          'session:$_sessionId:messages',
          () => _decryptor.decrypt(encrypted),
        );
      }

      for (var i = 0; i < toDecrypt.length; i++) {
        final decryptedData = decrypted[i];
        final item = toDecrypt[i];

        if (decryptedData != null) {
          final result = DecryptedMessage(
            id: item.message['id'] as String? ?? '',
            seq: item.message['seq'] as int? ?? 0,
            localId: item.message['localId'] as String?,
            content: decryptedData,
            createdAt: _parseCreatedAt(item.message['createdAt']),
          );
          if (item.cacheKey.isNotEmpty) {
            _cache.setCachedMessage(item.cacheKey, result);
          }
          results[item.index] = result;
        } else {
          freshFailures++;
          final result = DecryptedMessage(
            id: item.message['id'] as String? ?? '',
            seq: item.message['seq'] as int? ?? 0,
            localId: item.message['localId'] as String?,
            content: null,
            createdAt: _parseCreatedAt(item.message['createdAt']),
          );
          if (item.cacheKey.isNotEmpty) {
            _cache.setCachedMessage(item.cacheKey, result);
          }
          results[item.index] = result;
        }
      }
    }

    // At most two counter adds per batch, regardless of page size.
    recordDecryptFailure(
      envelope: _envelopeTag,
      stage: kStageMessages,
      fromCache: false,
      count: freshFailures,
    );
    recordDecryptFailure(
      envelope: _envelopeTag,
      stage: kStageMessages,
      fromCache: true,
      count: cachedFailures,
    );

    return (results: results, wasEncrypted: wasEncrypted);
  }

  /// Decrypt messages **and** run message processing in a single
  /// isolate call, returning display-ready results.
  ///
  /// All heavy work (base64 decode, crypto, message type parsing)
  /// runs in the isolate.  The main thread only builds a
  /// lightweight descriptor list and receives the processed result.
  Future<ProcessedMessages> decryptAndProcessMessages(
    List<Map<String, dynamic>> messages,
    String sessionId,
  ) async {
    // One pass classifies every row and decrypts the encrypted ones;
    // the wasEncrypted flags come out of that same pass instead of the
    // separate full-page scan the pipeline used to run first.
    final pass = await _decryptMessagesPass(messages);

    final contentList = <dynamic>[
      for (final dm in pass.results) dm?.content,
    ];

    return processDecryptedMessagesWithIsolation(
      decryptedJsonList: contentList,
      wireMessages: messages,
      sessionId: sessionId,
      wasEncrypted: pass.wasEncrypted,
      useIsolate: _decryptor is AES256Encryption && messages.length >= 20,
    );
  }

  /// Single message convenience method
  Future<DecryptedMessage?> decryptMessage(
    Map<String, dynamic>? message,
  ) async {
    if (message == null || message.isEmpty) return null;
    final results = await decryptMessages([message]);
    return results[0];
  }

  /// Encrypt a small batch of payloads, off the UI isolate when the session
  /// is backed by the pure-Dart AES-256-GCM encryptor. The send path
  /// JSON-encodes and encrypts the full message payload here; without the
  /// isolate hop a large pasted log would block the frame that paints the
  /// optimistic bubble. NaCl (FFI) stays main-thread, matching decrypt.
  Future<List<Uint8List>> _encryptItems(List<dynamic> data) {
    final encryptor = _encryptor;
    if (encryptor is AES256Encryption) {
      return encryptor.encryptInIsolate(data);
    }
    return encryptor.encrypt(data);
  }

  /// Encrypt raw record
  Future<String> encryptRawRecord(Map<String, dynamic> record) async {
    final encrypted = await _encryptItems([record]);
    return Base64Utils.encode(encrypted[0], Encoding.base64);
  }

  /// Encrypt raw data
  Future<String> encryptRaw(dynamic data) async {
    final encrypted = await _encryptItems([data]);
    return Base64Utils.encode(encrypted[0], Encoding.base64);
  }

  /// Decrypt raw data
  Future<dynamic> decryptRaw(String encrypted) async {
    try {
      final encryptedData = Base64Utils.decode(encrypted, Encoding.base64);
      final decrypted = await CryptoSecretBox.withDiagnosticScope(
        'session:$_sessionId:raw',
        () => _decryptor.decrypt([encryptedData]),
      );
      return decrypted[0];
    } catch (e, stack) {
      // Recoverable: caller handles null as "no decrypted content".
      logger.warning(
        'SessionEncryption.decryptRaw failed session=$_sessionId',
        e,
        stack,
      );
      recordDecryptFailure(
        envelope: _envelopeTag,
        stage: kStageRaw,
        fromCache: false,
      );
      return null;
    }
  }

  /// Encrypt metadata
  Future<String> encryptMetadata(Map<String, dynamic> metadata) async {
    final encrypted = await _encryptItems([metadata]);
    return Base64Utils.encode(encrypted[0], Encoding.base64);
  }

  /// Decrypt metadata with caching
  Future<Map<String, dynamic>?> decryptMetadata(
    int version,
    String encrypted,
  ) async {
    // Check cache first
    final cached = _cache.getCachedMetadata(_sessionId, version);
    if (cached != null) {
      return cached;
    }

    // Decrypt
    Uint8List encryptedData;
    try {
      encryptedData = Base64Utils.decode(encrypted, Encoding.base64);
    } on FormatException catch (e) {
      logger.warning(
        'SessionEncryption.decryptMetadata base64 decode failed '
        'session=$_sessionId version=$version len=${encrypted.length}',
        e,
      );
      recordDecryptFailure(
        envelope: kEnvelopeUnknown,
        stage: kStageMetadata,
        fromCache: false,
      );
      return null;
    }
    final decrypted = await CryptoSecretBox.withDiagnosticScope(
      'session:$_sessionId:metadata',
      () => _decryptor.decrypt([encryptedData]),
    );
    if (decrypted[0] == null) {
      recordDecryptFailure(
        envelope: _envelopeTag,
        stage: kStageMetadata,
        fromCache: false,
      );
      return null;
    }

    final data = WireParsers.asMap(decrypted[0]);
    if (data == null) {
      recordDecryptFailure(
        envelope: _envelopeTag,
        stage: kStageMetadata,
        fromCache: false,
      );
      return null;
    }
    _cache.setCachedMetadata(_sessionId, version, data);
    return data;
  }

  /// Encrypt agent state
  Future<String> encryptAgentState(Map<String, dynamic> state) async {
    final encrypted = await _encryptItems([state]);
    return Base64Utils.encode(encrypted[0], Encoding.base64);
  }

  /// Decrypt agent state with caching
  Future<Map<String, dynamic>> decryptAgentState(
    int version,
    String? encrypted,
  ) async {
    if (encrypted == null || encrypted.isEmpty) {
      return {};
    }

    // Check cache first
    final cached = _cache.getCachedAgentState(_sessionId, version);
    if (cached != null) {
      return cached;
    }

    // Decrypt
    Uint8List encryptedData;
    try {
      encryptedData = Base64Utils.decode(encrypted, Encoding.base64);
    } on FormatException catch (e) {
      logger.warning(
        'SessionEncryption.decryptAgentState base64 decode failed '
        'session=$_sessionId version=$version len=${encrypted.length}',
        e,
      );
      recordDecryptFailure(
        envelope: kEnvelopeUnknown,
        stage: kStageAgentState,
        fromCache: false,
      );
      return {};
    }
    final decrypted = await CryptoSecretBox.withDiagnosticScope(
      'session:$_sessionId:agent-state',
      () => _decryptor.decrypt([encryptedData]),
    );
    if (decrypted[0] == null) {
      recordDecryptFailure(
        envelope: _envelopeTag,
        stage: kStageAgentState,
        fromCache: false,
      );
      return {};
    }

    final data = WireParsers.asMap(decrypted[0]);
    if (data == null) {
      recordDecryptFailure(
        envelope: _envelopeTag,
        stage: kStageAgentState,
        fromCache: false,
      );
      return {};
    }
    _cache.setCachedAgentState(_sessionId, version, data);
    return data;
  }

  DateTime _parseCreatedAt(dynamic raw) {
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return parsed;
      }
    }
    return DateTime.now();
  }
}
