import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/message_invariant_monitor.dart';

import '../helpers/test_helpers.dart';

/// Production burst, build 267200 (Loki 2026-08-25): a fetch page replayed
/// 100+ known localIds from one session while the resident window held only
/// a newer tail. The status sweep treated each replayed row as an ack and
/// reported every known id as an `unmatched_optimistic` breach.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> serverUserRow(int seq) => {
    'id': 'server-$seq',
    'localId': 'local-$seq',
    'seq': seq,
    'createdAt': 1700000000000 + seq,
    'role': 'user',
    'kind': 'text',
    'content': 'message $seq',
    'sendStatus': 'sent',
  };

  test('a truncated cache window does not turn replayed history into '
      'unmatched optimistic rows', () async {
    final sync = createTestSync();
    addTearDown(() => sync.testFetchMessagesOverride = null);
    addTearDown(sync.messageInvariantMonitor.reset);
    addTearDown(sync.testClearAllSessionMessageState);
    const sessionId = 'sess-cache-truncated-ack';
    sync.testIsInitialized = true;
    sync.messageInvariantMonitor.reset();
    sync.testClearSessionMessageState(sessionId);
    sync.testSessions[sessionId] = Session(
      id: sessionId,
      seq: 120,
      createdAt: 1700000000000,
      updatedAt: 1700000000000,
      active: true,
      activeAt: 1700000000000,
      metadataVersion: 1,
      agentStateVersion: 1,
      thinking: false,
    );
    sync.encryption = _FakeEncryption(_SilentSessionEncryption());

    // The exact restart sequence: ids are known before the page arrives,
    // but only the newest tail is resident when the sweep runs.
    for (var seq = 1; seq <= 200; seq++) {
      sync.messageInvariantMonitor.seedSentLocalId('local-$seq');
    }
    sync.testSetSessionMessages(sessionId, [
      serverUserRow(101),
      serverUserRow(102),
    ]);
    expect(sync.messagesForSession(sessionId), hasLength(2));

    sync.testFetchMessagesOverride = (_, __, ___) async {
      return <String, dynamic>{
        'messages': [for (var seq = 1; seq <= 200; seq++) serverUserRow(seq)],
        'pagination': <String, dynamic>{'hasMore': false},
      };
    };

    await sync.fetchMessages(sessionId);
    await Future<void>.delayed(Duration.zero);

    final counters = sync.messageInvariantMonitor.counters;
    expect(counters[MessageInvariant.unmatchedOptimistic.tag], 0);
    expect(counters[MessageInvariant.unknownAckedLocalId.tag], 0);
    expect(counters[MessageInvariant.duplicateLocalId.tag], 0);
    expect(sync.messagesForSession(sessionId), hasLength(200));
    expect(sync.messagesForSession(sessionId).last['id'], 'server-200');
  });
}

class _FakeEncryption implements Encryption {
  const _FakeEncryption(this.sessionEncryption);

  final SessionEncryption sessionEncryption;

  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      sessionEncryption;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SilentSessionEncryption implements SessionEncryption {
  const _SilentSessionEncryption();

  @override
  bool get canDecryptAes => false;

  @override
  Future<ProcessedMessages> decryptAndProcessMessages(
    List<Map<String, dynamic>> messages,
    String sessionId,
  ) async {
    return ProcessedMessages(
      messages: messages,
      toolResults: const [],
      usageUpdates: const [],
      maxSeq: messages.isEmpty ? 0 : messages.last['seq'] as int? ?? 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
