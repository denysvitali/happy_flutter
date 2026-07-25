import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

/// E2E coverage for the two user-visible scenarios called out in
/// ROADMAP.md "User-visible core E2E scenarios" that are not exercised
/// by the other E2E suites:
///
/// 1. **Disconnected socket with successful REST persistence** — the
///    user sends a message while the socket is offline. REST is the
///    only available path; the send must still reach 'sent' and the
///    canonical localId must survive.
///
/// 2. **Follow-up sends while the agent is still thinking** — the
///    session is in a `thinking` state (agent mid-response) and the
///    user types a follow-up before the previous send fully resolves.
///    Each tap must produce a distinct localId, a distinct optimistic
///    row, and a distinct 'sent' message.
///
/// Scenarios already covered elsewhere (linked for cross-reference):
/// - rapid follow-ups: `concurrent_send_message_e2e_test.dart`
/// - background/resume mid-send: `lifecycle_midsend_localid_e2e_test.dart`
///
/// Invariants asserted (cross-cutting):
///   - One tap -> one stable localId across optimistic insert, REST
///     round-trip, and final merged message.
///   - A second tap is a new logical message, never a re-ack of the
///     first one — even when the first is still in flight.
///   - REST persistence is the source of truth when the socket is
///     offline: the server ack is the merge event, not a socket echo.

