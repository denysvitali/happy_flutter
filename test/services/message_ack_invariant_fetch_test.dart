// Contract tests for which server rows count as a *send ack*.
//
// `fetchMessages` walks every row of every history page and calls
// `_updateMessageSendStatus(sessionId, localId, 'sent')` so a pending local
// row flips to "sent" when the server confirms it. That loop sees EVERY
// stored `localId`, including ones minted by another device or a previous
// install — rows this client never sent and has no placeholder for.
//
// Counting those as acks produced bursts of false `unknown_acked_local_id`
// violations in production (300 in one paging burst on build 264100, Loki
// 2026-08-24), which made the P0 messaging invariant counter unalertable and
// spammed Sentry. These tests pin that history replay is silent while every
// real breach still reports.

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/message_invariant_monitor.dart';

import '../helpers/test_helpers.dart';

/// Decrypts nothing: these tests exercise the pre-ingest status loop, which
/// runs on the raw page rows before decryption output is merged.
class _SilentSessionEncryption implements SessionEncryption {
  _SilentSessionEncryption(this.maxSeq);

  final int maxSeq;

  @override
  Future<ProcessedMessages> decryptAndProcessMessages(
    List<Map<String, dynamic>> messages,
    String sessionId,
  ) async {
    return ProcessedMessages(
      messages: const [],
      toolResults: const [],
      usageUpdates: const [],
      maxSeq: maxSeq,
      droppedReasons: const [],
    );
  }

  @override
  bool get canDecryptAes => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEncryption implements Encryption {
  _FakeEncryption(this._sessionEncryption);

  final SessionEncryption _sessionEncryption;

  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      _sessionEncryption;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('history fetch is not a send ack', () {
    late Sync instance;
    const sessionId = 'sess-history-ack';

    int countFor(MessageInvariant invariant) =>
        instance.messageInvariantMonitor.counters[invariant.tag] ?? -1;

    setUp(() {
      instance = createTestSync();
      instance.messageInvariantMonitor.reset();
      instance.testIsInitialized = true;
      instance.testVisibleSessionId = sessionId;
      instance.testClearSessionMessageState(sessionId);
      instance.testSessions[sessionId] = Session(
        id: sessionId,
        seq: 3,
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
        active: true,
        activeAt: 1700000000000,
        metadataVersion: 1,
        agentStateVersion: 1,
        thinking: false,
        presence: 'online',
      );
      instance.encryption = _FakeEncryption(_SilentSessionEncryption(3));
    });

    /// Production sessions always have a resident row list; without one
    /// `_updateMessageSendStatus` returns before the ack tap and the bug
    /// under test cannot reproduce.
    void seedResidentRow() {
      instance.testSetSessionMessages(sessionId, [
        {
          'id': 'unrelated',
          'localId': 'unrelated-local',
          'seq': 1,
          'role': 'user',
          'kind': 'text',
          'content': 'hi',
          'sendStatus': 'sent',
        },
      ]);
    }

    tearDown(() {
      instance.testFetchMessagesOverride = null;
      instance.messageInvariantMonitor.reset();
    });

    test('a page of localIds this client never minted records zero '
        'violations', () async {
      seedResidentRow();
      instance.testFetchMessagesOverride = (_, __, ___) async {
        return <String, dynamic>{
          'messages': <Map<String, dynamic>>[
            {'id': 'm1', 'seq': 1, 'localId': 'other-device-1'},
            {'id': 'm2', 'seq': 2, 'localId': 'other-device-2'},
            {'id': 'm3', 'seq': 3, 'localId': 'previous-install-3'},
          ],
          'pagination': <String, dynamic>{'hasMore': false},
        };
      };

      await instance.fetchMessages(sessionId);
      await Future<void>.delayed(Duration.zero);

      expect(
        countFor(MessageInvariant.unknownAckedLocalId),
        0,
        reason: 'foreign localIds are server truth, not acks of our sends',
      );
      expect(instance.messageInvariantMonitor.totalViolations, 0);
    });

    test('paging the same foreign ids again stays silent', () async {
      seedResidentRow();
      var page = 0;
      instance.testFetchMessagesOverride = (_, __, ___) async {
        page++;
        return <String, dynamic>{
          'messages': <Map<String, dynamic>>[
            {'id': 'm$page', 'seq': page, 'localId': 'other-device-$page'},
          ],
          'pagination': <String, dynamic>{'hasMore': false},
        };
      };

      await instance.fetchMessages(sessionId);
      await instance.fetchMessages(sessionId);
      await Future<void>.delayed(Duration.zero);

      expect(instance.messageInvariantMonitor.totalViolations, 0);
    });

    test(
      'a locally minted server row merges without a false violation',
      () async {
        // History is server truth. The pre-page sweep seeds identity but must
        // not ack before the page merge; the resident row then proves the
        // canonical mapping survived.
        instance.messageInvariantMonitor.recordOptimisticSent('ours-1');
        seedResidentRow();
        instance.testFetchMessagesOverride = (_, __, ___) async {
          return <String, dynamic>{
            'messages': <Map<String, dynamic>>[
              {'id': 'm1', 'seq': 1, 'localId': 'ours-1'},
            ],
            'pagination': <String, dynamic>{'hasMore': false},
          };
        };

        await instance.fetchMessages(sessionId);
        await Future<void>.delayed(Duration.zero);

        expect(countFor(MessageInvariant.unmatchedOptimistic), 0);
        expect(countFor(MessageInvariant.unknownAckedLocalId), 0);
      },
    );

    test('two resident rows sharing one localId still report '
        'duplicate_local_id on the real ack path', () {
      // History pages are not acks; duplicate detection remains on the
      // actual REST/socket acknowledgement path.
      instance.testSetSessionMessages(sessionId, [
        {
          'id': 'local-a',
          'localId': 'dupe-1',
          'seq': 1,
          'role': 'user',
          'kind': 'text',
          'content': 'hi',
          'sendStatus': 'sending',
        },
        {
          'id': 'local-b',
          'localId': 'dupe-1',
          'seq': 2,
          'role': 'user',
          'kind': 'text',
          'content': 'hi',
          'sendStatus': 'sending',
        },
      ]);
      final optimisticRowCount = instance
          .messagesForSession(sessionId)
          .where((m) => m['localId'] == 'dupe-1')
          .length;

      instance.messageInvariantMonitor.seedSentLocalId('dupe-1');
      instance.messageInvariantMonitor.recordAck(
        localId: 'dupe-1',
        optimisticRowCount: optimisticRowCount,
        sessionId: sessionId,
      );

      expect(
        countFor(MessageInvariant.duplicateLocalId),
        1,
        reason: 'resident rows make this observable regardless of who sent it',
      );
    });
  });

  group('MessageInvariantMonitor.isKnownLocalId', () {
    test('is true only for minted or seeded ids', () {
      final monitor = MessageInvariantMonitor();
      expect(monitor.isKnownLocalId('never-seen'), isFalse);
      monitor.recordOptimisticSent('minted');
      expect(monitor.isKnownLocalId('minted'), isTrue);
      monitor.seedSentLocalId('restored');
      expect(monitor.isKnownLocalId('restored'), isTrue);
      expect(monitor.isKnownLocalId(''), isFalse);
    });
  });
}
