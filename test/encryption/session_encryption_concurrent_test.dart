// Tests for concurrent/parallel decryption safety in SessionEncryption.
//
// In production, multiple decrypt calls can happen simultaneously —
// e.g. sync fetching messages for different sessions, or a sync update
// arriving while a fetch is in progress.  These tests verify that
// concurrent decryption never corrupts results.

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

SessionEncryption _makeSessionEncryption(
  AES256Encryption enc, {
  String sessionId = 'test-session',
}) {
  return SessionEncryption(
    sessionId: sessionId,
    encryptor: enc,
    decryptor: enc,
    cache: EncryptionCache(),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Concurrent decryption safety', () {
    test(
      'parallel decryptMessages calls return correct results',
      () async {
        // Two independent SessionEncryption instances, each with a distinct
        // key, simulating different sessions being decrypted at the same time.
        final keyA = _generateKey();
        final keyB = _generateKey();
        final encA = AES256Encryption(keyA);
        final encB = AES256Encryption(keyB);
        final seA = _makeSessionEncryption(encA, sessionId: 'session-A');
        final seB = _makeSessionEncryption(encB, sessionId: 'session-B');

        final msgsA = await Future.wait([
          for (var i = 0; i < 5; i++)
            _encryptedWireMessage(
              encA,
              'a-$i',
              i,
              {'session': 'A', 'index': i},
            ),
        ]);
        final msgsB = await Future.wait([
          for (var i = 0; i < 5; i++)
            _encryptedWireMessage(
              encB,
              'b-$i',
              i,
              {'session': 'B', 'index': i},
            ),
        ]);

        // Launch both decryptions in parallel.
        final results = await Future.wait([
          seA.decryptMessages(msgsA),
          seB.decryptMessages(msgsB),
        ]);

        final resultsA = results[0];
        final resultsB = results[1];

        expect(resultsA.length, equals(5));
        expect(resultsB.length, equals(5));

        for (var i = 0; i < 5; i++) {
          final contentA =
              resultsA[i]!.content as Map<String, dynamic>;
          expect(contentA['session'], equals('A'));
          expect(contentA['index'], equals(i));

          final contentB =
              resultsB[i]!.content as Map<String, dynamic>;
          expect(contentB['session'], equals('B'));
          expect(contentB['index'], equals(i));
        }
      },
    );

    test(
      'parallel decryptMessages on same SessionEncryption',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final se = _makeSessionEncryption(enc);

        // Two batches with non-overlapping ids so cache keys differ.
        final batch1 = await Future.wait([
          for (var i = 0; i < 4; i++)
            _encryptedWireMessage(
              enc,
              'batch1-$i',
              i,
              {'batch': 1, 'index': i},
            ),
        ]);
        final batch2 = await Future.wait([
          for (var i = 0; i < 4; i++)
            _encryptedWireMessage(
              enc,
              'batch2-$i',
              i,
              {'batch': 2, 'index': i},
            ),
        ]);

        // Both calls share the same SessionEncryption instance.
        final results = await Future.wait([
          se.decryptMessages(batch1),
          se.decryptMessages(batch2),
        ]);

        final r1 = results[0];
        final r2 = results[1];

        expect(r1.length, equals(4));
        expect(r2.length, equals(4));

        for (var i = 0; i < 4; i++) {
          final c1 = r1[i]!.content as Map<String, dynamic>;
          expect(c1['batch'], equals(1));
          expect(c1['index'], equals(i));

          final c2 = r2[i]!.content as Map<String, dynamic>;
          expect(c2['batch'], equals(2));
          expect(c2['index'], equals(i));
        }
      },
    );

    test(
      'decryptMessages during encrypt does not interfere',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final se = _makeSessionEncryption(enc);

        // Pre-encrypt messages before the concurrent phase so the decrypt
        // call has valid ciphertext to work with.
        final messages = await Future.wait([
          for (var i = 0; i < 5; i++)
            _encryptedWireMessage(
              enc,
              'concurrent-$i',
              i,
              {'value': 'item-$i'},
            ),
        ]);

        // Fire encrypt and decrypt concurrently on the same instance.
        final encryptFuture =
            se.encryptRaw({'payload': 'something to encrypt'});
        final decryptFuture = se.decryptMessages(messages);

        final encryptedResult = await encryptFuture;
        final decryptedResults = await decryptFuture;

        // Encrypt produced a non-empty base64 string.
        expect(encryptedResult, isA<String>());
        expect(encryptedResult.isNotEmpty, isTrue);

        // Decrypt produced correct results for all messages.
        expect(decryptedResults.length, equals(5));
        for (var i = 0; i < 5; i++) {
          expect(
            decryptedResults[i],
            isNotNull,
            reason: 'message $i was null after concurrent encrypt',
          );
          final content =
              decryptedResults[i]!.content as Map<String, dynamic>;
          expect(content['value'], equals('item-$i'));
        }
      },
    );

    test(
      'multiple concurrent decryptAndProcessMessages calls',
      () async {
        const concurrency = 5;
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final se = _makeSessionEncryption(enc);

        // Build one batch per concurrent call.
        final batches = await Future.wait([
          for (var b = 0; b < concurrency; b++)
            Future.wait([
              for (var i = 0; i < 3; i++)
                _encryptedWireMessage(
                  enc,
                  'proc-b$b-m$i',
                  b * 10 + i,
                  {'batch': b, 'index': i},
                ),
            ]),
        ]);

        // Launch all five calls simultaneously.
        final results = await Future.wait([
          for (var b = 0; b < concurrency; b++)
            se.decryptAndProcessMessages(batches[b], 'session-$b'),
        ]);

        expect(results.length, equals(concurrency));
        for (var b = 0; b < concurrency; b++) {
          expect(
            results[b].messages.length,
            equals(3),
            reason: 'batch $b should have 3 processed messages',
          );
        }
      },
    );

    test(
      'rapid sequential decrypt calls all succeed',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final se = _makeSessionEncryption(enc);

        const callCount = 10;

        // Pre-build one wire message per call.
        final wireMessages = await Future.wait([
          for (var i = 0; i < callCount; i++)
            _encryptedWireMessage(
              enc,
              'rapid-$i',
              i,
              {'round': i, 'data': 'payload-$i'},
            ),
        ]);

        // Fire all calls without awaiting between them.
        final futures = <Future<List<DecryptedMessage?>>>[];
        for (var i = 0; i < callCount; i++) {
          futures.add(se.decryptMessages([wireMessages[i]]));
        }

        // Now await all of them together.
        final allResults = await Future.wait(futures);

        expect(allResults.length, equals(callCount));
        for (var i = 0; i < callCount; i++) {
          expect(allResults[i].length, equals(1));
          expect(
            allResults[i][0],
            isNotNull,
            reason: 'rapid call $i returned null result',
          );
          final content =
              allResults[i][0]!.content as Map<String, dynamic>;
          expect(content['round'], equals(i));
          expect(content['data'], equals('payload-$i'));
        }
      },
    );

    test(
      'large concurrent batch (stress test)',
      () async {
        const concurrency = 3;
        const batchSize = 20;

        final key = _generateKey();
        final enc = AES256Encryption(key);
        final se = _makeSessionEncryption(enc);

        // Build concurrency × batchSize messages with unique ids.
        final batches = await Future.wait([
          for (var b = 0; b < concurrency; b++)
            Future.wait([
              for (var i = 0; i < batchSize; i++)
                _encryptedWireMessage(
                  enc,
                  'stress-b$b-m$i',
                  b * batchSize + i,
                  {'batch': b, 'index': i, 'marker': 'stress'},
                ),
            ]),
        ]);

        // All three calls run in parallel.
        final results = await Future.wait([
          for (var b = 0; b < concurrency; b++)
            se.decryptMessages(batches[b]),
        ]);

        var totalDecrypted = 0;
        for (var b = 0; b < concurrency; b++) {
          expect(
            results[b].length,
            equals(batchSize),
            reason: 'batch $b length mismatch',
          );
          for (var i = 0; i < batchSize; i++) {
            expect(
              results[b][i],
              isNotNull,
              reason: 'batch $b message $i was null in stress test',
            );
            final content =
                results[b][i]!.content as Map<String, dynamic>;
            expect(content['batch'], equals(b));
            expect(content['index'], equals(i));
            expect(content['marker'], equals('stress'));
            totalDecrypted++;
          }
        }

        // Sanity: all 60 results were non-null and correct.
        expect(
          totalDecrypted,
          equals(concurrency * batchSize),
          reason: 'expected ${concurrency * batchSize} total results',
        );
      },
    );
  });
}
