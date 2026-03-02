import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../services/logger_service.dart' show logger;

import 'aes_gcm.dart';
import 'base64.dart';
import 'crypto_secret_box.dart';
import 'encryption_cache.dart';
import 'encryptor.dart';
import 'message_processor.dart';

/// Top-level function for batch decryption in a background isolate.
///
/// Must be top-level (not a closure or instance method) so it can be
/// passed to [Isolate.run].
Future<List<dynamic>> _batchDecryptInIsolate(
  ({
    List<Uint8List> encrypted,
    Uint8List secretKey,
    bool isAes,
  }) args,
) async {
  final results = <dynamic>[];
  for (final item in args.encrypted) {
    if (args.isAes) {
      // AES256Encryption format: version byte + encrypted payload
      if (item.isEmpty || item[0] != 0) {
        results.add(null);
        continue;
      }
      try {
        final decrypted = await AesGcmEncryption.decrypt(
          item.sublist(1),
          args.secretKey,
        );
        results.add(decrypted);
      } catch (e) {
        results.add(null);
      }
    } else {
      // NaCl SecretBox decryption
      final decrypted = await CryptoSecretBox.decrypt(
        item,
        args.secretKey,
      );
      results.add(decrypted);
    }
  }
  return results;
}

/// Lightweight wire data sent to the isolate.
/// Only the fields needed for decrypt + process — NOT the full API maps.
class _IsolateWireMessage {
  const _IsolateWireMessage({
    required this.id,
    required this.seq,
    required this.createdAt,
    this.localId,
    this.base64Content,
    this.isEncrypted = false,
  });

  final String id;
  final int seq;
  final dynamic createdAt;
  final String? localId;

  /// Base64-encoded encrypted payload (content.c), or null if not
  /// encrypted.
  final String? base64Content;
  final bool isEncrypted;
}

/// Top-level function that does base64 decode + decrypt + process
/// entirely inside a background isolate.
///
/// Receives only minimal wire data (not the full API response maps)
/// to minimise isolate serialization overhead.
Future<ProcessedMessages> _batchDecryptAndProcessInIsolate(
  ({
    List<_IsolateWireMessage> wireData,
    Uint8List secretKey,
    bool isAes,
    String sessionId,
  }) args,
) async {
  final decryptedJsonList = List<dynamic>.filled(
    args.wireData.length,
    null,
  );

  // Decrypt every encrypted message (base64 decode + crypto).
  for (var i = 0; i < args.wireData.length; i++) {
    final wire = args.wireData[i];
    if (!wire.isEncrypted || wire.base64Content == null) continue;

    final encrypted = Base64Utils.decode(
      wire.base64Content!,
      Encoding.base64,
    );

    if (args.isAes) {
      if (encrypted.isEmpty || encrypted[0] != 0) continue;
      try {
        decryptedJsonList[i] = await AesGcmEncryption.decrypt(
          encrypted.sublist(1),
          args.secretKey,
        );
      } catch (_) {
        // leave null — will show as decryption error
      }
    } else {
      decryptedJsonList[i] = await CryptoSecretBox.decrypt(
        encrypted,
        args.secretKey,
      );
    }
  }

  // Rebuild minimal wireMessages maps for processDecryptedMessages.
  final wireMessages = <Map<String, dynamic>>[];
  for (final w in args.wireData) {
    wireMessages.add({
      'id': w.id,
      'seq': w.seq,
      'localId': w.localId,
      'createdAt': w.createdAt,
    });
  }

  return processDecryptedMessages(
    decryptedJsonList: decryptedJsonList,
    wireMessages: wireMessages,
    sessionId: args.sessionId,
  );
}

/// Session-specific encryption management
class SessionEncryption {

  SessionEncryption({
    required String sessionId,
    required Encryptor encryptor,
    required Decryptor decryptor,
    required EncryptionCache cache,
  })  : _sessionId = sessionId,
        _encryptor = encryptor,
        _decryptor = decryptor,
        _cache = cache;
  final String _sessionId;
  final Encryptor _encryptor;
  final Decryptor _decryptor;
  final EncryptionCache _cache;

