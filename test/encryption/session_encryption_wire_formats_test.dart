// Tests for the 4 content wire format variants that
// SessionEncryption.decryptMessages must handle.
//
// The private _base64FromContent() function in session_encryption.dart
// supports:
//   1. Map wrapper         — {'t': 'encrypted', 'c': '<base64>'}
//   2. JSON-encoded map    — '{"t":"encrypted","c":"<base64>"}'
//   3. JSON-encoded string — '"<base64>"'
//   4. Raw base64 string   — '<base64>'
//
// All four reach the same decrypt path; these tests verify end-to-end
// correctness through the public API.

import 'dart:convert' show jsonEncode;
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/aes_gcm.dart';
import 'package:happy_flutter/core/encryption/base64.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Uint8List _generateKey() {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(32, (_) => random.nextInt(256)),
  );
}

/// Encrypts [payload] with [enc] and returns the raw base64 ciphertext string
/// (the value that goes into the `'c'` field, or is used directly as the
/// content for the newer wire formats).
Future<String> _encryptToBase64(
  AES256Encryption enc,
  Map<String, dynamic> payload,
) async {
  final encrypted = await enc.encrypt([payload]);
  return Base64Utils.encode(encrypted[0], Encoding.base64);
}

SessionEncryption _makeSessionEncryption(AES256Encryption enc) {
  return SessionEncryption(
    sessionId: 'test-session',
    encryptor: enc,
    decryptor: enc,
    cache: EncryptionCache(),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Content wire format variants', () {
    test('map wrapper format decrypts correctly', () async {
      final key = _generateKey();
      final enc = AES256Encryption(key);
      final se = _makeSessionEncryption(enc);

      final payload = {'role': 'user', 'text': 'map wrapper'};
      final b64 = await _encryptToBase64(enc, payload);

      final message = <String, dynamic>{
        'id': 'msg-map',
        'seq': 1,
        'createdAt': 1700000000000,
        'content': {'t': 'encrypted', 'c': b64},
      };

      final result = await se.decryptMessage(message);

      expect(result, isNotNull);
      expect(result!.id, equals('msg-map'));
      final content = result.content as Map<String, dynamic>?;
      expect(content, isNotNull);
      expect(content!['role'], equals('user'));
      expect(content['text'], equals('map wrapper'));
    });

    test('JSON-encoded map string format decrypts correctly', () async {
      final key = _generateKey();
      final enc = AES256Encryption(key);
      final se = _makeSessionEncryption(enc);

      final payload = {'role': 'assistant', 'text': 'json-encoded map'};
      final b64 = await _encryptToBase64(enc, payload);

      // Server JSON-encodes the content map into a string.
      final contentString = jsonEncode({'t': 'encrypted', 'c': b64});

      final message = <String, dynamic>{
        'id': 'msg-json-map',
        'seq': 2,
        'createdAt': 1700000000000,
        'content': contentString,
      };

      final result = await se.decryptMessage(message);

      expect(result, isNotNull);
      expect(result!.id, equals('msg-json-map'));
      final content = result.content as Map<String, dynamic>?;
      expect(content, isNotNull);
      expect(content!['role'], equals('assistant'));
      expect(content['text'], equals('json-encoded map'));
    });

    test('JSON-encoded bare base64 string format decrypts correctly', () async {
      final key = _generateKey();
      final enc = AES256Encryption(key);
      final se = _makeSessionEncryption(enc);

      final payload = {'role': 'user', 'text': 'json-encoded bare b64'};
      final b64 = await _encryptToBase64(enc, payload);

      // Server JSON-encodes the base64 string itself: produces '"<base64>"'.
      final contentString = jsonEncode(b64);

      final message = <String, dynamic>{
        'id': 'msg-json-b64',
        'seq': 3,
        'createdAt': 1700000000000,
        'content': contentString,
      };

      final result = await se.decryptMessage(message);

      expect(result, isNotNull);
      expect(result!.id, equals('msg-json-b64'));
      final content = result.content as Map<String, dynamic>?;
      expect(content, isNotNull);
      expect(content!['role'], equals('user'));
      expect(content['text'], equals('json-encoded bare b64'));
    });

    test('raw base64 string format decrypts correctly', () async {
      final key = _generateKey();
      final enc = AES256Encryption(key);
      final se = _makeSessionEncryption(enc);

      final payload = {'role': 'assistant', 'text': 'raw base64'};
      final b64 = await _encryptToBase64(enc, payload);

      // New server format: content is the plain base64 string directly.
      final message = <String, dynamic>{
        'id': 'msg-raw-b64',
        'seq': 4,
        'createdAt': 1700000000000,
        'content': b64,
      };

      final result = await se.decryptMessage(message);

      expect(result, isNotNull);
      expect(result!.id, equals('msg-raw-b64'));
      final content = result.content as Map<String, dynamic>?;
      expect(content, isNotNull);
      expect(content!['role'], equals('assistant'));
      expect(content['text'], equals('raw base64'));
    });

    test('batch with mixed content formats all decrypt correctly', () async {
      final key = _generateKey();
      final enc = AES256Encryption(key);
      final se = _makeSessionEncryption(enc);

      final payloads = [
        {'format': 'map-wrapper', 'index': 0},
        {'format': 'json-map', 'index': 1},
        {'format': 'json-b64', 'index': 2},
        {'format': 'raw-b64', 'index': 3},
      ];

      final b64s = await Future.wait(
        payloads.map((p) => _encryptToBase64(enc, p)),
      );

      final messages = <Map<String, dynamic>>[
        // Format 1: map wrapper
        {
          'id': 'mix-0',
          'seq': 0,
          'createdAt': 1700000000000,
          'content': {'t': 'encrypted', 'c': b64s[0]},
        },
        // Format 2: JSON-encoded map string
        {
          'id': 'mix-1',
          'seq': 1,
          'createdAt': 1700000000000,
          'content': jsonEncode({'t': 'encrypted', 'c': b64s[1]}),
        },
        // Format 3: JSON-encoded bare base64
        {
          'id': 'mix-2',
          'seq': 2,
          'createdAt': 1700000000000,
          'content': jsonEncode(b64s[2]),
        },
        // Format 4: raw base64
        {
          'id': 'mix-3',
          'seq': 3,
          'createdAt': 1700000000000,
          'content': b64s[3],
        },
      ];

      final results = await se.decryptMessages(messages);

      expect(results.length, equals(4));

      for (var i = 0; i < 4; i++) {
        expect(
          results[i],
          isNotNull,
          reason: 'message at index $i was null',
        );
        expect(results[i]!.id, equals('mix-$i'));

        final content = results[i]!.content as Map<String, dynamic>?;
        expect(
          content,
          isNotNull,
          reason: 'content at index $i was null',
        );
        expect(
          content!['format'],
          equals(payloads[i]['format']),
          reason:
              'format mismatch at index $i: '
              'expected "${payloads[i]['format']}" '
              'got "${content['format']}"',
        );
        expect(content['index'], equals(i));
      }
    });

    test(
      'non-encrypted content returns DecryptedMessage with null content',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final se = _makeSessionEncryption(enc);

        // Content has a different type tag — not 'encrypted'.
        final message = <String, dynamic>{
          'id': 'msg-plaintext',
          'seq': 10,
          'createdAt': 1700000000000,
          'content': {'t': 'plaintext', 'data': 'hello'},
        };

        final result = await se.decryptMessage(message);

        expect(result, isNotNull);
        expect(result!.id, equals('msg-plaintext'));
        expect(result.seq, equals(10));
        expect(result.content, isNull);
      },
    );

    test(
      'null content returns DecryptedMessage with null content',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final se = _makeSessionEncryption(enc);

        // No 'content' key at all — defaults to null.
        final message = <String, dynamic>{
          'id': 'msg-no-content',
          'seq': 11,
          'createdAt': 1700000000000,
        };

        final result = await se.decryptMessage(message);

        expect(result, isNotNull);
        expect(result!.id, equals('msg-no-content'));
        expect(result.seq, equals(11));
        expect(result.content, isNull);
      },
    );
  });
}
