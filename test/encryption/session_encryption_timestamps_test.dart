// Tests for the timestamp parsing path in SessionEncryption.decryptMessages.
//
// The private _parseCreatedAt method handles three variants:
//   1. int  — milliseconds since epoch
//   2. String — ISO 8601 (with or without Z suffix)
//   3. anything else (null, missing key, invalid string) — falls back to now
//
// All cases are exercised through the public API using plaintext (non-encrypted)
// messages so no crypto setup is required.

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

SessionEncryption _makeSessionEncryption() {
  final key = Uint8List.fromList(
    List<int>.generate(32, (_) => Random.secure().nextInt(256)),
  );
  final enc = AES256Encryption(key);
  return SessionEncryption(
    sessionId: 'ts-test',
    encryptor: enc,
    decryptor: enc,
    cache: EncryptionCache(),
  );
}

/// Builds a minimal plaintext wire message.
///
/// The content map has `'t': 'plaintext'` so [decryptMessages] takes the
/// non-encrypted branch and calls `_parseCreatedAt` directly.
Map<String, dynamic> _plaintextMessage(
  String id,
  int seq, {
  dynamic createdAt = _kMissing,
}) {
  final msg = <String, dynamic>{
    'id': id,
    'seq': seq,
    'content': {'t': 'plaintext'},
  };
  if (!identical(createdAt, _kMissing)) {
    msg['createdAt'] = createdAt;
  }
  return msg;
}

const _kMissing = Object(); // sentinel — key will be omitted from the map

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Timestamp parsing in decryptMessages', () {
    late SessionEncryption se;

    setUp(() {
      se = _makeSessionEncryption();
    });

    test('integer timestamp (milliseconds since epoch)', () async {
      const tsMs = 1700000000000;
      final message = _plaintextMessage(
        'ts-1',
        1,
        createdAt: tsMs,
      );

      final results = await se.decryptMessages([message]);

      expect(results, hasLength(1));
      final result = results[0];
      expect(result, isNotNull);
      expect(
        result!.createdAt,
        equals(DateTime.fromMillisecondsSinceEpoch(tsMs)),
      );
    });

    test('ISO 8601 string timestamp', () async {
      const isoZ = '2024-01-15T12:30:00.000Z';
      final message = _plaintextMessage(
        'ts-2',
        2,
        createdAt: isoZ,
      );

      final results = await se.decryptMessages([message]);

      expect(results, hasLength(1));
      final result = results[0];
      expect(result, isNotNull);
      expect(result!.createdAt, equals(DateTime.parse(isoZ)));
    });

    test('ISO 8601 string without Z suffix', () async {
      const isoNoZ = '2024-01-15T12:30:00.000';
      final message = _plaintextMessage(
        'ts-3',
        3,
        createdAt: isoNoZ,
      );

      final results = await se.decryptMessages([message]);

      expect(results, hasLength(1));
      final result = results[0];
      expect(result, isNotNull);
      expect(result!.createdAt, equals(DateTime.parse(isoNoZ)));
    });

    test('null createdAt falls back to approximately now', () async {
      final before = DateTime.now();
      final message = _plaintextMessage('ts-4', 4, createdAt: null);

      final results = await se.decryptMessages([message]);

      final after = DateTime.now();
      expect(results, hasLength(1));
      final result = results[0];
      expect(result, isNotNull);
      expect(
        result!.createdAt.isAfter(
          before.subtract(const Duration(seconds: 2)),
        ),
        isTrue,
      );
      expect(
        result.createdAt.isBefore(
          after.add(const Duration(seconds: 2)),
        ),
        isTrue,
      );
    });

    test('missing createdAt key falls back to approximately now', () async {
      final before = DateTime.now();
      // _plaintextMessage with default _kMissing sentinel omits the key
      final message = _plaintextMessage('ts-5', 5);

      final results = await se.decryptMessages([message]);

      final after = DateTime.now();
      expect(results, hasLength(1));
      final result = results[0];
      expect(result, isNotNull);
      expect(
        result!.createdAt.isAfter(
          before.subtract(const Duration(seconds: 2)),
        ),
        isTrue,
      );
      expect(
        result.createdAt.isBefore(
          after.add(const Duration(seconds: 2)),
        ),
        isTrue,
      );
    });

    test('invalid string createdAt falls back to approximately now', () async {
      final before = DateTime.now();
      final message = _plaintextMessage(
        'ts-6',
        6,
        createdAt: 'not-a-date',
      );

      final results = await se.decryptMessages([message]);

      final after = DateTime.now();
      expect(results, hasLength(1));
      final result = results[0];
      expect(result, isNotNull);
      expect(
        result!.createdAt.isAfter(
          before.subtract(const Duration(seconds: 2)),
        ),
        isTrue,
      );
      expect(
        result.createdAt.isBefore(
          after.add(const Duration(seconds: 2)),
        ),
        isTrue,
      );
    });

    test('zero timestamp', () async {
      final message = _plaintextMessage('ts-7', 7, createdAt: 0);

      final results = await se.decryptMessages([message]);

      expect(results, hasLength(1));
      final result = results[0];
      expect(result, isNotNull);
      expect(
        result!.createdAt,
        equals(DateTime.fromMillisecondsSinceEpoch(0)),
      );
    });
  });
}
