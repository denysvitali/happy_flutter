// Tests for decryption error resilience at the SessionEncryption layer.
//
// Bug context: the Isolate.run() regression (commit 6fbe95e) caused ALL
// items in a batch to silently return null on Android.  These tests guard
// the orthogonal failure mode: a *single* bad wire message (corrupted
// ciphertext, invalid base64, empty content, missing version byte, or
// non-encrypted format) must not poison the rest of the batch.  Good
// items must still decrypt correctly; only the bad item should be
// degraded to null content.

import 'dart:convert';
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

/// Builds a well-formed wire-format message with AES-256-GCM content.
///
/// Shape expected by [SessionEncryption.decryptMessages]:
///   { 'id', 'seq', 'content': {'t': 'encrypted', 'c': <base64>},
///     'createdAt' }
Future<Map<String, dynamic>> _encryptedWireMessage(
  AES256Encryption encryptor,
  String id,
  int seq,
  Map<String, dynamic> content,
) async {
  final encrypted = await encryptor.encrypt([content]);
  final b64 = Base64Utils.encode(encrypted[0], Encoding.base64);
  return {
    'id': id,
    'seq': seq,
    'content': {'t': 'encrypted', 'c': b64},
    'createdAt': 1700000000000,
  };
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
  group('SessionEncryption.decryptMessages — error resilience', () {
    test(
      'corrupted ciphertext in middle of batch does not affect other '
      'messages',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final se = _makeSessionEncryption(enc);

        // Build 5 valid encrypted messages.
        final messages = await Future.wait([
          for (var i = 0; i < 5; i++)
            _encryptedWireMessage(
              enc,
              'msg-$i',
              i,
              {'index': i, 'text': 'hello $i'},
            ),
        ]);

        // Corrupt message at index 2: replace its base64 ciphertext with
        // valid-format base64 that decodes to garbage (wrong key / auth tag
        // will fail GCM verification).  'AAAA' decodes to 3 zero bytes —
        // far too short for a valid AES-GCM payload (needs ≥28 bytes), so
        // AES256Encryption.decrypt returns null for that item only.
        final corrupt = Map<String, dynamic>.from(messages[2]);
        corrupt['content'] = {'t': 'encrypted', 'c': 'AAAA'};
        messages[2] = corrupt;

        final results = await se.decryptMessages(messages);

        expect(results.length, equals(5));

        for (var i = 0; i < 5; i++) {
          if (i == 2) {
            // Bad item: DecryptedMessage is returned but content is null.
            expect(
              results[i],
              isNotNull,
              reason: 'index 2 should produce a DecryptedMessage, not null',
            );
            expect(
              results[i]!.content,
              isNull,
              reason: 'corrupted item at index 2 must have null content',
            );
          } else {
            expect(
              results[i],
              isNotNull,
              reason: 'valid message at index $i was unexpectedly dropped',
            );
            final content =
                results[i]!.content as Map<String, dynamic>?;
            expect(
              content,
              isNotNull,
              reason: 'content at index $i must not be null',
            );
            expect(content!['index'], equals(i));
            expect(content['text'], equals('hello $i'));
          }
        }
      },
    );

    test(
      'invalid base64 in one message does not crash batch',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final se = _makeSessionEncryption(enc);

        final messages = await Future.wait([
          for (var i = 0; i < 5; i++)
            _encryptedWireMessage(
              enc,
              'b64-$i',
              i,
              {'seq': i, 'payload': 'data-$i'},
            ),
        ]);

        // Replace message 3 with completely invalid base64.
        final corrupt = Map<String, dynamic>.from(messages[3]);
        corrupt['content'] = {'t': 'encrypted', 'c': 'not-valid-base64!!!'};
        messages[3] = corrupt;

        final results = await se.decryptMessages(messages);

        expect(results.length, equals(5));

        for (var i = 0; i < 5; i++) {
          if (i == 3) {
            expect(
              results[i],
              isNotNull,
              reason: 'index 3 should produce a DecryptedMessage, not null',
            );
            expect(
              results[i]!.content,
              isNull,
              reason: 'invalid-base64 item at index 3 must have null content',
            );
          } else {
            expect(
              results[i],
              isNotNull,
              reason: 'valid message at index $i was dropped',
            );
            final content =
                results[i]!.content as Map<String, dynamic>?;
            expect(content, isNotNull);
            expect(content!['seq'], equals(i));
            expect(content['payload'], equals('data-$i'));
          }
        }
      },
    );

    test(
      'empty content field does not crash batch',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final se = _makeSessionEncryption(enc);

        final messages = await Future.wait([
          for (var i = 0; i < 5; i++)
            _encryptedWireMessage(
              enc,
              'empty-$i',
              i,
              {'value': i},
            ),
        ]);

        // Replace message 1's content with an empty string.
        // The session encryption layer sees content: '' — not a recognised
        // encrypted wrapper, so it produces a non-null DecryptedMessage
        // with null content rather than crashing.
        final corrupt = Map<String, dynamic>.from(messages[1]);
        corrupt['content'] = '';
        messages[1] = corrupt;

        final results = await se.decryptMessages(messages);

        expect(results.length, equals(5));

        // Empty-content message: a DecryptedMessage is returned (not a
        // crash / null list slot), but its content will be null since the
        // empty string is not an encrypted payload.
        expect(
          results[1],
          isNotNull,
          reason:
              'empty-content message should yield a DecryptedMessage, not null',
        );

        // Surrounding messages must be fully intact.
        for (final i in [0, 2, 3, 4]) {
          expect(
            results[i],
            isNotNull,
            reason: 'valid message at index $i was dropped',
          );
          final content =
              results[i]!.content as Map<String, dynamic>?;
          expect(content, isNotNull);
          expect(content!['value'], equals(i));
        }
      },
    );

    test(
      'wrong encryption format (missing version byte) in one item does '
      'not affect others',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final se = _makeSessionEncryption(enc);

        final messages = await Future.wait([
          for (var i = 0; i < 5; i++)
            _encryptedWireMessage(
              enc,
              'ver-$i',
              i,
              {'n': i, 'label': 'item-$i'},
            ),
        ]);

        // Strip the version byte from message at index 4.
        // AES256Encryption.encrypt prepends a 0x00 version byte; decode the
        // stored base64, drop byte 0, re-encode so the decryptor sees data
        // that starts with the nonce rather than the version byte and
        // consequently rejects it (item[0] != 0 → null).
        final targetContent =
            messages[4]['content'] as Map<String, dynamic>;
        final originalB64 = targetContent['c'] as String;
        final originalBytes = Base64Utils.decode(originalB64, Encoding.base64);
        // Drop the version byte (first byte).
        final stripped = originalBytes.sublist(1);
        final strippedB64 = Base64Utils.encode(stripped, Encoding.base64);

        final corrupt = Map<String, dynamic>.from(messages[4]);
        corrupt['content'] = {'t': 'encrypted', 'c': strippedB64};
        messages[4] = corrupt;

        final results = await se.decryptMessages(messages);

        expect(results.length, equals(5));

        // Index 4: version byte missing, so AES256Encryption.decrypt returns
        // null for that slot — the DecryptedMessage has null content.
        expect(
          results[4],
          isNotNull,
          reason: 'index 4 should yield a DecryptedMessage, not null',
        );
        expect(
          results[4]!.content,
          isNull,
          reason: 'stripped-version-byte item must have null content',
        );

        // Indices 0–3: unaffected.
        for (var i = 0; i < 4; i++) {
          expect(
            results[i],
            isNotNull,
            reason: 'valid message at index $i was dropped',
          );
          final content =
              results[i]!.content as Map<String, dynamic>?;
          expect(content, isNotNull);
          expect(content!['n'], equals(i));
          expect(content['label'], equals('item-$i'));
        }
      },
    );

    test(
      'batch with mix of encrypted and unencrypted messages',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final se = _makeSessionEncryption(enc);

        // Two properly encrypted messages.
        final enc0 = await _encryptedWireMessage(
          enc,
          'mixed-0',
          0,
          {'role': 'user', 'text': 'hello'},
        );
        final enc2 = await _encryptedWireMessage(
          enc,
          'mixed-2',
          2,
          {'role': 'assistant', 'text': 'world'},
        );

        // One message without the {'t': 'encrypted', 'c': ...} wrapper —
        // simulates legacy or plaintext messages from the server.
        final plaintext = <String, dynamic>{
          'id': 'mixed-1',
          'seq': 1,
          'content': {'role': 'system', 'text': 'unencrypted'},
          'createdAt': 1700000000000,
        };

        // Another with a completely absent content field.
        final noContent = <String, dynamic>{
          'id': 'mixed-3',
          'seq': 3,
          'createdAt': 1700000000000,
        };

        final messages = [enc0, plaintext, enc2, noContent];

        final results = await se.decryptMessages(messages);

        // Result count must always match input count.
        expect(results.length, equals(4));

        // Encrypted messages must decrypt correctly.
        expect(results[0], isNotNull);
        expect(results[0]!.id, equals('mixed-0'));
        final content0 = results[0]!.content as Map<String, dynamic>?;
        expect(content0, isNotNull);
        expect(content0!['text'], equals('hello'));

        expect(results[2], isNotNull);
        expect(results[2]!.id, equals('mixed-2'));
        final content2 = results[2]!.content as Map<String, dynamic>?;
        expect(content2, isNotNull);
        expect(content2!['text'], equals('world'));

        // Non-encrypted messages: DecryptedMessage is returned (not null
        // list slot) but content is null since they weren't encrypted.
        expect(
          results[1],
          isNotNull,
          reason: 'plaintext message should yield a DecryptedMessage',
        );
        expect(
          results[3],
          isNotNull,
          reason: 'no-content message should yield a DecryptedMessage',
        );
      },
    );
  });
}