void main() {
  group('disconnected socket with successful REST persistence', () {
    late Sync sync;
    late _AckInterceptor interceptor;

    setUp(() async {
      sync = Sync();
      _stubAllSyncs(sync);
      sync.testSessions.clear();
      sync.testSetSessionMessages('sess-1', []);
      sync.testSessions['sess-1'] = _makeSession('sess-1');
      sync.testSetLastEphemeralAt(
        'sess-1',
        DateTime.now().millisecondsSinceEpoch,
      );
      sync.encryption = _FakeEncryption();
      sync.testIsInitialized = true;
      // Disconnected socket: only REST can carry the send.
      sync.testSocketConnectedOverride = false;
      sync.testSocketSendOverride = (_, __) {
        fail(
          'Socket emit must NOT be attempted while disconnected; '
          'REST is the only path',
        );
      };
      sync.testFetchMessagesOverride = (_, __, ___) async =>
          _emptyMessagesPage;

      interceptor = _AckInterceptor();
      await ApiClient().initialize(serverUrl: 'http://localhost');
      ApiClient().testDio!.interceptors.add(interceptor);
    });

    tearDown(() {
      ApiClient().dispose();
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
    });

    test('REST-only send reaches sent state with the optimistic localId',
        () async {
      const sessionId = 'sess-1';

      // Kick the send off, then drain microtasks so sendMessage
      // has actually run to the point where it sets
      // lastCompleteSendFuture. Awaiting that future directly
      // when it's still null (the function hasn't yet reached the
      // assignment) would return immediately and the assertion below
      // would race the actual POST.
      final future = sync.sendMessage(sessionId, 'ping while offline');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await sync.lastCompleteSendFuture;
      await future;

      final msgs = sync.testSessionMessages(sessionId)!;
      final userMsgs = msgs
          .where((m) => m['content'] == 'ping while offline')
          .toList();
      expect(userMsgs, hasLength(1));
      expect(userMsgs.single['sendStatus'], 'sent');
      expect(userMsgs.single['localId'], isNotNull);
      expect(userMsgs.single['localId'], isNotEmpty);

      // The localId the optimistic row used must be the same one the
      // server echoed back, and must be the only one in flight.
      expect(interceptor.ackedLocalIds, hasLength(1));
      expect(interceptor.ackedLocalIds.single, userMsgs.single['localId']);
    });

    test('repeated identical sends while offline all persist as distinct '
        'messages', () async {
      const sessionId = 'sess-1';

      final f1 = sync.sendMessage(sessionId, 'continue');
      final f2 = sync.sendMessage(sessionId, 'continue');
      final f3 = sync.sendMessage(sessionId, 'continue');

      await Future.wait([f1, f2, f3]);
      await sync.lastCompleteSendFuture;

      final msgs = sync.testSessionMessages(sessionId)!;
      final continueMsgs =
          msgs.where((m) => m['content'] == 'continue').toList();
      expect(
        continueMsgs,
        hasLength(3),
        reason: 'Three distinct logical messages must persist',
      );

      // Three distinct localIds and three distinct server IDs — the
      // REST-only path must not collapse identical text into a single
      // logical message.
      final localIds =
          continueMsgs.map((m) => m['localId'] as String).toSet();
      expect(
        localIds,
        hasLength(3),
        reason: 'Repeated identical text must still get distinct localIds',
      );

      final serverIds =
          continueMsgs.map((m) => m['id'] as String?).whereType<String>()
              .toSet();
      expect(
        serverIds,
        hasLength(3),
        reason: 'Server must echo three distinct ids',
      );
    });
  });

  group('follow-up sends while the agent is still thinking', () {
    late Sync sync;
    late _AckInterceptor interceptor;

    setUp(() async {
      sync = Sync();
      _stubAllSyncs(sync);
      sync.testSessions.clear();
      sync.testSetSessionMessages('sess-2', []);
      // Session starts in a "thinking" state — the agent is mid-response
      // on the previous turn. The user's follow-up send must still be
      // accepted as a brand-new logical message.
      sync.testSessions['sess-2'] =
          _makeSession('sess-2', thinking: true);
      sync.testSetLastEphemeralAt(
        'sess-2',
        DateTime.now().millisecondsSinceEpoch,
      );
      sync.encryption = _FakeEncryption();
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testFetchMessagesOverride = (_, __, ___) async =>
          _emptyMessagesPage;

      interceptor = _AckInterceptor();
      await ApiClient().initialize(serverUrl: 'http://localhost');
      ApiClient().testDio!.interceptors.add(interceptor);
    });

    tearDown(() {
      ApiClient().dispose();
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
    });

    test('two distinct taps while thinking produce two distinct logical '
        'messages with distinct localIds', () async {
      const sessionId = 'sess-2';

      final f1 = sync.sendMessage(sessionId, 'first thought');
      final f2 = sync.sendMessage(sessionId, 'follow-up while thinking');

      // Let both optimistic inserts settle before we sample state.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // While both sends are in flight, the message list must show two
      // distinct optimistic rows with two distinct localIds — never
      // collapsed to a single row even though the second was tapped
      // while the first was still 'sending'.
      final midMsgs = sync.testSessionMessages(sessionId)!;
      final midUser = midMsgs
          .where((m) => m['sendStatus'] == 'sending')
          .toList();
      expect(
        midUser,
        hasLength(2),
        reason: 'Both sends must insert an optimistic row before ack',
      );
      final midLocalIds =
          midUser.map((m) => m['localId'] as String).toSet();
      expect(
        midLocalIds,
        hasLength(2),
        reason: 'Each in-flight send must carry a distinct localId',
      );

      await Future.wait([f1, f2]);
      await sync.lastCompleteSendFuture;

      final finalMsgs = sync.testSessionMessages(sessionId)!;
      final userMsgs = finalMsgs
          .where((m) => m['content'] == 'first thought'
              || m['content'] == 'follow-up while thinking')
          .toList();
      expect(userMsgs, hasLength(2));

      final localIds =
          userMsgs.map((m) => m['localId'] as String).toSet();
      expect(
        localIds,
        hasLength(2),
        reason: 'Two distinct logical messages must persist',
      );

      final serverIds =
          userMsgs.map((m) => m['id'] as String?).whereType<String>().toSet();
      expect(
        serverIds,
        hasLength(2),
        reason: 'Server must echo two distinct ids',
      );

      // Both reached 'sent' — the session was in a thinking state but
      // a fresh user tap is always accepted.
      expect(
        userMsgs.every((m) => m['sendStatus'] == 'sent'),
        isTrue,
      );
    });

    test('the second tap never re-acks the first message', () async {
      const sessionId = 'sess-2';

      final f1 = sync.sendMessage(sessionId, 'first');
      // Drain microtasks so f1's optimistic insert completes first.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final firstLocalId = sync
          .testSessionMessages(sessionId)!
          .where((m) => m['content'] == 'first')
          .single['localId'] as String;

      final f2 = sync.sendMessage(sessionId, 'second');
      await Future.wait([f1, f2]);
      await sync.lastCompleteSendFuture;

      // The REST interceptor saw the localId of the first send exactly
      // once, and the localId of the second send exactly once. A
      // re-ack would have shown the first id twice.
      expect(interceptor.ackedLocalIds, hasLength(2));
      expect(
        interceptor.ackedLocalIds.toSet(),
        containsAll(<String>{firstLocalId}),
      );
      expect(
        interceptor.ackedLocalIds.where((id) => id == firstLocalId),
        hasLength(1),
        reason: 'First localId must appear in REST POSTs exactly once',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// HTTP interceptor that captures acked localIds and returns a fresh
// server id for each POST so a re-ack (e.g. by mistake) would surface
// as a duplicate `id` and fail the test.
// ---------------------------------------------------------------------------

class _AckInterceptor extends Interceptor {
  final List<String> ackedLocalIds = [];
  int _seqCounter = 1;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final isMessagesPath =
        options.path.contains('/v3/sessions/') &&
            options.path.contains('/messages');
    final isPost = options.method.toUpperCase() == 'POST';

    if (isMessagesPath && isPost) {
      final localId = _extractLocalId(options.data);
      if (localId != null) {
        ackedLocalIds.add(localId);
      }
      final seq = _seqCounter++;
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'messages': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'srv-$seq',
                'seq': seq,
                'localId': localId,
                'createdAt': DateTime.now().millisecondsSinceEpoch,
              },
            ],
          },
        ),
      );
      return;
    }

    // GET or other requests: return 200 with empty data so
    // fetchMessages doesn't trigger 404 cleanup.
    handler.resolve(
      Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: <String, dynamic>{
          'messages': <Map<String, dynamic>>[],
          'hasMore': false,
        },
      ),
    );
  }

  String? _extractLocalId(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final msgs = data['messages'] as List<dynamic>?;
    if (msgs == null || msgs.isEmpty) return null;
    final first = msgs.first;
    if (first is! Map<String, dynamic>) return null;
    return first['localId'] as String?;
  }
}

