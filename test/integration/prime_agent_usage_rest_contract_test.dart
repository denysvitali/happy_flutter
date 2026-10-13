import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

import 'fake_session_encryption.dart';
import 'mock_sync_server.dart';

void main() {
  const sessionId = 'prime-usage-rest';
  late Sync instance;
  late MockSyncServer server;

  setUp(() async {
    instance = Sync()
      ..encryption = _FakeEncryption()
      ..testIsInitialized = true
      ..testSocketConnectedOverride = true
      ..testSocketSendOverride = (_, _) {}
      ..testFetchMessagesOverride = null
      ..testResetDataChangeDebounce()
      ..testClearSessionMessageState(sessionId)
      ..sessionsSync = InvalidateSync(() async {})
      ..settingsSync = InvalidateSync(() async {})
      ..profileSync = InvalidateSync(() async {})
      ..purchasesSync = InvalidateSync(() async {})
      ..machinesSync = InvalidateSync(() async {})
      ..pushTokenSync = InvalidateSync(() async {})
      ..nativeUpdateSync = InvalidateSync(() async {})
      ..artifactsSync = InvalidateSync(() async {})
      ..sessionGitStatusSync = InvalidateSync(() async {})
      ..testSetVisibleSessionId(sessionId)
      ..testSetSessionUsage(sessionId, {})
      ..testSetSessionLastSeq(sessionId, 1)
      ..testSetSessionMessages(sessionId, [
        {
          'id': 'parent-answer',
          'seq': 1,
          'kind': 'text',
          'role': 'agent',
          'content': 'Parent answer',
          'createdAt': 1000,
        },
      ]);
    server = MockSyncServer();
    await server.setUp();
    server.stubMessages(sessionId, []);
  });

  tearDown(() async {
    instance
      ..testSetVisibleSessionId(null)
      ..testSocketConnectedOverride = null
      ..testSocketSendOverride = null
      ..testFetchMessagesOverride = null
      ..testClearSessionMessageState(sessionId)
      ..testResetDataChangeDebounce()
      ..testSessions.remove(sessionId);
    await server.tearDown();
  });

  test(
    'usage-only REST pages notify initial context, compaction, and clear',
    () async {
      var seq = 1;
      for (final used in <int?>[11978, 50, null]) {
        seq++;
        instance.testSessions[sessionId] = Session(
          id: sessionId,
          seq: seq,
          createdAt: 1000,
          updatedAt: 1000 + seq,
          active: true,
          activeAt: 1000,
          metadataVersion: 1,
          agentStateVersion: 1,
          thinking: false,
          presence: 'online',
          lastSeq: seq,
          metadata: const Metadata(
            flavor: 'prime-agent',
            model: 'openai-codex/gpt-6-luna',
          ),
        );
        server.appendStubbedMessage(sessionId, _usageMessage(seq, used));
        final notification = instance.onSessionMessagesChanged
            .where((id) => id == sessionId)
            .first
            .timeout(const Duration(seconds: 2));
        await instance.fetchMessages(sessionId);
        expect(await notification, sessionId);
        expect(instance.sessionUsage[sessionId]!['contextSize'], used);
        expect(
          instance.sessionUsage[sessionId]!['contextWindow'],
          used == null ? null : 500000,
        );
        expect(instance.sessionUsage[sessionId]!['timestamp'], 1000 + seq);
        expect(instance.messagesForSession(sessionId), hasLength(1));
        expect(
          instance.messagesForSession(sessionId).single['content'],
          'Parent answer',
        );
      }
      expect(server.messageRequestLog, [1, 2, 3]);
    },
  );

  test(
    'usage-only REST batch accepts known usage after same-time clear',
    () async {
      instance.testSessions[sessionId] = const Session(
        id: sessionId,
        seq: 3,
        createdAt: 1000,
        updatedAt: 2000,
        active: true,
        activeAt: 1000,
        metadataVersion: 1,
        agentStateVersion: 1,
        thinking: false,
        presence: 'online',
        lastSeq: 3,
        metadata: Metadata(
          flavor: 'prime-agent',
          model: 'openai-codex/gpt-6-luna',
        ),
      );
      server
        ..appendStubbedMessage(
          sessionId,
          _usageMessage(2, null, createdAt: 2000),
        )
        ..appendStubbedMessage(
          sessionId,
          _usageMessage(3, 11978, createdAt: 2000),
        );
      final notification = instance.onSessionMessagesChanged
          .where((id) => id == sessionId)
          .first
          .timeout(const Duration(seconds: 2));
      await instance.fetchMessages(sessionId);
      expect(await notification, sessionId);
      expect(instance.sessionUsage[sessionId]!['contextSize'], 11978);
      expect(instance.sessionUsage[sessionId]!['contextWindow'], 500000);
      expect(instance.sessionUsage[sessionId]!['timestamp'], 2000);
      expect(instance.sessionUsage[sessionId]!['seq'], 3);
      expect(instance.messagesForSession(sessionId), hasLength(1));
      expect(server.messageRequestLog, [1]);
    },
  );
}

Map<String, dynamic> _usageMessage(int seq, int? used, {int? createdAt}) {
  final envelope = {
    'role': 'agent',
    'content': {
      'type': 'acp',
      'data': {
        'type': 'usage',
        'usage': {
          'context_size': used,
          'context_window': used == null ? null : 500000,
          'input_tokens': 139982,
          'source': 'prime-agent-daemon',
          'scope': 'session',
          'model': 'gpt-6-luna',
          'provider': 'openai-codex',
        },
      },
    },
  };
  final encoded = Uint8List.fromList([
    0x01,
    ...utf8.encode(jsonEncode(envelope)),
  ]);
  return {
    'id': 'usage-$seq',
    'seq': seq,
    'createdAt': createdAt ?? 1000 + seq,
    'content': {'t': 'encrypted', 'c': base64Encode(encoded)},
  };
}

class _FakeEncryption implements Encryption {
  final Map<String, FakeSessionEncryption> _sessions = {};

  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      _sessions.putIfAbsent(
        sessionId,
        () => FakeSessionEncryption(sessionId: sessionId),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
