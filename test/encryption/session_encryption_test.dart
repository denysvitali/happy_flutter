// Tests for SessionEncryption.decryptMessages completeness.
//
// These tests guard against the class of bug where batch decryption
// silently drops items — the production bug that was triggered by
// Isolate.run() returning empty/null results on Android.  Every test
// asserts that the result list length equals the input length AND that
// no item was silently nulled out.

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

/// Builds a wire-format message map with AES-256-GCM–encrypted content.
///
/// Mirrors the server payload shape that [SessionEncryption.decryptMessages]
/// expects:
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
  group('SessionEncryption.decryptMessages — completeness', () {
    test(
      'returns one result per input message (10 messages)',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final se = _makeSessionEncryption(enc);

        final messages = await Future.wait([
          for (var i = 0; i < 10; i++)
            _encryptedWireMessage(
              enc,
              'msg-$i',
              i,
              {'text': 'hello from message $i', 'index': i},
            ),
        ]);

        final results = await se.decryptMessages(messages);

        // Length must match exactly — no silent drops.
        expect(results.length, equals(10));

        for (var i = 0; i < 10; i++) {
          expect(
            results[i],
            isNotNull,
            reason: 'message at index $i was silently dropped',
          );
          expect(results[i]!.id, equals('msg-$i'));
          expect(results[i]!.seq, equals(i));

          // Content must be a map with the original fields.
          final content = results[i]!.content as Map<String, dynamic>?;
          expect(
            content,
            isNotNull,
            reason: 'decrypted content at index $i is null',
          );
          expect(content!['text'], equals('hello from message $i'));
          expect(content['index'], equals(i));
        }
      },
    );

    test(
      'preserves message order across a batch',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final se = _makeSessionEncryption(enc);

        // Give each message a unique, order-sensitive payload.
        final payloads = [
          {'role': 'user', 'text': 'first'},
          {'role': 'assistant', 'text': 'second'},
          {'role': 'user', 'text': 'third'},
          {'role': 'assistant', 'text': 'fourth'},
          {'role': 'user', 'text': 'fifth'},
        ];

        final messages = await Future.wait([
          for (var i = 0; i < payloads.length; i++)
            _encryptedWireMessage(enc, 'ord-$i', i, payloads[i]),
        ]);

        final results = await se.decryptMessages(messages);

        expect(results.length, equals(payloads.length));

        for (var i = 0; i < payloads.length; i++) {
          final content = results[i]!.content as Map<String, dynamic>;
          expect(
            content['text'],
            equals(payloads[i]['text']),
            reason:
                'order mismatch at position $i: '
                'expected "${payloads[i]['text']}" '
                'got "${content['text']}"',
          );
        }
      },
    );

    test(
      'handles batch of 20+ messages — all results non-null',
      () async {
        // 25 messages — this was the approximate threshold that previously
        // triggered isolate offloading, causing silent data loss on Android.
        const batchSize = 25;

        final key = _generateKey();
        final enc = AES256Encryption(key);
        final se = _makeSessionEncryption(enc);

        final messages = await Future.wait([
          for (var i = 0; i < batchSize; i++)
            _encryptedWireMessage(
              enc,
              'batch-$i',
              i,
              {'seq': i, 'payload': 'data-$i'},
            ),
        ]);

        final results = await se.decryptMessages(messages);

        expect(
          results.length,
          equals(batchSize),
          reason: 'result list length must equal input length',
        );

        for (var i = 0; i < batchSize; i++) {
          expect(
            results[i],
            isNotNull,
            reason:
                'message at index $i was silently dropped in 25-item batch',
          );

          final content = results[i]!.content as Map<String, dynamic>?;
          expect(
            content,
            isNotNull,
            reason: 'content at index $i is null in 25-item batch',
          );
          expect(content!['seq'], equals(i));
          expect(content['payload'], equals('data-$i'));
        }
      },
    );

    test(
      'decryptMessage (singular) decrypts a single message correctly',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final se = _makeSessionEncryption(enc);

        final wire = await _encryptedWireMessage(
          enc,
          'single-1',
          42,
          {'type': 'text', 'body': 'singular test'},
        );

        final result = await se.decryptMessage(wire);

        expect(result, isNotNull);
        expect(result!.id, equals('single-1'));
        expect(result.seq, equals(42));

        final content = result.content as Map<String, dynamic>?;
        expect(content, isNotNull);
        expect(content!['type'], equals('text'));
        expect(content['body'], equals('singular test'));
      },
    );

    test(
      'decryptMessage returns null for null input',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final se = _makeSessionEncryption(enc);

        final result = await se.decryptMessage(null);
        expect(result, isNull);
      },
    );

    test(
      'decryptMessage returns null for empty map input',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final se = _makeSessionEncryption(enc);

        final result = await se.decryptMessage({});
        expect(result, isNull);
      },
    );

    test(
      'decryptMessages result length equals input for mixed valid/empty batch',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final se = _makeSessionEncryption(enc);

        final validWire = await _encryptedWireMessage(
          enc,
          'valid-1',
          1,
          {'text': 'valid'},
        );

        // Empty maps are allowed in the input; the contract is that the
        // result list length always equals the input list length.
        final messages = [
          validWire,
          <String, dynamic>{}, // empty — should produce null result slot
          validWire,
        ];

        final results = await se.decryptMessages(messages);

        expect(
          results.length,
          equals(3),
          reason:
              'result length must equal input length even with empty entries',
        );
        expect(results[0], isNotNull);
        expect(results[1], isNull); // empty map produces null
        expect(results[2], isNotNull);
      },
    );
  });
}
