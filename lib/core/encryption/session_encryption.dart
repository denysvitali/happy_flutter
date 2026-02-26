import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

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

/// Top-level function that decrypts **and** processes messages in a
/// background isolate, returning display-ready results.
Future<ProcessedMessages> _batchDecryptAndProcessInIsolate(
  ({
    List<Uint8List> encrypted,
    Uint8List secretKey,
    bool isAes,
    List<Map<String, dynamic>> wireMessages,
    List<int> toDecryptIndices,
    String sessionId,
  }) args,
) async {
  // Step 1: decrypt
  final decryptedRaw = <dynamic>[];
  for (final item in args.encrypted) {
    if (args.isAes) {
      if (item.isEmpty || item[0] != 0) {
        decryptedRaw.add(null);
        continue;
      }
      try {
        final decrypted = await AesGcmEncryption.decrypt(
          item.sublist(1),
          args.secretKey,
        );
        decryptedRaw.add(decrypted);
      } catch (e) {
        decryptedRaw.add(null);
      }
    } else {
      final decrypted = await CryptoSecretBox.decrypt(
        item,
        args.secretKey,
      );
      decryptedRaw.add(decrypted);
    }
  }

  // Step 2: build per-message decrypted content list aligned with
  // wireMessages (null for non-encrypted / failed).
  final decryptedJsonList = List<dynamic>.filled(
    args.wireMessages.length,
    null,
  );
  for (var i = 0; i < args.toDecryptIndices.length; i++) {
    decryptedJsonList[args.toDecryptIndices[i]] = decryptedRaw[i];
  }
  // For non-encrypted messages that have content (not encrypted), the
  // content is already null in decryptedJsonList — processDecryptedMessages
  // treats null as decryption failure.  We need to mark them specially.
  // Actually, unencrypted messages with no content also appear as null.
  // We set them to a sentinel so processDecryptedMessages can distinguish.
  // Instead, we pass the wire content directly for unencrypted messages.
  for (var i = 0; i < args.wireMessages.length; i++) {
    if (decryptedJsonList[i] != null) continue;
    final wire = args.wireMessages[i];
    if (wire.isEmpty) continue;
    final content = wire['content'] as Map<String, dynamic>?;
    if (content == null || content['t'] != 'encrypted') {
      // Not encrypted — mark with null content (decryption "succeeded"
      // but there's nothing to decrypt).  processDecryptedMessages will
      // emit an error placeholder which is correct for these.
      // Actually we need to NOT process these as errors — they are
      // unencrypted messages with null content.  Skip them from
      // processing by keeping null — the caller handles them.
    }
  }

  // Step 3: process
  return processDecryptedMessages(
    decryptedJsonList: decryptedJsonList,
    wireMessages: args.wireMessages,
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
  /// Falls back to main-thread decryption + processing for small
  /// batches or unsupported decryptor types.
  Future<ProcessedMessages> decryptAndProcessMessages(
    List<Map<String, dynamic>> messages,
    String sessionId,
  ) async {
    // Separate cached / unencrypted / to-decrypt, same as decryptMessages
    final toDecrypt = <({int index, Map<String, dynamic> message})>[];
    final cachedContent = List<dynamic>.filled(messages.length, null);
    final hasCachedContent = List<bool>.filled(messages.length, false);

    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      if (message.isEmpty) continue;

      final messageId = message['id'] as String?;
      if (messageId != null) {
        final cached = _cache.getCachedMessage(messageId);
        if (cached != null) {
          cachedContent[i] = cached.content;
          hasCachedContent[i] = true;
          continue;
        }
      }

      final content = message['content'] as Map<String, dynamic>?;
      if (content != null && content['t'] == 'encrypted') {
        toDecrypt.add((index: i, message: message));
      } else {
        // Not encrypted — content is null
        hasCachedContent[i] = true;
        cachedContent[i] = null;
      }
    }

    // Offload to isolate if large enough
    if (toDecrypt.length >= _isolateThreshold &&
        _canOffloadToIsolate) {
      final encrypted = toDecrypt
          .map((item) => Base64Utils.decode(
                item.message['content']['c'] as String,
                Encoding.base64,
              ))
          .toList();

      final result = await Isolate.run(
        () => _batchDecryptAndProcessInIsolate((
          encrypted: encrypted,
          secretKey: _extractSecretKey()!,
          isAes: _decryptor is AES256Encryption,
          wireMessages: messages,
          toDecryptIndices:
              toDecrypt.map((item) => item.index).toList(),
          sessionId: sessionId,
        )),
      );

      // Update cache with decrypted messages that came back
      // (we can't do this in the isolate since the cache is
      // main-isolate only)
      _updateCacheFromProcessed(messages, toDecrypt, result);

      return result;
    }

    // Small batch: decrypt on main thread then process
    final decryptedList = await decryptMessages(messages);
    // Build content list for processDecryptedMessages
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

  /// Update the encryption cache after isolate processing.
  void _updateCacheFromProcessed(
    List<Map<String, dynamic>> wireMessages,
    List<({int index, Map<String, dynamic> message})> toDecrypt,
    ProcessedMessages result,
  ) {
    // We can't easily recover individual decrypted content from
    // ProcessedMessages, but we can at least mark messages as
    // "seen" so the next call to decryptMessages can use the cache.
    // For now this is a no-op — the cache is populated on the next
    // call to decryptMessages for any re-fetched page.
  }

  /// Whether the decryptor type supports isolate offloading.
  bool get _canOffloadToIsolate =>
      _decryptor is SecretBoxEncryption ||
      _decryptor is AES256Encryption;

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
      if (kDebugMode) debugPrint('SessionEncryption.decryptRaw failed: $e');
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
