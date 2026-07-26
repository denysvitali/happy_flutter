import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/services/failure_telemetry.dart';
import 'package:happy_flutter/core/services/message_processing_service.dart';
import 'package:happy_flutter/core/services/opentelemetry_service.dart';

/// One observed `recordCount` call.
class _Count {
  _Count(this.name, this.value, this.attributes);
  final String name;
  final int value;
  final Map<String, Object?> attributes;

  @override
  String toString() => '$name x$value $attributes';
}

/// A decryptor that always fails, so `decryptMessages` takes the
/// null-content path for every item without needing libsodium/PointyCastle.
class _AlwaysFailsDecryptor implements Encryptor {
  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async =>
      List<Uint8List>.filled(data.length, Uint8List(0));

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async =>
      List<dynamic>.filled(data.length, null);
}

Map<String, dynamic> _encryptedWire(int seq) => <String, dynamic>{
      'id': 'msg-$seq',
      'seq': seq,
      'localId': 'local-$seq',
      'createdAt': 1700000000000,
      'content': <String, dynamic>{'t': 'encrypted', 'c': 'AAAA'},
    };

void main() {
  late List<_Count> counts;

  setUp(() {
    counts = <_Count>[];
    OpenTelemetryService.debugCountSink = (name, value, attributes) {
      counts.add(_Count(name, value, attributes));
    };
  });

  tearDown(() {
    OpenTelemetryService.debugCountSink = null;
  });

  List<_Count> named(String name) =>
      counts.where((c) => c.name == name).toList();

  SessionEncryption makeSession(EncryptionCache cache) => SessionEncryption(
        sessionId: 'sess-abc123',
        encryptor: _AlwaysFailsDecryptor(),
        decryptor: _AlwaysFailsDecryptor(),
        cache: cache,
      );

  group('app.crypto.decrypt_failures', () {
    test('is emitted once per batch with the batch failure count', () async {
      final enc = makeSession(EncryptionCache());
      final wire = List.generate(25, _encryptedWire);

      final results = await enc.decryptMessages(wire);

      // Behaviour is unchanged: every message still comes back with
      // null content so the UI keeps rendering its error bubble.
      expect(results.length, 25);
      expect(results.every((r) => r != null && r.content == null), isTrue);

      final fresh = named(kDecryptFailuresMetric)
          .where((c) => c.attributes['from_cache'] == false)
          .toList();

      // THE POINT OF THIS TEST: exactly one counter add for 25 failures,
      // not 25. Removing the recordDecryptFailure call from
      // SessionEncryption.decryptMessages makes this fail with length 0.
      expect(fresh.length, 1, reason: 'expected one batch-level add, got $counts');
      expect(fresh.single.value, 25);
      expect(fresh.single.attributes['stage'], kStageMessages);
      expect(fresh.single.attributes['envelope'], kEnvelopeNacl);
    });

    test('never emits when nothing failed', () async {
      final enc = makeSession(EncryptionCache());

      await enc.decryptMessages(<Map<String, dynamic>>[]);

      expect(named(kDecryptFailuresMetric), isEmpty);
    });

    test('separates memoized failures from fresh ones', () async {
      final cache = EncryptionCache();
      final enc = makeSession(cache);
      final wire = List.generate(3, _encryptedWire);

      await enc.decryptMessages(wire);
      counts.clear();

      // Second pass hits the memoized null-content entries.
      await enc.decryptMessages(wire);

      final emitted = named(kDecryptFailuresMetric);
      expect(emitted.length, 1);
      expect(emitted.single.attributes['from_cache'], true);
      expect(emitted.single.value, 3);
    });

    test('attribute values stay inside the closed vocabularies', () async {
      final enc = makeSession(EncryptionCache());
      await enc.decryptMessages(List.generate(2, _encryptedWire));

      for (final c in named(kDecryptFailuresMetric)) {
        expect(
          c.attributes['envelope'],
          isIn(<String>[kEnvelopeAes, kEnvelopeNacl, kEnvelopeUnknown]),
        );
        expect(
          c.attributes['stage'],
          isIn(<String>[
            kStageMessages,
            kStageMetadata,
            kStageAgentState,
            kStageDek,
            kStageRaw,
            kStageUnknown,
          ]),
        );
        expect(c.attributes['from_cache'], isA<bool>());
        // No id, no localId, no raw exception text ever reaches an
        // attribute value.
        for (final v in c.attributes.values) {
          expect(v.toString(), isNot(contains('sess-abc123')));
          expect(v.toString(), isNot(contains('msg-')));
          expect(v.toString(), isNot(contains('local-')));
        }
      }
    });
  });

  group('app.messages.undecryptable_rendered', () {
    test('counts rendered error bubbles once per batch', () async {
      final wire = List.generate(4, _encryptedWire);

      final processed = await processDecryptedMessagesWithIsolation(
        decryptedJsonList: List<dynamic>.filled(4, null),
        wireMessages: wire,
        sessionId: 'sess-abc123',
        wasEncrypted: List<bool>.filled(4, true),
        useIsolate: false,
      );

      // Behaviour unchanged: the error bubbles are still built.
      expect(processed.messages.length, 4);
      expect(
        processed.messages.every((m) => m['errorType'] == 'decryption_failed'),
        isTrue,
      );

      final emitted = named(kUndecryptableRenderedMetric);
      expect(emitted.length, 1);
      expect(emitted.single.value, 4);
      expect(emitted.single.attributes['error_type'], 'decryption_failed');
    });

    test('is silent when every message decrypted', () async {
      final processed = await processDecryptedMessagesWithIsolation(
        decryptedJsonList: <dynamic>[
          <String, dynamic>{'role': 'user', 'content': 'hi'},
        ],
        wireMessages: <Map<String, dynamic>>[_encryptedWire(1)],
        sessionId: 'sess-abc123',
        wasEncrypted: <bool>[true],
        useIsolate: false,
      );

      expect(processed.undecryptableRenderedCount, 0);
      expect(named(kUndecryptableRenderedMetric), isEmpty);
    });
  });

  group('classifySyncFailureReason', () {
    test('buckets into the closed reason vocabulary', () {
      const allowed = <String>[
        kReasonHttp,
        kReasonDecrypt,
        kReasonParse,
        kReasonDisposed,
        kReasonTimeout,
      ];
      final samples = <Object>[
        const FormatException('bad base64 AAAA'),
        StateError('Tried to use it after dispose()'),
        StateError('something else entirely'),
        Exception('a totally novel failure 12345'),
        ArgumentError('nope'),
      ];
      for (final s in samples) {
        expect(classifySyncFailureReason(s), isIn(allowed));
      }
      expect(
        classifySyncFailureReason(StateError('used after dispose')),
        kReasonDisposed,
      );
    });
  });

  group('decryptStageFromScope', () {
    test('drops the embedded id and maps onto bounded stages', () {
      expect(decryptStageFromScope('session:abc123:messages'), kStageMessages);
      expect(decryptStageFromScope('session:abc123:metadata'), kStageMetadata);
      expect(
        decryptStageFromScope('session:abc123:agent-state'),
        kStageAgentState,
      );
      expect(
        decryptStageFromScope('machine:abc123:daemon-state'),
        kStageAgentState,
      );
      expect(decryptStageFromScope('session:abc123:raw'), kStageRaw);
      expect(decryptStageFromScope(null), kStageUnknown);
      expect(decryptStageFromScope('rpc:some-route'), kStageUnknown);
    });
  });

  group('ProcessedMessages', () {
    test('defaults the new count to zero for existing constructors', () {
      const p = ProcessedMessages(
        messages: <Map<String, dynamic>>[],
        toolResults: <Map<String, dynamic>>[],
        usageUpdates: <Map<String, dynamic>>[],
        maxSeq: -1,
      );
      expect(p.undecryptableRenderedCount, 0);
    });
  });
}
