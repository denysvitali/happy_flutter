// Tests for cache-key edge cases in SessionEncryption.decryptMessages.
//
// The private _messageCacheKey() / _messageContentSignature() helpers
// determine whether a decrypted result can be served from cache.  These
// tests exercise that logic through the public API and verify the
// following properties:
//
//   • empty-id messages always bypass cache (key = '')
//   • same id + different ciphertext → different key → no stale hit
//   • different ids + same ciphertext → independent cache slots
//   • unencrypted Map content uses the 'json:...' signature path
//   • unencrypted String content uses the 'str:...' signature path
//   • large batches with repeated ids use the cache efficiently

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
  final rng = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(32, (_) => rng.nextInt(256)),
  );
}

/// Encrypts [plaintext] and returns a wire-format message map.
Future<Map<String, dynamic>> _encryptedMessage(
  AES256Encryption enc,
  String id,
  int seq,
  Map<String, dynamic> plaintext,
) async {
  final encrypted = await enc.encrypt([plaintext]);
  final b64 = Base64Utils.encode(encrypted[0], Encoding.base64);
  return {
    'id': id,
    'seq': seq,
    'content': {'t': 'encrypted', 'c': b64},
    'createdAt': 0,
  };
}

SessionEncryption _makeSession(
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
  group('Cache key edge cases', () {
    // -----------------------------------------------------------------------
    // 1. Empty id bypasses cache
    // -----------------------------------------------------------------------
    test('messages with empty id bypass cache', () async {
      final key = _generateKey();
      final enc = AES256Encryption(key);
      final cache = EncryptionCache();
      final se = _makeSession(enc, cache);

      final wireMsg = await _encryptedMessage(
        enc,
        '',
        1,
        {'value': 'bypass-test'},
      );

      // First call — live decryption.
      final first = await se.decryptMessages([wireMsg]);

      expect(first.length, equals(1));
      expect(
        first[0],
        isNotNull,
        reason: 'first decrypt of empty-id message must succeed',
      );

      // Cache must still be empty — empty id never populates the cache.
      expect(
        cache.getStats()['messages'],
        equals(0),
        reason: 'empty-id message must not be stored in cache',
      );

      // Second call with the same map — must go through live decryption
      // again (not a cache hit) and still succeed.
      final second = await se.decryptMessages([wireMsg]);

      expect(second.length, equals(1));
      expect(
        second[0],
        isNotNull,
        reason: 'second decrypt of empty-id message must succeed',
      );
      expect(
        second[0]!.id,
        equals(''),
        reason: 'id field must be preserved as empty string',
      );

      // Cache is still empty after both calls.
      expect(
        cache.getStats()['messages'],
        equals(0),
        reason: 'cache must remain empty after two empty-id decrypts',
      );
    });

    // -----------------------------------------------------------------------
    // 2. Same id, different ciphertext → fresh result, no stale cache hit
    // -----------------------------------------------------------------------
    test(
      'messages with same id but different content get different '
      'cache entries',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final cache = EncryptionCache();
        final se = _makeSession(enc, cache);

        // First ciphertext for id='x'.
        final wireFirst = await _encryptedMessage(
          enc,
          'x',
          1,
          {'payload': 'first'},
        );
        final firstResults = await se.decryptMessages([wireFirst]);

        expect(firstResults[0], isNotNull);
        expect(
          (firstResults[0]!.content as Map<String, dynamic>?)?['payload'],
          equals('first'),
        );

        // AES-GCM uses a random IV, so re-encrypting the same id produces
        // a distinct ciphertext → distinct cache key → cache miss.
        final wireSecond = await _encryptedMessage(
          enc,
          'x',
          1,
          {'payload': 'second'},
        );
        final secondResults = await se.decryptMessages([wireSecond]);

        expect(secondResults[0], isNotNull);
        expect(
          (secondResults[0]!.content as Map<String, dynamic>?)?['payload'],
          equals('second'),
          reason: 'must return fresh content, not the stale cached value',
        );
      },
    );

    // -----------------------------------------------------------------------
    // 3. Different ids, same ciphertext bytes → independent cache slots
    // -----------------------------------------------------------------------
    test(
      'messages with different ids but same content are cached '
      'independently',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final cache = EncryptionCache();
        final se = _makeSession(enc, cache);

        // Encrypt once; reuse the same base64 payload for both messages.
        final encrypted = await enc.encrypt([
          {'shared': 'payload'},
        ]);
        final b64 = Base64Utils.encode(encrypted[0], Encoding.base64);
        final sharedContent = {'t': 'encrypted', 'c': b64};

        final msgAlpha = {
          'id': 'alpha',
          'seq': 1,
          'content': sharedContent,
          'createdAt': 0,
        };
        final msgBeta = {
          'id': 'beta',
          'seq': 2,
          'content': sharedContent,
          'createdAt': 0,
        };

        final results = await se.decryptMessages([msgAlpha, msgBeta]);

        expect(results.length, equals(2));
        expect(results[0], isNotNull, reason: 'alpha must decrypt');
        expect(results[1], isNotNull, reason: 'beta must decrypt');

        // Both should share the same content but have distinct ids.
        expect(results[0]!.id, equals('alpha'));
        expect(results[1]!.id, equals('beta'));
        expect(
          (results[0]!.content as Map<String, dynamic>?)?['shared'],
          equals('payload'),
        );
        expect(
          (results[1]!.content as Map<String, dynamic>?)?['shared'],
          equals('payload'),
        );

        // Two separate cache entries must have been created.
        expect(
          cache.getStats()['messages'],
          equals(2),
          reason: 'each id must occupy its own cache slot',
        );
      },
    );

    // -----------------------------------------------------------------------
    // 4. Unencrypted Map content uses 'json:...' path and is cached
    // -----------------------------------------------------------------------
    test('unencrypted message with map content is cached', () async {
      final key = _generateKey();
      final enc = AES256Encryption(key);
      final cache = EncryptionCache();
      final se = _makeSession(enc, cache);

      // A message whose content is NOT encrypted — plain Map.
      final wireMsg = {
        'id': 'u1',
        'seq': 1,
        'content': {'t': 'other'},
        'createdAt': 0,
      };

      // First call — live (no decryption needed, but still cached).
      final first = await se.decryptMessages([wireMsg]);

      expect(first.length, equals(1));
      expect(first[0], isNotNull, reason: 'unencrypted map must produce a result');
      expect(first[0]!.id, equals('u1'));
      expect(
        cache.getStats()['messages'],
        equals(1),
        reason: 'unencrypted map message must be stored in cache',
      );

      // Second call — must come from cache (same result).
      final second = await se.decryptMessages([wireMsg]);

      expect(second.length, equals(1));
      expect(
        second[0],
        isNotNull,
        reason: 'cached unencrypted map must not be null',
      );
      expect(second[0]!.id, equals('u1'));
      expect(
        second[0]!.seq,
        equals(first[0]!.seq),
        reason: 'cached result must match original',
      );
    });

    // -----------------------------------------------------------------------
    // 5. Unencrypted String content uses 'str:...' path and is cached
    // -----------------------------------------------------------------------
    test('unencrypted message with string content is cached', () async {
      final key = _generateKey();
      final enc = AES256Encryption(key);
      final cache = EncryptionCache();
      final se = _makeSession(enc, cache);

      // A message whose content is a plain String (not valid base64 for an
      // encrypted blob, so decryptMessages treats it as unencrypted).
      // We use a very short string to avoid accidentally matching the
      // 'encrypted raw base64' path — a plain word has no valid AES-GCM
      // structure after decoding.
      final wireMsg = {
        'id': 'u2',
        'seq': 1,
        'content': 'hello',
        'createdAt': 0,
      };

      final first = await se.decryptMessages([wireMsg]);

      expect(first.length, equals(1));
      expect(first[0], isNotNull);
      expect(first[0]!.id, equals('u2'));
      expect(
        cache.getStats()['messages'],
        greaterThanOrEqualTo(1),
        reason: 'string-content message must be stored in cache',
      );

      final second = await se.decryptMessages([wireMsg]);

      expect(second.length, equals(1));
      expect(second[0], isNotNull);
      expect(second[0]!.id, equals('u2'));
      expect(
        second[0]!.seq,
        equals(first[0]!.seq),
        reason: 'second call must return same result from cache',
      );
    });

    // -----------------------------------------------------------------------
    // 6. Large batch with repeated ids uses cache efficiently
    // -----------------------------------------------------------------------
    test(
      'large batch with repeated message ids uses cache efficiently',
      () async {
        final key = _generateKey();
        final enc = AES256Encryption(key);
        final cache = EncryptionCache();
        final se = _makeSession(enc, cache);

        // Encrypt 5 unique messages.
        final unique = await Future.wait([
          for (var i = 0; i < 5; i++)
            _encryptedMessage(enc, 'msg-$i', i, {'index': i}),
        ]);

        // Build a batch of 20 where each unique message appears 4 times.
        // Order: 0,1,2,3,4, 0,1,2,3,4, 0,1,2,3,4, 0,1,2,3,4
        final batch = [
          for (var round = 0; round < 4; round++)
            for (var i = 0; i < 5; i++) unique[i],
        ];

        expect(batch.length, equals(20));

        // First call — first 5 are live, the rest are cache hits.
        final results = await se.decryptMessages(batch);

        expect(
          results.length,
          equals(20),
          reason: 'all 20 results must be present',
        );

        for (var slot = 0; slot < results.length; slot++) {
          final expectedIndex = slot % 5;
          expect(
            results[slot],
            isNotNull,
            reason: 'slot $slot must not be null',
          );
          expect(
            results[slot]!.id,
            equals('msg-$expectedIndex'),
            reason: 'wrong id at slot $slot',
          );
          final content =
              results[slot]!.content as Map<String, dynamic>?;
          expect(
            content,
            isNotNull,
            reason: 'content at slot $slot must not be null',
          );
          expect(
            content!['index'],
            equals(expectedIndex),
            reason: 'wrong index at slot $slot',
          );
        }

        // Exactly 5 unique entries should be in the cache.
        expect(
          cache.getStats()['messages'],
          equals(5),
          reason: 'cache must hold exactly 5 unique entries',
        );
      },
    );
  });
}
