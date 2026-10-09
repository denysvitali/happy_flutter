import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

/// A chat pushed over another chat (notification tap, sidebar, loops) takes
/// the visible-session slot. Closing it must hand the slot back to the chat
/// underneath: that chat is on screen again, and without ownership it gets no
/// resume refresh and no message queue until the user sends something.
void main() {
  late Sync sync;
  var n = 0;
  late String covered;
  late String top;
  late Map<String, int> serverLastSeq;

  setUp(() {
    sync = Sync();
    final stamp = '${++n}-${DateTime.now().microsecondsSinceEpoch}';
    covered = 'covered-$stamp';
    top = 'top-$stamp';
    sync.encryption = _FakeEncryption();
    sync.testIsInitialized = true;
    sync.testSocketConnectedOverride = true;
    sync.testSocketSendOverride = (_, __) {};
    sync.testSessions.clear();
    _stubAllSyncs(sync);
    sync.testResetLastResumeAtMs();
    sync.testSetVisibleSessionId(null);
    InvalidateSync.isBackgrounded = false;

    // The catalog's lastSeq stays at what the app knew before backgrounding;
    // only the message API knows about rows written since.
    sync.testSessions[covered] = _makeSession(covered, lastSeq: 10);
    sync.testSessions[top] = _makeSession(top, lastSeq: 3);
    serverLastSeq = {covered: 10, top: 3};
    sync.testFetchMessagesOverride = (sessionId, afterSeq, limit) async {
      return _buildMessagesResponse([
        for (var i = afterSeq + 1; i <= (serverLastSeq[sessionId] ?? 0); i++)
          _makeEncryptedMessage('$sessionId-$i', seq: i),
      ]);
    };
  });

  tearDown(() async {
    await sync.onSessionInvisible(top);
    await sync.onSessionInvisible(covered);
    sync.testFetchMessagesOverride = null;
    sync.testSetVisibleSessionId(null);
    InvalidateSync.isBackgrounded = false;
  });

  Future<void> settle([int ms = 300]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> openChat(String sessionId) async {
    sync.claimSessionVisibility(sessionId);
    await sync.onSessionVisible(sessionId);
    await settle();
  }

  test('SyncVisibility_CloseTopChat_RestoresCoveredChat', () async {
    await openChat(covered);
    expect(sync.messagesForSession(covered), hasLength(10));

    await openChat(top);
    expect(sync.testGetVisibleSessionId(), top);

    await sync.onSessionInvisible(top);
    await settle();

    expect(sync.testGetVisibleSessionId(), covered);
    expect(sync.messagesSync.containsKey(covered), isTrue);
  });

  test(
    'SyncVisibility_CloseTopChat_AfterBackground_FetchesCoveredChat',
    () async {
      await openChat(covered);
      await openChat(top);

      sync.suspend();
      await settle(100);
      // The covered session's agent kept working while the app was away.
      serverLastSeq[covered] = 25;
      sync.resume();
      await settle(1500);

      // Back out of the top chat to the one that was open before.
      await sync.onSessionInvisible(top);
      await settle(1500);

      expect(sync.testGetVisibleSessionId(), covered);
      expect(sync.messagesForSession(covered), hasLength(25));
    },
  );

  test('SyncVisibility_CloseOnlyChat_ClearsVisibleSession', () async {
    await openChat(covered);

    await sync.onSessionInvisible(covered);
    await settle();

    expect(sync.testGetVisibleSessionId(), isNull);
    expect(sync.messagesSync.containsKey(covered), isFalse);
  });

  test('SyncVisibility_CloseCoveredChat_KeepsTopChatVisible', () async {
    await openChat(covered);
    await openChat(top);

    await sync.onSessionInvisible(covered);
    await settle();

    expect(sync.testGetVisibleSessionId(), top);
    expect(sync.messagesSync.containsKey(top), isTrue);
  });
}

Session _makeSession(String id, {int lastSeq = 0}) => Session(
  id: id,
  seq: 1,
  createdAt: 1700000000000,
  updatedAt: 1700000000000,
  active: true,
  activeAt: 1700000000000,
  metadataVersion: 1,
  agentStateVersion: 1,
  thinking: false,
  presence: 'offline',
  lastSeq: lastSeq,
);

Map<String, dynamic> _makeEncryptedMessage(String id, {required int seq}) {
  final payload = jsonEncode({
    'role': 'agent',
    'content': {
      'type': 'output',
      'data': {
        'type': 'assistant',
        'message': {'content': 'msg $id'},
      },
    },
  });
  final bytes = utf8.encode(payload);
  final out = Uint8List(bytes.length + 1)..[0] = 0x01;
  out.setRange(1, out.length, bytes);
  return {
    'id': id,
    'seq': seq,
    'role': 'agent',
    'content': {'t': 'encrypted', 'c': base64Encode(out)},
    'createdAt': 1700000000000 + seq * 1000,
  };
}

Map<String, dynamic> _buildMessagesResponse(List<Map<String, dynamic>> m) => {
  'messages': m,
  'hasMore': false,
};

void _stubAllSyncs(Sync instance) {
  try {
    instance.sessionsSync.dispose();
  } on Error {
    // ignore
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

class _FakeEncryption implements Encryption {
  final Map<String, _FakeSessionEncryption> _sessions = {};
  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      _sessions.putIfAbsent(
        sessionId,
        () => _FakeSessionEncryption(sessionId: sessionId),
      );
  @override
  String generateId() => 'l-${DateTime.now().microsecondsSinceEpoch}';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSessionEncryption extends SessionEncryption {
  _FakeSessionEncryption({required String sessionId})
    : super(
        sessionId: sessionId,
        encryptor: _FakeEncryptor(),
        decryptor: _FakeEncryptor(),
        cache: EncryptionCache(),
      );
}

class _FakeEncryptor implements Encryptor {
  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async => data.map((item) {
    final bytes = utf8.encode(jsonEncode(item));
    return Uint8List(bytes.length + 1)
      ..[0] = 0x01
      ..setRange(1, bytes.length + 1, bytes);
  }).toList();
  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async => data.map((item) {
    if (item.isEmpty) return null;
    try {
      return item[0] == 0x01
          ? jsonDecode(utf8.decode(item.sublist(1)))
          : utf8.decode(item);
    } catch (_) {
      return null;
    }
  }).toList();
}
