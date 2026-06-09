import 'dart:convert';
import 'dart:typed_data';

import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
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
/// without real encryption, but properly runs the full message
/// processing pipeline of the real [SessionEncryption] base class
/// (cache, batch decrypt, processDecryptedMessages).
class FakeSessionEncryption extends SessionEncryption {
  FakeSessionEncryption({required super.sessionId})
      : super(
          encryptor: FakeEncryptor(),
          decryptor: FakeEncryptor(),
          cache: EncryptionCache(),
        );
}