  /// Minimum batch size to justify isolate overhead.
  static const int _isolateThreshold = 5;

  /// Batch decrypt messages
  Future<List<DecryptedMessage?>> decryptMessages(
    List<Map<String, dynamic>> messages,
  ) async {
    final results = List<DecryptedMessage?>.filled(messages.length, null);
    final toDecrypt = <({int index, Map<String, dynamic> message})>[];

    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      if (message.isEmpty) {
        results[i] = null;
        continue;
      }

      // Check cache first
      final messageId = message['id'] as String?;
      if (messageId != null) {
        final cached = _cache.getCachedMessage(messageId);
        if (cached != null) {
          results[i] = cached;
          continue;
        }
      }

      final content = message['content'] as Map<String, dynamic>?;
      if (content != null && content['t'] == 'encrypted') {
        toDecrypt.add((index: i, message: message));
      } else {
        // Not encrypted or invalid
        results[i] = DecryptedMessage(
          id: message['id'] as String? ?? '',
          seq: message['seq'] as int? ?? 0,
          localId: message['localId'] as String?,
          content: null,
          createdAt: _parseCreatedAt(message['createdAt']),
        );
        if (messageId != null) {
          _cache.setCachedMessage(messageId, results[i]!);
        }
      }
    }

    // Batch decrypt uncached messages
    if (toDecrypt.isNotEmpty) {
      final encrypted = toDecrypt
          .map((item) => Base64Utils.decode(
                item.message['content']['c'] as String,
                Encoding.base64,
              ))
          .toList();

      List<dynamic> decrypted;

      // Offload to background isolate if batch is large enough
      if (toDecrypt.length >= _isolateThreshold &&
          _canOffloadToIsolate) {
        decrypted = await Isolate.run(
          () => _batchDecryptInIsolate((
            encrypted: encrypted,
            secretKey: _extractSecretKey()!,
            isAes: _decryptor is AES256Encryption,
          )),
        );
      } else {
        decrypted = await _decryptor.decrypt(encrypted);
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
          _cache.setCachedMessage(result.id, result);
          results[item.index] = result;
        } else {
          final result = DecryptedMessage(
            id: item.message['id'] as String? ?? '',
            seq: item.message['seq'] as int? ?? 0,
            localId: item.message['localId'] as String?,
            content: null,
            createdAt: _parseCreatedAt(item.message['createdAt']),
          );
          _cache.setCachedMessage(result.id, result);
          results[item.index] = result;
        }
      }
    }

    return results;
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
    // Build lightweight wire data — extract only the fields the
    // isolate needs.  This keeps isolate-boundary serialisation
    // small (ids + seq + base64 string) instead of copying the
    // entire API response maps.
    var toDecryptCount = 0;
    var cachedCount = 0;
    final wireData = <_IsolateWireMessage>[];
    final cachedContent = List<dynamic>.filled(messages.length, null);
    final hasCached = List<bool>.filled(messages.length, false);

    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];
      if (msg.isEmpty) {
        wireData.add(const _IsolateWireMessage(
          id: '',
          seq: 0,
          createdAt: 0,
        ));
        continue;
      }

      final messageId = msg['id'] as String? ?? '';
      final seq = msg['seq'] as int? ?? 0;
      final localId = msg['localId'] as String?;
      final createdAt = msg['createdAt'];
      final content = msg['content'] as Map<String, dynamic>?;
      final isEncrypted =
          content != null && content['t'] == 'encrypted';

      // Check cache
      if (messageId.isNotEmpty) {
        final cached = _cache.getCachedMessage(messageId);
        if (cached != null) {
          cachedContent[i] = cached.content;
          hasCached[i] = true;
          cachedCount++;
          wireData.add(_IsolateWireMessage(
            id: messageId,
            seq: seq,
            localId: localId,
            createdAt: createdAt,
          ));
          continue;
        }
      }

      if (isEncrypted) {
        toDecryptCount++;
      }

      wireData.add(_IsolateWireMessage(
        id: messageId,
        seq: seq,
        localId: localId,
        createdAt: createdAt,
        base64Content:
            isEncrypted ? content['c'] as String? : null,
        isEncrypted: isEncrypted,
      ));
    }

    logger.info(
      '[fetchMessages] session=$sessionId '
      'total=${messages.length} '
      'toDecrypt=$toDecryptCount '
      'cached=$cachedCount',
    );

    // Offload to isolate if enough messages need decryption
    if (toDecryptCount >= _isolateThreshold &&
        _canOffloadToIsolate) {
      final result = await Isolate.run(
        () => _batchDecryptAndProcessInIsolate((
          wireData: wireData,
          secretKey: _extractSecretKey()!,
          isAes: _decryptor is AES256Encryption,
          sessionId: sessionId,
        )),
      );

      return result;
    }

    // Small batch / unsupported decryptor: main-thread path
    final decryptedList = await decryptMessages(messages);
    final contentList = <dynamic>[];
    for (final dm in decryptedList) {
      contentList.add(dm?.content);
    }

    return processDecryptedMessages(
      decryptedJsonList: contentList,
      wireMessages: messages,
      sessionId: sessionId,
    );
  }

  /// Whether the decryptor type supports isolate offloading.
  bool get _canOffloadToIsolate =>
      !kIsWeb &&
      (_decryptor is SecretBoxEncryption ||
          _decryptor is AES256Encryption);

  /// Extract the secret key from known decryptor types.
  Uint8List? _extractSecretKey() {
    final dec = _decryptor;
    if (dec is SecretBoxEncryption) return dec.secretKey;
    if (dec is AES256Encryption) return dec.secretKey;
    return null;
  }

  /// Single message convenience method
  Future<DecryptedMessage?> decryptMessage(
    Map<String, dynamic>? message,
  ) async {
    if (message == null || message.isEmpty) return null;
    final results = await decryptMessages([message]);
    return results[0];
  }

  /// Encrypt raw record
  Future<String> encryptRawRecord(Map<String, dynamic> record) async {
    final encrypted = await _encryptor.encrypt([record]);
    return Base64Utils.encode(encrypted[0], Encoding.base64);
  }

  /// Encrypt raw data
  Future<String> encryptRaw(dynamic data) async {
    final encrypted = await _encryptor.encrypt([data]);
    return Base64Utils.encode(encrypted[0], Encoding.base64);
  }

  /// Decrypt raw data
  Future<dynamic> decryptRaw(String encrypted) async {
    try {
      final encryptedData = Base64Utils.decode(encrypted, Encoding.base64);
      final decrypted = await _decryptor.decrypt([encryptedData]);
      return decrypted[0];
    } catch (e) {
      logger.warning('SessionEncryption.decryptRaw failed', e);
      return null;
    }
  }

  /// Encrypt metadata
  Future<String> encryptMetadata(Map<String, dynamic> metadata) async {
    final encrypted = await _encryptor.encrypt([metadata]);
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
    final encryptedData = Base64Utils.decode(encrypted, Encoding.base64);
    final decrypted = await _decryptor.decrypt([encryptedData]);
    if (decrypted[0] == null) {
      return null;
    }

    final data = decrypted[0] as Map<String, dynamic>;
    _cache.setCachedMetadata(_sessionId, version, data);
    return data;
  }

  /// Encrypt agent state
  Future<String> encryptAgentState(Map<String, dynamic> state) async {
    final encrypted = await _encryptor.encrypt([state]);
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
    final encryptedData = Base64Utils.decode(encrypted, Encoding.base64);
    final decrypted = await _decryptor.decrypt([encryptedData]);
    if (decrypted[0] == null) {
      return {};
    }

    final data = decrypted[0] as Map<String, dynamic>;
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
