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

/// A session that kept running while the app was in the background must show
/// what it wrote as soon as the user opens it.
///
/// Nothing is pushed while the socket is down, and the sessions catalog does
/// not reliably report the new rows either: its delta fetch is keyed on the
/// session row's `updated_at`, which message ingestion does not move. So
/// after a resume both the cursor and `Session.lastSeq` can still hold their
/// pre-background value, compare equal, and read as "caught up". The chat
/// then stayed on its old tail until the user sent a message, whose forced
/// probe finally pulled everything in at once.
void main() {
  late Sync sync;
  var n = 0;
  late String sid;
  late int serverLastSeq;
  late List<int> fetches;

  setUp(() {
    sync = Sync();
    sid = 'bg-${++n}-${DateTime.now().microsecondsSinceEpoch}';
    sync.encryption = _FakeEncryption();
    sync.testIsInitialized = true;
    sync.testSocketConnectedOverride = true;
    sync.testSocketSendOverride = (_, __) {};
    sync.testSessions.clear();
    _stubAllSyncs(sync);
    sync.testResetLastResumeAtMs();
    sync.testSetVisibleSessionId(null);
    InvalidateSync.isBackgrounded = false;

    fetches = <int>[];
    sync.testFetchMessagesOverride = (sessionId, afterSeq, limit) async {
      fetches.add(afterSeq);
      final end = afterSeq + limit < serverLastSeq
          ? afterSeq + limit
          : serverLastSeq;
      return {
        'messages': [
          for (var i = afterSeq + 1; i <= end; i++)
            _makeEncryptedMessage('$sessionId-$i', seq: i),
        ],
        'hasMore': end < serverLastSeq,
      };
    };
  });

  tearDown(() async {
    await sync.onSessionInvisible(sid);
    sync.testFetchMessagesOverride = null;
    sync.testSetVisibleSessionId(null);
    InvalidateSync.isBackgrounded = false;
  });

  Future<void> settle([int ms = 300]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  int? lastShownSeq() {
    final messages = sync.messagesForSession(sid);
    return messages.isEmpty ? null : messages.last['seq'] as int?;
  }

  /// Opens the chat, lets it load, and leaves it — the state a session is in
  /// when the user has looked at it and gone back to the list.
  Future<void> openThenLeave() async {
    await sync.onSessionVisible(sid);
    await settle();
    await sync.onSessionInvisible(sid);
  }

  Future<void> backgroundAndReturn() async {
    sync.suspend();
    await settle(100);
    sync.resume();
    // Past the deferred resume invalidation, which only covers the chat
    // that was visible when the app came back.
    await settle(800);
  }

  test('Sync_OnSessionVisible_AfterBackground fetches rows the catalog '
      'never reported', () async {
    serverLastSeq = 10;
    sync.testSessions[sid] = _makeSession(sid, lastSeq: 10);
    await openThenLeave();
    expect(lastShownSeq(), 10);

    // The session keeps working while the app is away. The catalog entry
    // is deliberately left at 10.
    serverLastSeq = 60;
    await backgroundAndReturn();
    fetches.clear();

    await sync.onSessionVisible(sid);
    await settle();

    expect(
      fetches,
      isNotEmpty,
      reason:
          'cursor == Session.lastSeq is not proof of being caught up '
          'after the live feed was interrupted',
    );
    expect(lastShownSeq(), 60);
  });

  test(
    'Sync_OnSessionVisible_WithoutInterruption does not probe again',
    () async {
      serverLastSeq = 10;
      sync.testSessions[sid] = _makeSession(sid, lastSeq: 10);
      await openThenLeave();
      fetches.clear();

      await sync.onSessionVisible(sid);
      await settle();

      expect(
        fetches,
        isEmpty,
        reason:
            'the message API already confirmed this tail and nothing '
            'interrupted delivery since',
      );
    },
  );

  test('Sync_FetchMessages_PageLimit keeps crawling past a stale catalog '
      'lastSeq', () async {
    // More new rows than one visible cycle may fetch (12 pages of 200).
    serverLastSeq = 3000;
    sync.testSessions[sid] = _makeSession(sid, lastSeq: 100);

    await sync.onSessionVisible(sid);
    // Two cycles, separated by the message sync's minimum interval.
    await settle(2500);

    expect(lastShownSeq(), 3000);
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
