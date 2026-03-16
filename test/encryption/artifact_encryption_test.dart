import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/artifact_encryption.dart';
import 'package:happy_flutter/core/encryption/base64.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';

void main() {
  group('ArtifactEncryption', () {
    late Uint8List key;
    late ArtifactEncryption encryption;

    setUp(() {
      key = _generateKey();
      encryption = ArtifactEncryption(key);
    });

    test('decryptHeader roundtrip', () async {
      final header = <String, dynamic>{
        'title': 'My Artifact',
        'version': 1,
        'tags': ['dart', 'flutter'],
      };

      final encrypted = await encryption.encryptHeader(header);
      final result = await encryption.decryptHeader(encrypted);

      expect(result, isNotNull);
      expect(result, equals(header));
    });

    test('decryptBody roundtrip', () async {
      final body = <String, dynamic>{'body': 'hello world'};

      final encrypted = await encryption.encryptBody(body);
      final result = await encryption.decryptBody(encrypted);

      expect(result, isNotNull);
      expect(result, equals({'body': 'hello world'}));
    });

    test('decryptHeader with invalid base64 returns null', () async {
      final result = await encryption.decryptHeader('not!!valid@@base64###');

      expect(result, isNull);
    });

    test('decryptBody with invalid base64 returns null', () async {
      final result = await encryption.decryptBody('not!!valid@@base64###');

      expect(result, isNull);
    });

    test('decryptHeader when decryption fails returns null', () async {
      // Encrypt with one key, attempt to decrypt with a different key.
      final otherKey = _generateKey();
      final otherEncryption = ArtifactEncryption(otherKey);

      final header = <String, dynamic>{'title': 'secret'};
      final encrypted = await otherEncryption.encryptHeader(header);

      final result = await encryption.decryptHeader(encrypted);

      expect(result, isNull);
    });

    test('decryptBody when decryption fails returns null', () async {
      // Encrypt with one key, attempt to decrypt with a different key.
      final otherKey = _generateKey();
      final otherEncryption = ArtifactEncryption(otherKey);

      final body = <String, dynamic>{'body': 'secret content'};
      final encrypted = await otherEncryption.encryptBody(body);

      final result = await encryption.decryptBody(encrypted);

      expect(result, isNull);
    });

    test(
      'decryptHeader with non-map decrypted data returns null',
      () async {
        // Encrypt a plain string (not a map) directly via AES256Encryption
        // so the base64 payload decrypts to a non-map value.
        final encryptor = AES256Encryption(key);
        const nonMap = 'just a string, not a map';
        final rawEncrypted = await encryptor.encrypt([nonMap]);
        final encoded = Base64Utils.encode(
          rawEncrypted[0],
          Encoding.base64,
        );

        final result = await encryption.decryptHeader(encoded);

        expect(result, isNull);
      },
    );

    test('decryptBody with missing body field', () async {
      // Encrypt a map without the 'body' key.
      final body = <String, dynamic>{'other': 'data'};
      final encrypted = await encryption.encryptBody(body);

      final result = await encryption.decryptBody(encrypted);

      // decryptBody returns {'body': body['body']} — null when key absent.
      expect(result, equals({'body': null}));
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
