import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/at_rest_encryption_service.dart';

void main() {
  group('AtRestEncryptionService', () {
    final key = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));

    test('authenticated envelope round-trips without exposing plaintext', () {
      final protection = AtRestEncryptionService.memoryOnly(key);

      final protected = protection.protectString(
        'sensitive-local-message',
        associatedData: 'message-cache:session-a',
      );

      expect(protected, startsWith(AtRestEncryptionService.envelopePrefix));
      expect(protected, isNot(contains('sensitive-local-message')));
      expect(
        protection.unprotectString(
          protected!,
          associatedData: 'message-cache:session-a',
        ),
        'sensitive-local-message',
      );
    });

    test('AAD prevents moving ciphertext between persistence domains', () {
      final protection = AtRestEncryptionService.memoryOnly(key);
      final protected = protection.protectString(
        'payload',
        associatedData: 'message-outbox',
      );

      expect(
        protection.unprotectString(
          protected!,
          associatedData: 'message-cache:session-a',
        ),
        isNull,
      );
    });

    test('worker key copy is zeroed after producing an envelope', () {
      final protection = AtRestEncryptionService.memoryOnly(key);
      final workerKey = protection.copyKeyForWorker()!;

      final protected = protectAtRestPayloadForWorker(
        'queued-cache-payload',
        associatedData: 'message-cache:session-a',
        key: workerKey,
      );

      expect(workerKey, everyElement(0));
      expect(
        protection.unprotectString(
          protected!,
          associatedData: 'message-cache:session-a',
        ),
        'queued-cache-payload',
      );
    });
  });
}
