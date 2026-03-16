import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/aes_gcm.dart';
import 'package:happy_flutter/core/encryption/base64.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';

void main() {
  group('SessionEncryption.decryptAndProcessMessages', () {
    late Uint8List key;
    late AES256Encryption encryptor;
    late SessionEncryption sessionEncryption;

    setUp(() {
      key = _generateKey();
      encryptor = AES256Encryption(key);
      sessionEncryption = SessionEncryption(
        sessionId: 'test-session',
        encryptor: encryptor,
        decryptor: encryptor,
        cache: EncryptionCache(),
      );
    });

    test(
      'decryptAndProcessMessages returns one ProcessedMessage per input',
      () async {
        const count = 3;
        final wireMessages = <Map<String, dynamic>>[];

        for (var i = 0; i < count; i++) {
          wireMessages.add(
            await _encryptedWireMessage(
              encryptor,
              'msg-$i',
              i + 1,
              {
                'role': 'user',
                'content': {'type': 'text', 'text': 'Hello $i'},
              },
            ),
          );
        }

        final result = await sessionEncryption.decryptAndProcessMessages(
          wireMessages,
          'test-session',
        );

        expect(result, isA<ProcessedMessages>());
        expect(result.messages, hasLength(count));
      },
    );

    test(
      'decryptAndProcessMessages preserves message IDs and sequence',
      () async {
        final wireMessages = <Map<String, dynamic>>[];

        final ids = ['alpha', 'beta', 'gamma'];
        final seqs = [10, 20, 30];

        for (var i = 0; i < ids.length; i++) {
          wireMessages.add(
            await _encryptedWireMessage(
              encryptor,
              ids[i],
              seqs[i],
              {
                'role': 'user',
                'content': {'type': 'text', 'text': 'Message $i'},
              },
            ),
          );
        }

        final result = await sessionEncryption.decryptAndProcessMessages(
          wireMessages,
          'test-session',
        );

        expect(result.messages, hasLength(ids.length));

        for (var i = 0; i < ids.length; i++) {
          final msg = result.messages[i];
          expect(
            msg['id'],
            ids[i],
            reason: 'message[$i] id should be ${ids[i]}',
          );
          expect(
            msg['seq'],
            seqs[i],
            reason: 'message[$i] seq should be ${seqs[i]}',
          );
        }

        // maxSeq should equal the highest seq value
        expect(result.maxSeq, 30);
      },
    );

    test(
      'decryptAndProcessMessages with large batch (was isolate threshold)',
      () async {
        // The old code had an Isolate.run() threshold at 5 messages which
        // silently failed on Android, returning empty results. This test
        // uses 10+ messages to exercise the path that previously triggered
        // isolate dispatch and verify every message is processed.
        const count = 12;
        final wireMessages = <Map<String, dynamic>>[];

        for (var i = 0; i < count; i++) {
          wireMessages.add(
            await _encryptedWireMessage(
              encryptor,
              'batch-msg-$i',
              i + 1,
              {
                'role': 'user',
                'content': {'type': 'text', 'text': 'Batch message $i'},
              },
            ),
          );
        }

        final result = await sessionEncryption.decryptAndProcessMessages(
          wireMessages,
          'test-session',
        );

        expect(
          result.messages,
          hasLength(count),
          reason:
              'All $count messages must be processed — the old Isolate.run() '
              'path silently dropped results on Android',
        );

        // Every message should have a valid id and seq, and none should
        // be a decryption-error placeholder.
        for (var i = 0; i < count; i++) {
          final msg = result.messages[i];
          expect(
            msg['kind'],
            isNot('error'),
            reason: 'message[$i] should not be a decryption error',
          );
          expect(
            msg['id'],
            'batch-msg-$i',
            reason: 'message[$i] id should be batch-msg-$i',
          );
          expect(
            msg['seq'],
            i + 1,
            reason: 'message[$i] seq should be ${i + 1}',
          );
        }

        expect(result.maxSeq, count);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Uint8List _generateKey() {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(32, (_) => random.nextInt(256)),
  );
}

/// Build a wire-format message map with AES-256-GCM-encrypted content.
///
/// [encryptor] must be an [AES256Encryption] whose key will also be used
/// by the [SessionEncryption] under test.  The encrypted bytes are
/// base64-encoded and wrapped in the standard `{'t':'encrypted','c':'<b64>'}`
/// envelope that [SessionEncryption.decryptMessages] expects.
Future<Map<String, dynamic>> _encryptedWireMessage(
  AES256Encryption encryptor,
  String id,
  int seq,
  Map<String, dynamic> content,
) async {
  // AES256Encryption.encrypt returns a list of Uint8List where each item
  // has the 1-byte version prefix prepended — exactly what
  // AES256Encryption.decrypt expects.
  final encryptedList = await encryptor.encrypt([content]);
  final b64 = Base64Utils.encode(encryptedList[0], Encoding.base64);
  return {
    'id': id,
    'seq': seq,
    'content': {'t': 'encrypted', 'c': b64},
    'createdAt': 1700000000000,
  };
}
