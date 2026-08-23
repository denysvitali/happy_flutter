import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/logger_service.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

/// Contract tests for the coalesced inline socket drain.
///
/// A synchronous burst of new-message events for one visible session must
/// be drained as ONE pipeline invocation: one decrypt batch, one
/// `_upsertSessionMessages` merge, one notification wave — while preserving
/// FIFO order, cursor/gap semantics, and per-event dedup identity.
void main() {
  group('coalesced inline socket drain', () {
    late Sync sync;
    late _GatedEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _GatedEncryption();

      for (final id in sync.sessionMessages.keys.toList()) {
        sync.testSetSessionMessages(id, []);
      }
      for (final id in sync.testSessions.keys.toList()) {
        sync.testSetSessionLastSeq(id, 0);
      }
      sync.testSessions.clear();
      sync.testClearSessionsWithPendingSocketMessages();

      _stubAllSyncs(sync);

      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testFetchMessagesOverride = (_, __, ___) async => {
            'messages': <Map<String, dynamic>>[],
            'hasMore': false,
          };
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
      sync.testVisibleSessionId = null;
      LoggerService().clear();
    });

    test(
      'burst of 40 socket messages drains as ONE merge: '
      'resident count == 40, seq order preserved, zero duplicates',
      () async {
        const sessionId = 'batch-drain-burst';
        const burst = 40;

        sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 101);
        // One resident row so the burst rides the append fast path —
        // the production hot shape (existing transcript + burst).
        sync.testSetSessionMessages(sessionId, [
          {
            'id': 'msg-101',
            'seq': 101,
            'role': 'agent',
            'kind': 'text',
            'content': 'Resident',
            'createdAt': 1700000101000,
          },
        ]);
        sync.testSetSessionLastSeq(sessionId, 101);
        sync.testVisibleSessionId = sessionId;
        sync.messagesSync[sessionId] = InvalidateSync(
          () => sync.fetchMessages(sessionId),
        );
        LoggerService().clear();

        // One synchronous turn: all events buffer before any drain runs.
        for (var i = 1; i <= burst; i++) {
          final seq = 101 + i;
          sync.handleUpdate({
            't': 'new-message',
            'sid': sessionId,
            'message': _makeEncryptedMessage(
              'msg-$seq',
              seq: seq,
              content: 'Burst message $seq',
            ),
          });
        }

        await _waitForMessageCount(sync, sessionId, burst);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Exactly ONE pipeline invocation: one decrypt batch carrying all
        // 40 payloads.
        expect(
          encryption.decryptCalls,
          hasLength(1),
          reason:
              'the whole burst must be decrypted as a single batch, got '
              '${encryption.decryptCalls.length} invocations with sizes '
              '${encryption.decryptCalls.map((c) => c.length).toList()}',
        );
        expect(encryption.decryptCalls.single, hasLength(burst));

        // Exactly ONE _upsertSessionMessages call (the `[messages] upsert`
        // debug line is emitted once per upsert for the visible session).
        final upsertLines = LoggerService()
            .getLogs()
            .where((e) => e.message.contains('[messages] upsert'))
            .map((e) => e.message)
            .where((m) => m.contains('session=$sessionId'))
            .toList();
        expect(
          upsertLines,
          hasLength(1),
          reason: 'one drain must produce one merge; saw: $upsertLines',
        );
        expect(upsertLines.single, contains('incoming=$burst'));
        // Codex text rows carry isPromptEchoCandidate=true, which the
        // append fast path deliberately routes to the full merge
        // (_sync_messaging_merge.dart). Batching's contract is therefore
        // ONE whole-list merge per burst, not N per-row merges.
        expect(upsertLines.single, contains('mode=merge'));

        final msgs = sync.testSessionMessages(sessionId)!;
        expect(msgs, hasLength(burst + 1));
        final ids = msgs.map((m) => m['id'] as String).toSet();
        expect(ids.length, burst + 1, reason: 'no duplicate logical messages');
        final seqs = msgs.map((m) => m['seq'] as int).toList();
        for (var i = 1; i < seqs.length; i++) {
          expect(seqs[i], greaterThan(seqs[i - 1]),
              reason: 'arrival order preserved by seq');
        }
        expect(sync.testGetSessionLastSeq(sessionId), 101 + burst);
      },
    );

    test(
      'messages arriving DURING a drain land in a follow-up drain '
      'without loss or reordering',
      () async {
        const sessionId = 'batch-drain-midflight';
        sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 10);
        sync.testSetSessionMessages(sessionId, []);
        sync.testSetSessionLastSeq(sessionId, 10);
        sync.testVisibleSessionId = sessionId;
        sync.messagesSync[sessionId] = InvalidateSync(
          () => sync.fetchMessages(sessionId),
        );

        // First five events; the decrypt of the first batch blocks on a
        // gate so the drain is observably mid-flight.
        encryption.gate = Completer<void>();
        for (var i = 11; i <= 15; i++) {
          sync.handleUpdate({
            't': 'new-message',
            'sid': sessionId,
            'message': _makeEncryptedMessage(
              'msg-$i',
              seq: i,
              content: 'First wave $i',
            ),
          });
        }

        // Wait until the first drain is suspended inside decrypt.
        while (encryption.gate == null || !encryption.insideDecrypt) {
          await Future<void>.delayed(Duration.zero);
        }

        // Arrivals during the drain.
        for (var i = 16; i <= 18; i++) {
          sync.handleUpdate({
            't': 'new-message',
            'sid': sessionId,
            'message': _makeEncryptedMessage(
              'msg-$i',
              seq: i,
              content: 'Second wave $i',
            ),
          });
        }

        // No concurrent processing for this session.
        expect(encryption.concurrentDecrypts, 1);
        encryption.releaseGate();
        await _waitForMessageCount(sync, sessionId, 8);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(encryption.concurrentDecrypts, 0);
        expect(encryption.decryptCalls, hasLength(2));
        // Second invocation carries exactly the mid-drain arrivals.
        expect(encryption.decryptCalls[1], hasLength(3));

        final msgs = sync.testSessionMessages(sessionId)!;
        expect(msgs, hasLength(8));
        expect(
          msgs.map((m) => m['id']).toSet().length,
          8,
          reason: 'mid-drain arrivals must not duplicate or evict rows',
        );
        final seqs = msgs.map((m) => m['seq'] as int).toList();
        for (var i = 1; i < seqs.length; i++) {
          expect(seqs[i], greaterThan(seqs[i - 1]));
        }
      },
    );

    test(
      'repeated identical text produces distinct logical messages '
      '(text is never identity)',
      () async {
        const sessionId = 'batch-drain-same-text';
        const count = 30;
        sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 5);
        sync.testSetSessionMessages(sessionId, []);
        sync.testSetSessionLastSeq(sessionId, 5);
        sync.testVisibleSessionId = sessionId;
        sync.messagesSync[sessionId] = InvalidateSync(
          () => sync.fetchMessages(sessionId),
        );

        for (var i = 6; i < 6 + count; i++) {
          sync.handleUpdate({
            't': 'new-message',
            'sid': sessionId,
            'message': _makeEncryptedMessage(
              'msg-$i',
              seq: i,
              content: 'continue',
            ),
          });
        }

        await _waitForMessageCount(sync, sessionId, count);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final msgs = sync.testSessionMessages(sessionId)!;
        expect(msgs, hasLength(count));
        expect(
          msgs.where((m) => m['id'] == 'continue').length,
          0,
          reason: 'identity comes from id/seq, never from text',
        );
        final ids = msgs.map((m) => m['id'] as String).toSet();
        expect(ids.length, count);
      },
    );

    test(
      'a seq gap inside the burst still schedules the pre-gap catch-up '
      'fetch and advances the cursor',
      () async {
        const sessionId = 'batch-drain-gap';
        const cursor = 200;
        sync.testSessions[sessionId] =
            _makeSession(sessionId, lastSeq: cursor);
        sync.testSetSessionMessages(sessionId, []);
        sync.testSetSessionLastSeq(sessionId, cursor);
        sync.testVisibleSessionId = sessionId;
        sync.messagesSync[sessionId] = InvalidateSync(
          () => sync.fetchMessages(sessionId),
        );

        final requestedAfterSeqs = <int>[];
        sync.testFetchMessagesOverride = (sid, afterSeq, __) async {
          if (sid == sessionId) requestedAfterSeqs.add(afterSeq);
          return {
            'messages': <Map<String, dynamic>>[],
            'hasMore': false,
          };
        };

        // Seqs 202..241 arrive inline; seq 201 is missing -> gap.
        for (var i = 202; i <= 241; i++) {
          sync.handleUpdate({
            't': 'new-message',
            'sid': sessionId,
            'message': _makeEncryptedMessage(
              'msg-$i',
              seq: i,
              content: 'After gap $i',
            ),
          });
        }

        await _waitForMessageCount(sync, sessionId, 40);
        // Allow the gap-triggered invalidate() fetch cycle to run.
        final deadline = DateTime.now().add(const Duration(seconds: 3));
        while (requestedAfterSeqs.isEmpty &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }

        expect(
          requestedAfterSeqs.any((afterSeq) => afterSeq <= cursor),
          isTrue,
          reason:
              'the missing seq 201 must schedule an authoritative fetch '
              'from at or below the pre-gap cursor $cursor; got '
              '$requestedAfterSeqs',
        );
        expect(sync.testGetSessionLastSeq(sessionId), 241);
        final msgs = sync.testSessionMessages(sessionId)!;
        expect(msgs, hasLength(40));
      },
    );

    test(
      'non-visible session bursts coalesce into one sessions-domain '
      'notification wave',
      () async {
        const sessionId = 'batch-drain-background';
        sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 7);
        sync.testSetSessionMessages(sessionId, []);
        sync.testVisibleSessionId = 'some-other-session';

        var sessionNotifications = 0;
        final sub = sync.onSessionMessagesChanged.listen((_) {
          sessionNotifications++;
        });

        for (var i = 8; i <= 27; i++) {
          sync.handleUpdate({
            't': 'new-message',
            'sid': sessionId,
            'message': _makeEncryptedMessage(
              'msg-$i',
              seq: i,
              content: 'Background $i',
            ),
          });
        }

        await _waitForMessageCount(sync, sessionId, 20);
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await sub.cancel();

        expect(sync.testSessionMessages(sessionId), hasLength(20));
        // Coalescing bounds the notification churn: far fewer than one
        // per event. The debounced stream may still fire more than once
        // across drains, so pin only the upper bound.
        expect(
          sessionNotifications,
          lessThan(5),
          reason: 'one notification wave per drain, not per message',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Future<void> _waitForMessageCount(
  Sync sync,
  String sessionId,
  int expected, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final msgs = sync.testSessionMessages(sessionId);
    if (msgs != null && msgs.length >= expected) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('session $sessionId never reached $expected resident messages');
}

Session _makeSession(String id, {int lastSeq = 10}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 1700000000000,
    updatedAt: 1700000000000,
    active: true,
    activeAt: 1700000000000,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    presence: 'online',
    lastSeq: lastSeq,
  );
}

Map<String, dynamic> _makeEncryptedMessage(
  String id, {
  required int seq,
  required String content,
}) {
  final innerContent = {
    'role': 'agent',
    'content': {
      'type': 'codex',
      'data': {'type': 'message', 'message': content},
    },
  };
  final bytes = utf8.encode(jsonEncode(innerContent));
  final output = Uint8List(bytes.length + 1);
  output[0] = 0x01;
  output.setRange(1, output.length, bytes);
  return {
    'id': id,
    'seq': seq,
    'role': 'agent',
    'content': {'t': 'encrypted', 'c': base64Encode(output)},
    'createdAt': 1700000000000 + seq * 1000,
  };
}

void _stubAllSyncs(Sync instance) {
  try {
    instance.sessionsSync.dispose();
  } on Error {
    // Not yet initialized — ignore
  }
  instance.sessionsSync = InvalidateSync(() async {});
  instance.settingsSync = InvalidateSync(() async {});
  instance.profileSync = InvalidateSync(() async {});
  instance.purchasesSync = InvalidateSync(() async {});
  instance.machinesSync = InvalidateSync(() async {});
  instance.pushTokenSync = InvalidateSync(() async {});
  instance.nativeUpdateSync = InvalidateSync(() async {});
  instance.artifactsSync = InvalidateSync(() async {});
  instance.sessionGitStatusSync = InvalidateSync(() async {});
  instance.messagesSync.clear();
}

/// Passthrough encryptor that records every decrypt invocation and can
/// block the first one so tests can inject arrivals mid-drain.
class _GatedEncryptor implements Encryptor {
  final List<List<Uint8List>> decryptCalls = [];
  Completer<void>? gate;
  int concurrentDecrypts = 0;
  bool insideDecrypt = false;

  void releaseGate() {
    gate?.complete();
  }

  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    throw UnimplementedError('inline ingest path never encrypts');
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    decryptCalls.add(data);
    concurrentDecrypts++;
    insideDecrypt = true;
    try {
      final wait = gate;
      if (wait != null && !wait.isCompleted) {
        await wait.future;
      }
      final results = <dynamic>[];
      for (final item in data) {
        if (item.isEmpty) {
          results.add(null);
          continue;
        }
        try {
          if (item[0] == 0x01) {
            results.add(jsonDecode(utf8.decode(item.sublist(1))));
          } else {
            results.add(utf8.decode(item));
          }
        } catch (_) {
          results.add(null);
        }
      }
      return results;
    } finally {
      insideDecrypt = false;
      concurrentDecrypts--;
    }
  }
}

class _GatedEncryption implements Encryption {
  final Map<String, SessionEncryption> _sessions = {};
  final _GatedEncryptor shared = _GatedEncryptor();

  Completer<void>? get gate => shared.gate;
  set gate(Completer<void>? value) => shared.gate = value;
  bool get insideDecrypt => shared.insideDecrypt;
  List<List<Uint8List>> get decryptCalls => shared.decryptCalls;
  int get concurrentDecrypts => shared.concurrentDecrypts;
  void releaseGate() => shared.releaseGate();

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return _sessions.putIfAbsent(
      sessionId,
      () => _GateSessionEncryption(sessionId: sessionId, encryptor: shared),
    );
  }

  @override
  String generateId() =>
      'test-local-${DateTime.now().microsecondsSinceEpoch}';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _GateSessionEncryption extends SessionEncryption {
  _GateSessionEncryption({
    required String sessionId,
    required Encryptor encryptor,
  }) : super(
          sessionId: sessionId,
          encryptor: encryptor,
          decryptor: encryptor,
          cache: EncryptionCache(),
        );
}
