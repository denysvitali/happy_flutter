// Tests that decrypt code paths surface failures as null/empty rather
// than throwing. Production GlitchTip surfaced ~27 warning-level
// "CryptoSecretBox.decrypt failed" events per day; this test pins the
// contract that recoverable decrypt failures stay recoverable.
//
// The crypto/key derivation logic itself is not exercised here — these
// tests deliberately use a real key with garbage ciphertext to confirm
// the surrounding plumbing does not propagate the exception.

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/crypto_secret_box.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/machine_encryption.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';

Uint8List _generateKey() {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(32, (_) => random.nextInt(256)),
  );
}

void main() {
  group('CryptoSecretBox.decrypt — failure softening', () {
    test(
      'returns null without throwing when ciphertext is below the '
      'nonce+mac minimum',
      () async {
        final key = _generateKey();
        final tooShort = Uint8List(8); // less than 24 (nonce) + 16 (mac)

        final result = await CryptoSecretBox.decrypt(tooShort, key);

        expect(result, isNull);
      },
    );

    test('returns null without throwing when ciphertext is corrupt', () async {
      final key = _generateKey();
      // Plausibly-sized but garbage bytes — sodium will fail the MAC check.
      final garbage = Uint8List.fromList(
        List<int>.generate(64, (i) => i & 0xff),
      );

      final result = await CryptoSecretBox.decrypt(garbage, key);

      expect(result, isNull);
    });
  });

  group('AES256Encryption.decrypt — failure softening', () {
    test('returns null entries for items with bad version byte', () async {
      final key = _generateKey();
      final aes = AES256Encryption(key);
      // Wrong version byte (0xFF) — must short-circuit to null.
      final bad = Uint8List.fromList([0xff, 1, 2, 3]);
      final empty = Uint8List(0);

      final results = await aes.decrypt([bad, empty]);

      expect(results.length, 2);
      expect(results[0], isNull);
      expect(results[1], isNull);
    });

    test(
      'returns null for items whose payload is too small to be GCM',
      () async {
        final key = _generateKey();
        final aes = AES256Encryption(key);
        // Version byte 0 (valid) plus a few junk bytes — AES-GCM
        // decrypt should throw internally, but the catch must
        // swallow it and emit null.
        final corrupt = Uint8List.fromList([0, 1, 2, 3, 4]);

        final results = await aes.decrypt([corrupt]);

        expect(results, [null]);
      },
    );
  });

  group('SessionEncryption.decryptRaw — corrupt input', () {
    test('returns null when input is not valid base64', () async {
      final key = _generateKey();
      final aes = AES256Encryption(key);
      final session = SessionEncryption(
        sessionId: 'session-corrupt',
        encryptor: aes,
        decryptor: aes,
        cache: EncryptionCache(),
      );

      final result = await session.decryptRaw('!!! not base64 !!!');

      expect(result, isNull);
    });
  });

  group('SessionEncryption.decryptMetadata — corrupt input', () {
    test('returns null on bad base64 instead of throwing', () async {
      final key = _generateKey();
      final aes = AES256Encryption(key);
      final session = SessionEncryption(
        sessionId: 'session-corrupt',
        encryptor: aes,
        decryptor: aes,
        cache: EncryptionCache(),
      );

      final result = await session.decryptMetadata(0, '###not-base64###');

      expect(result, isNull);
    });
  });

  group('SessionEncryption.decryptAgentState — corrupt input', () {
    test('returns empty map on bad base64 instead of throwing', () async {
      final key = _generateKey();
      final aes = AES256Encryption(key);
      final session = SessionEncryption(
        sessionId: 'session-corrupt',
        encryptor: aes,
        decryptor: aes,
        cache: EncryptionCache(),
      );

      final result = await session.decryptAgentState(0, '###not-base64###');

      expect(result, isEmpty);
    });
  });

  group('MachineEncryption.decryptMetadata — corrupt input', () {
    test('returns null on bad base64 instead of throwing', () async {
      final key = _generateKey();
      final aes = AES256Encryption(key);
      final machine = MachineEncryption(
        machineId: 'machine-corrupt',
        encryptor: aes,
        decryptor: aes,
        cache: EncryptionCache(),
      );

      final result = await machine.decryptMetadata(0, '###not-base64###');

      expect(result, isNull);
    });
  });

  group('SessionEncryption.decryptMessages — corrupt single message', () {
    test(
      'corrupt ciphertext in one slot does not throw or poison '
      'the batch result',
      () async {
        final key = _generateKey();
        final aes = AES256Encryption(key);
        final session = SessionEncryption(
          sessionId: 'session-mixed',
          encryptor: aes,
          decryptor: aes,
          cache: EncryptionCache(),
        );

        // Build one message with garbage base64 content. The expected
        // behaviour is a non-null DecryptedMessage with null content,
        // never an exception.
        final messages = <Map<String, dynamic>>[
          {
            'id': 'msg-corrupt',
            'seq': 1,
            'content': {'t': 'encrypted', 'c': 'this is not base64 !!!'},
            'createdAt': 1700000000000,
          },
        ];

        final decrypted = await session.decryptMessages(messages);

        expect(decrypted, hasLength(1));
        expect(decrypted[0], isNotNull);
        expect(decrypted[0]!.content, isNull);
      },
    );
  });
}
