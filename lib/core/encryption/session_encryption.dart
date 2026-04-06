import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:typed_data';


import '../services/logger_service.dart' show logger;
import '../utils/wire_parsers.dart';

import 'base64.dart';
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
      final cacheKey = _messageCacheKey(message);
      if (cacheKey.isNotEmpty) {
        final cached = _cache.getCachedMessage(cacheKey);
        if (cached != null) {
          results[i] = cached;
          continue;
        }
      }

      final contentRaw = message['content'];
      var content = contentRaw is Map<String, dynamic> ? contentRaw : null;
      // Fallback: if content is a JSON string, try decoding it
      if (content == null && contentRaw is String) {
        try {
          final decoded = jsonDecode(contentRaw);
          if (decoded is Map<String, dynamic>) {
            content = decoded;
          } else if (decoded is String) {
            // JSON-encoded bare base64 string — use decoded value
            content = {'t': 'encrypted', 'c': decoded};
          }
        } catch (_) {
          // Not valid JSON — handled below
        }
      }
      // New server format: content is the raw base64 encrypted string
      if (content == null && contentRaw is String && contentRaw.isNotEmpty) {
        content = {'t': 'encrypted', 'c': contentRaw};
      }
      if (content != null && content['t'] == 'encrypted') {
        toDecrypt.add((index: i, message: message));
      } else {
        // Not encrypted — pass through the wire content so that
        // processDecryptedMessages can handle it normally instead
        // of silently dropping it (content: null + wasEncrypted=false
        // previously caused a silent skip).
        results[i] = DecryptedMessage(
          id: message['id'] as String? ?? '',
          seq: message['seq'] as int? ?? 0,
          localId: message['localId'] as String?,
          content: content ?? contentRaw,
          createdAt: _parseCreatedAt(message['createdAt']),
        );
        if (cacheKey.isNotEmpty) {
          _cache.setCachedMessage(cacheKey, results[i]!);
        }
      }
    }

    // Batch decrypt uncached messages
    if (toDecrypt.isNotEmpty) {
      final encrypted = <Uint8List>[];
      for (final item in toDecrypt) {
        final b64 = _base64FromContent(item.message['content']);
        try {
          encrypted.add(Base64Utils.decode(b64, Encoding.base64));
        } on FormatException {
          final codes = b64.codeUnits.take(10).toList();
          logger.warning(
            '[decryptMessages] base64 decode failed '
            'id=${item.message['id']} '
            'len=${b64.length} codes=$codes',
          );
          encrypted.add(Uint8List(0));
        }
      }

      List<dynamic> decrypted;

      // AES-256-GCM (pure Dart, no platform channels) runs in a
      // background isolate. NaCl/libsodium (FFI) stays on the
      // main isolate.
      if (_decryptor is AES256Encryption) {
        decrypted = await _decryptor.decryptInIsolate(encrypted);
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
          final cacheKey = _messageCacheKey(item.message);
          if (cacheKey.isNotEmpty) {
            _cache.setCachedMessage(cacheKey, result);
          }
          results[item.index] = result;
        } else {
          final result = DecryptedMessage(
            id: item.message['id'] as String? ?? '',
            seq: item.message['seq'] as int? ?? 0,
            localId: item.message['localId'] as String?,
            content: null,
            createdAt: _parseCreatedAt(item.message['createdAt']),
          );
          final cacheKey = _messageCacheKey(item.message);
          if (cacheKey.isNotEmpty) {
            _cache.setCachedMessage(cacheKey, result);
          }
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
    // Single pass: decrypt messages and extract the wasEncrypted flag
    // in one go.  The previous implementation did two full passes over
    // the message list — one to build wireData, one inside
    // decryptMessages().  Now decryptMessages() is the only heavy pass.
    final wasEncryptedList = <bool>[];
    for (final msg in messages) {
      if (msg.isEmpty) {
        wasEncryptedList.add(false);
        continue;
      }
      final contentRaw = msg['content'];
      var isEncrypted = false;
      if (contentRaw is Map<String, dynamic>) {
        isEncrypted = contentRaw['t'] == 'encrypted';
      } else if (contentRaw is String && contentRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(contentRaw);
          isEncrypted = decoded is Map<String, dynamic> &&
              decoded['t'] == 'encrypted';
          if (!isEncrypted && decoded is String) {
            isEncrypted = true; // bare base64 string
          }
        } catch (_) {
          isEncrypted = true; // raw base64 string
        }
      }
      wasEncryptedList.add(isEncrypted);
    }

    final decryptedList = await decryptMessages(messages);
    final contentList = <dynamic>[];
    for (final dm in decryptedList) {
      contentList.add(dm?.content);
    }

    return processDecryptedMessages(
      decryptedJsonList: contentList,
      wireMessages: messages,
      sessionId: sessionId,
      wasEncrypted: wasEncryptedList,
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
    } catch (e, stack) {
      logger.error('SessionEncryption.decryptRaw failed', e, stack);
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

    final data = WireParsers.asMap(decrypted[0]);
    if (data == null) return null;
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

    final data = WireParsers.asMap(decrypted[0]);
    if (data == null) return {};
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
