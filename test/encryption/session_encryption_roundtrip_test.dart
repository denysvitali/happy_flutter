import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/aes_gcm.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/native/native_core.dart';

void main() {
  group('SessionEncryption - end-to-end roundtrip', () {
    late AES256Encryption encryptor;
    late SessionEncryption sessionEncryption;

    setUp(() {
      final key = _generateKey();
      encryptor = AES256Encryption(key);
      sessionEncryption = SessionEncryption(
        sessionId: 'test-session',
        encryptor: encryptor,
        decryptor: encryptor,
        cache: EncryptionCache(),
      );
    });

    test('encryptRaw/decryptRaw roundtrip preserves map data', () async {
      final original = <String, dynamic>{
        'role': 'user',
        'text': 'Hello from roundtrip test',
        'count': 42,
      };

      final encrypted = await sessionEncryption.encryptRaw(original);
      expect(encrypted, isA<String>());
      expect(encrypted.isNotEmpty, isTrue);

      final decrypted = await sessionEncryption.decryptRaw(encrypted);
      expect(decrypted, isNotNull);
      expect(decrypted, equals(original));
    });

    test('encryptRaw/decryptRaw roundtrip preserves string data', () async {
      const original = 'plain string payload';

      final encrypted = await sessionEncryption.encryptRaw(original);
      expect(encrypted, isA<String>());

      final decrypted = await sessionEncryption.decryptRaw(encrypted);
      expect(decrypted, equals(original));
    });

    test('repeated text and retry keep distinct canonical localIds through '
        'encryption and out-of-order decrypt', () async {
      addTearDown(NativeCore.instance.debugReset);
      await NativeCore.instance.ensureInitialized();
      final payloads = <Map<String, String>>[
        {'localId': 'tap-1', 'text': 'continue'},
        {'localId': 'tap-2', 'text': 'continue'},
        {'localId': 'tap-1', 'text': 'continue'},
      ];
      final encrypted = await encryptor.encrypt(payloads);
      expect(encrypted, hasLength(3));
      expect(encrypted.map((bytes) => bytes[0]), everyElement(0));
      expect(
        encrypted[0],
        isNot(encrypted[2]),
        reason: 'a retry uses a fresh nonce but keeps the same localId',
      );
      expect(
        await AesGcmEncryption.decrypt(
          encrypted[0].sublist(1),
          encryptor.secretKey,
        ),
        payloads[0],
      );

      final reversed = await encryptor.decrypt(encrypted.reversed.toList());
      expect(reversed, payloads.reversed.toList());
      expect(reversed.map((value) => value['localId']), [
        'tap-1',
        'tap-2',
        'tap-1',
      ]);
    });

    test('encryptRawRecord/decryptRaw roundtrip', () async {
      final record = <String, dynamic>{
        'id': 'rec-001',
        'type': 'tool_result',
        'output': 'build succeeded',
        'exitCode': 0,
      };

      final encrypted = await sessionEncryption.encryptRawRecord(record);
      expect(encrypted, isA<String>());
      expect(encrypted.isNotEmpty, isTrue);

      final decrypted = await sessionEncryption.decryptRaw(encrypted);
      expect(decrypted, isNotNull);
      expect(decrypted, equals(record));
    });

    test('encryptMetadata/decryptMetadata roundtrip', () async {
      final metadata = <String, dynamic>{
        'path': '~/projects/app',
        'summary': 'Working on Flutter encryption',
        'tags': ['flutter', 'crypto'],
      };
      const version = 1;

      final encrypted = await sessionEncryption.encryptMetadata(metadata);
      expect(encrypted, isA<String>());

      final decrypted = await sessionEncryption.decryptMetadata(
        version,
        encrypted,
      );
      expect(decrypted, isNotNull);
      expect(decrypted, equals(metadata));
    });

    test('encryptAgentState/decryptAgentState roundtrip', () async {
      final state = <String, dynamic>{
        'status': 'running',
        'model': 'claude-3-5-sonnet',
        'turnCount': 7,
        'aborted': false,
      };
      const version = 2;

      final encrypted = await sessionEncryption.encryptAgentState(state);
      expect(encrypted, isA<String>());

      final decrypted = await sessionEncryption.decryptAgentState(
        version,
        encrypted,
      );
      expect(decrypted, equals(state));
    });

    test('decryptAgentState with null returns empty map', () async {
      final result = await sessionEncryption.decryptAgentState(1, null);
      expect(result, isEmpty);
    });

    test('decryptAgentState with empty string returns empty map', () async {
      final result = await sessionEncryption.decryptAgentState(1, '');
      expect(result, isEmpty);
    });

    test('decryptRaw with corrupted data returns null', () async {
      // A valid-looking base64 string that is not actually encrypted data.
      const corrupted = 'dGhpcyBpcyBub3QgZW5jcnlwdGVkZGF0YQ==';

      final result = await sessionEncryption.decryptRaw(corrupted);
      expect(result, isNull);
    });
  });
}

/// Generates a cryptographically random 32-byte AES-256 key.
Uint8List _generateKey() {
  final random = Random.secure();
  final key = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    key[i] = random.nextInt(256);
  }
  return key;
}
