import 'dart:convert';
import 'dart:typed_data';

import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';

/// A fake encryptor/decryptor for E2E tests that stores and retrieves
/// plaintext without actual encryption.
///
/// Uses a simple format: [version byte (0x01)] + utf8 JSON of the content
///
/// This allows tests to verify the full message processing pipeline without
/// dealing with real crypto operations.
class FakeEncryptor implements Encryptor {
  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    final results = <Uint8List>[];
    for (final item in data) {
      final json = jsonEncode(item);
      final bytes = utf8.encode(json);
      // Prepend version byte
      final output = Uint8List(bytes.length + 1);
      output[0] = 0x01;
      output.setRange(1, output.length, bytes);
      results.add(output);
    }
    return results;
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    final results = <dynamic>[];
    for (final item in data) {
      if (item.isEmpty) {
        results.add(null);
        continue;
      }
      try {
        final version = item[0];
        if (version == 0x01) {
          // Our fake format
          final json = utf8.decode(item.sublist(1));
          results.add(jsonDecode(json));
        } else {
          // Unknown version - try raw decode
          results.add(utf8.decode(item));
        }
      } catch (e) {
        results.add(null);
      }
    }
    return results;
  }
}

/// A session encryption for E2E tests that passes plaintext through
/// without real encryption, but properly runs the full message processing.
class FakeSessionEncryption extends SessionEncryption {
  FakeSessionEncryption({required String sessionId})
      : super(
          sessionId: sessionId,
          encryptor: FakeEncryptor(),
          decryptor: FakeEncryptor(),
          cache: EncryptionCache(),
        );

  /// Override decryptAndProcessMessages to bypass isolate and run
  /// processing directly in-process with our fake encryptor.
  @override
  Future<ProcessedMessages> decryptAndProcessMessages(
    List<Map<String, dynamic>> messages,
    String sessionId,
  ) async {
    // Use the same logic as the parent but without isolate.
    // This is a simplified copy that uses FakeEncryptor directly.
    final toDecrypt = <({int index, Map<String, dynamic> message})>[];
    final results = <DecryptedMessage?>[];
    final wireData = <_IsolateWireMessage>[];

    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];
      if (msg.isEmpty) {
        results.add(null);
        wireData.add(const _IsolateWireMessage(id: '', seq: 0, createdAt: 0));
        continue;
      }

      final messageId = msg['id'] as String? ?? '';
      final seq = msg['seq'] as int? ?? 0;
      final localId = msg['localId'] as String?;
      final createdAt = msg['createdAt'];
      final contentRaw = msg['content'];
      var content =
          contentRaw is Map<String, dynamic> ? contentRaw : null;
      if (content == null && contentRaw is String) {
        try {
          final decoded = jsonDecode(contentRaw);
          if (decoded is Map<String, dynamic>) {
            content = decoded;
          }
        } catch (_) {}
      }
      if (content == null && contentRaw is String && contentRaw.isNotEmpty) {
        content = {'t': 'encrypted', 'c': contentRaw};
      }
      final isEncrypted =
          content != null && content['t'] == 'encrypted';

      if (isEncrypted) {
        toDecrypt.add((index: i, message: msg));
        wireData.add(_IsolateWireMessage(
          id: messageId,
          seq: seq,
          localId: localId,
          createdAt: createdAt,
          base64Content: content!['c'] as String?,
          isEncrypted: true,
        ));
      } else {
        results.add(DecryptedMessage(
          id: messageId,
          seq: seq,
          localId: localId,
          content: null,
          createdAt: _parseCreatedAt(createdAt),
        ));
        wireData.add(_IsolateWireMessage(
          id: messageId,
          seq: seq,
          localId: localId,
          createdAt: createdAt,
          isEncrypted: false,
        ));
      }
    }

    // Batch decrypt with fake encryptor
    if (toDecrypt.isNotEmpty) {
      final fake = FakeEncryptor();
      final toDecryptData = <dynamic>[];
      for (final item in toDecrypt) {
        // The 'c' field is base64 of encrypted content.
        // For our fake encryptor, we need to reverse: decode base64,
        // strip version byte, get JSON string, parse to dynamic.
        final b64 = item.message['content']['c'] as String;
        try {
          final decoded = base64Decode(b64);
          // FakeEncryptor format: [0x01] + utf8(json)
          if (decoded.isNotEmpty && decoded[0] == 0x01) {
            final json = utf8.decode(decoded.sublist(1));
            toDecryptData.add(jsonDecode(json));
          } else {
            toDecryptData.add(utf8.decode(decoded));
          }
        } catch (_) {
          toDecryptData.add(null);
        }
      }

      final decrypted = await fake.decrypt(
        toDecryptData.map((d) {
          final json = jsonEncode(d);
          final bytes = utf8.encode(json);
          final output = Uint8List(bytes.length + 1);
          output[0] = 0x01;
          output.setRange(1, output.length, bytes);
          return output;
        }).toList(),
      );

      var di = 0;
      for (var i = 0; i < messages.length; i++) {
        if (results[i] != null) continue;
        results.add(DecryptedMessage(
          id: messages[i]['id'] as String? ?? '',
          seq: messages[i]['seq'] as int? ?? 0,
          localId: messages[i]['localId'] as String?,
          content: di < decrypted.length ? decrypted[di] : null,
          createdAt: _parseCreatedAt(messages[i]['createdAt']),
        ));
        di++;
      }
    }

    final contentList = results.map((dm) => dm?.content).toList();
    final wasEncryptedList = wireData.map((w) => w.isEncrypted).toList();

    return processDecryptedMessages(
      decryptedJsonList: contentList,
      wireMessages: messages,
      sessionId: sessionId,
      wasEncrypted: wasEncryptedList,
    );
  }

  static int _parseCreatedAt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed.millisecondsSinceEpoch;
    }
    return DateTime.now().millisecondsSinceEpoch;
  }
}

/// Encryption interface for test double injection.
abstract class TestEncryption {
  SessionEncryption? getSessionEncryption(String sessionId);
}