// ---------------------------------------------------------------------------
// Fake encryption (mirrors concurrent_send_message_e2e_test.dart).
// Uses noSuchMethod so the surface area can grow without breaking
// the test fixture.
// ---------------------------------------------------------------------------

class _FakeEncryption implements Encryption {
  final Map<String, _FakeSessionEncryption> _sessions = {};

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return _sessions.putIfAbsent(
      sessionId,
      () => _FakeSessionEncryption(sessionId: sessionId),
    );
  }

  @override
  String generateId() => 'test-local-${DateTime.now().microsecondsSinceEpoch}';

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
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    return data.map((item) {
      final jsonStr = jsonEncode(item);
      final bytes = utf8.encode(jsonStr);
      final output = Uint8List(bytes.length + 1);
      output[0] = 0x01;
      output.setRange(1, output.length, bytes);
      return output;
    }).toList();
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    return data.map((item) {
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
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

const _emptyMessagesPage = <String, dynamic>{
  'messages': <Map<String, dynamic>>[],
  'hasMore': false,
};

Session _makeSession(
  String id, {
  String presence = 'online',
  bool thinking = false,
}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 1700000000000,
    updatedAt: 1700000000000,
    active: true,
    activeAt: 1700000000000,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    presence: presence,
  );
}

void _stubAllSyncs(Sync instance) {
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
