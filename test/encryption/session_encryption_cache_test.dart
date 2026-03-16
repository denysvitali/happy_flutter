// Tests for SessionEncryption.decryptMessages with mixed cached/uncached
// messages.
//
// Guards against the class of bug where partial cache hits mask silent
// failures — cached items return fine but newly-decrypted items fail
// silently.  Every test verifies that ALL results are non-null regardless
// of how many items come from cache vs live decryption.

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

/// Builds a wire-format message with AES-256-GCM–encrypted content.
///
/// Mirrors the server payload shape:
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

/// Creates a [SessionEncryption] backed by a shared [EncryptionCache].
///
/// Pass the same [cache] instance across calls within a test to exercise
/// cross-call caching behaviour.
SessionEncryption _makeSessionEncryption(
  AES256Encryption enc,
  EncryptionCache cache,
) {
  return SessionEncryption(
    sessionId: 'test-session',
    encryptor: enc,
    decryptor: enc,
    cache: cache,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SessionEncryption.decryptMessages — cache behaviour', () {
    test(
      'second call uses cache, still returns all items',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final cache = EncryptionCache();
        final se = _makeSessionEncryption(enc, cache);

        final messages = await Future.wait([
          for (var i = 0; i < 5; i++)
            _encryptedWireMessage(
              enc,
              'msg-$i',
              i,
              {'text': 'hello $i', 'index': i},
            ),
        ]);

        // First call — live decryption, populates cache.
        final first = await se.decryptMessages(messages);

        expect(
          first.length,
          equals(5),
          reason: 'first call must return 5 results',
        );
        for (var i = 0; i < 5; i++) {
          expect(
            first[i],
            isNotNull,
            reason: 'first call: slot $i was null',
          );
          expect(first[i]!.id, equals('msg-$i'));
        }

        // Second call with identical messages — all hits come from cache.
        final second = await se.decryptMessages(messages);

        expect(
          second.length,
          equals(5),
          reason: 'second (cached) call must return 5 results',
        );
        for (var i = 0; i < 5; i++) {
          expect(
            second[i],
            isNotNull,
            reason: 'second (cached) call: slot $i was null',
          );
          expect(second[i]!.id, equals('msg-$i'));
          final content = second[i]!.content as Map<String, dynamic>?;
          expect(
            content,
            isNotNull,
            reason: 'cached content at slot $i must not be null',
          );
          expect(content!['index'], equals(i));
        }
      },
    );

    test(
      'mixed batch: some cached, some new — all return non-null',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final cache = EncryptionCache();
        final se = _makeSessionEncryption(enc, cache);

        final msgA = await _encryptedWireMessage(
          enc,
          'a',
          1,
          {'text': 'alpha'},
        );
        final msgB = await _encryptedWireMessage(
          enc,
          'b',
          2,
          {'text': 'beta'},
        );
        final msgC = await _encryptedWireMessage(
          enc,
          'c',
          3,
          {'text': 'gamma'},
        );

        // Prime cache with A, B, C.
        await se.decryptMessages([msgA, msgB, msgC]);

        final msgD = await _encryptedWireMessage(
          enc,
          'd',
          4,
          {'text': 'delta'},
        );
        final msgE = await _encryptedWireMessage(
          enc,
          'e',
          5,
          {'text': 'epsilon'},
        );

        // A is cached; D and E are new — mixed batch.
        final results = await se.decryptMessages([msgA, msgD, msgE]);

        expect(
          results.length,
          equals(3),
          reason: 'mixed batch must return 3 results',
        );

        expect(results[0], isNotNull, reason: 'A (cached) must not be null');
        expect(results[1], isNotNull, reason: 'D (new) must not be null');
        expect(results[2], isNotNull, reason: 'E (new) must not be null');

        expect(results[0]!.id, equals('a'));
        expect(results[1]!.id, equals('d'));
        expect(results[2]!.id, equals('e'));

        final contentD = results[1]!.content as Map<String, dynamic>?;
        expect(contentD, isNotNull);
        expect(contentD!['text'], equals('delta'));

        final contentE = results[2]!.content as Map<String, dynamic>?;
        expect(contentE, isNotNull);
        expect(contentE!['text'], equals('epsilon'));
      },
    );

    test(
      'interleaved cached and uncached messages preserve order',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final cache = EncryptionCache();
        final se = _makeSessionEncryption(enc, cache);

        // Build A–E.
        final msgs = await Future.wait([
          for (final id in ['a', 'b', 'c', 'd', 'e'])
            _encryptedWireMessage(
              enc,
              id,
              id.codeUnitAt(0),
              {'letter': id},
            ),
        ]);
        final msgA = msgs[0];
        final msgB = msgs[1];
        final msgC = msgs[2];
        final msgD = msgs[3];
        final msgE = msgs[4];

        // Prime cache with A, B, C, D, E.
        await se.decryptMessages([msgA, msgB, msgC, msgD, msgE]);

        final msgF = await _encryptedWireMessage(
          enc,
          'f',
          102,
          {'letter': 'f'},
        );
        final msgG = await _encryptedWireMessage(
          enc,
          'g',
          103,
          {'letter': 'g'},
        );

        // Interleaved: A (cached), F (new), B (cached), G (new), C (cached).
        final batch = [msgA, msgF, msgB, msgG, msgC];
        final results = await se.decryptMessages(batch);

        expect(
          results.length,
          equals(5),
          reason: 'interleaved batch must return 5 results',
        );

        // Verify non-null and correct order.
        final expectedIds = ['a', 'f', 'b', 'g', 'c'];
        for (var i = 0; i < expectedIds.length; i++) {
          expect(
            results[i],
            isNotNull,
            reason: 'slot $i (id=${expectedIds[i]}) must not be null',
          );
          expect(
            results[i]!.id,
            equals(expectedIds[i]),
            reason: 'wrong id at slot $i',
          );
          final content = results[i]!.content as Map<String, dynamic>?;
          expect(
            content,
            isNotNull,
            reason: 'content at slot $i must not be null',
          );
          expect(content!['letter'], equals(expectedIds[i]));
        }
      },
    );

    test(
      'empty messages in batch do not break other results',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final cache = EncryptionCache();
        final se = _makeSessionEncryption(enc, cache);

        final msgA = await _encryptedWireMessage(
          enc,
          'a',
          1,
          {'text': 'alpha'},
        );
        final msgB = await _encryptedWireMessage(
          enc,
          'b',
          2,
          {'text': 'beta'},
        );

        // Batch with an empty-map sentinel in the middle.
        final results = await se.decryptMessages([
          msgA,
          <String, dynamic>{}, // empty — must produce null slot
          msgB,
        ]);

        expect(
          results.length,
          equals(3),
          reason: 'result length must equal input length',
        );

        expect(results[0], isNotNull, reason: 'A must not be null');
        expect(results[1], isNull, reason: 'empty map must produce null');
        expect(results[2], isNotNull, reason: 'B must not be null');

        expect(results[0]!.id, equals('a'));
        expect(results[2]!.id, equals('b'));

        final contentA = results[0]!.content as Map<String, dynamic>?;
        expect(contentA, isNotNull);
        expect(contentA!['text'], equals('alpha'));

        final contentB = results[2]!.content as Map<String, dynamic>?;
        expect(contentB, isNotNull);
        expect(contentB!['text'], equals('beta'));
      },
    );

    test(
      'cache does not return stale data when content changes',
      () async {
        // AES-GCM uses a random IV, so re-encrypting the same plaintext
        // produces a different ciphertext (different length/hashCode).
        // The cache key includes a content signature, so a new encryption
        // of the same message id must produce a different key and thus
        // bypass the cache — returning fresh content.
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final cache = EncryptionCache();
        final se = _makeSessionEncryption(enc, cache);

        // First encryption of id='x' with content A.
        final wireA = await _encryptedWireMessage(
          enc,
          'x',
          1,
          {'payload': 'content-A'},
        );
        final firstResults = await se.decryptMessages([wireA]);

        expect(firstResults.length, equals(1));
        expect(firstResults[0], isNotNull);
        final contentA =
            firstResults[0]!.content as Map<String, dynamic>?;
        expect(contentA, isNotNull);
        expect(
          contentA!['payload'],
          equals('content-A'),
          reason: 'first decrypt must return content A',
        );

        // Second encryption of same id='x' with different content B.
        // The random IV guarantees a distinct ciphertext → distinct cache
        // key → cache miss → fresh decryption.
        final wireB = await _encryptedWireMessage(
          enc,
          'x',
          1,
          {'payload': 'content-B'},
        );
        final secondResults = await se.decryptMessages([wireB]);

        expect(secondResults.length, equals(1));
        expect(secondResults[0], isNotNull);
        final contentB =
            secondResults[0]!.content as Map<String, dynamic>?;
        expect(contentB, isNotNull);
        expect(
          contentB!['payload'],
          equals('content-B'),
          reason:
              'second decrypt must return content B, not stale content A',
        );
      },
    );
  });
}
