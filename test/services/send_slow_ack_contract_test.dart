// Contract tests for the "sent (slow)" outcome.
//
// Three production traces showed the same shape: the server took ~28s on
// `AllocateSessionSeqBatch` row-lock contention, the client's ~12s send
// deadline expired first, and the message went to the outbox. The retry
// POST then came back 200 in 93-379ms because the row was *already*
// persisted (`ON CONFLICT (session_id, local_id) DO NOTHING` plus a
// `GetMessagesByLocalIDs` lookup). The send had landed, but the last
// thing the user saw was "Retry queued".
//
// Invariants pinned here (P0 messaging surface):
//   - one canonical localId across optimistic row, deadline handoff,
//     outbox retry and server ack;
//   - exactly one logical message — the slow ack replaces the
//     placeholder by localId, it never appends;
//   - terminal state stays `sendStatus: 'sent'` — the slow marker is an
//     additive display hint, not a new send state;
//   - a delivery that was never deadline-timed-out is not marked slow.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/message_outbox.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

const String _sessionId = 'sess-slow';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('slow send confirmation', () {
    late Sync instance;
    late _AckInterceptor interceptor;

    setUp(() async {
      instance = Sync();
      _stubAllSyncs(instance);
      instance.testIsInitialized = true;
      instance.testSocketConnectedOverride = true;
      instance.testSocketSendOverride = (_, __) {};
      instance.testSessions.clear();
      instance.testSessions[_sessionId] = _session(_sessionId);
      instance.testSetSessionMessages(_sessionId, []);

      interceptor = _AckInterceptor();
      await ApiClient().initialize(serverUrl: 'http://localhost');
      ApiClient().testDio!.interceptors.add(interceptor);
    });

    tearDown(() {
      ApiClient().dispose();
      instance.testSocketConnectedOverride = null;
      instance.testSocketSendOverride = null;
    });

    /// Seeds the optimistic row that `sendMessage` would have inserted
    /// before the deadline expired, carrying the canonical [localId].
    void seedOptimisticRow(String localId, {String status = 'pending'}) {
      instance.testSetSessionMessages(_sessionId, [
        <String, dynamic>{
          'id': localId,
          'localId': localId,
          'role': 'user',
          'kind': 'text',
          'content': 'continue',
          'text': 'continue',
          'seq': -1,
          'createdAt': 1700000000000,
          'sendStatus': status,
        },
      ]);
    }

    OutboxEntry entryFor(String localId) => OutboxEntry(
      localId: localId,
      sessionId: _sessionId,
      text: 'continue',
      encryptedContent: 'cipher-$localId',
      rawRecord: const <String, dynamic>{'role': 'user'},
      queuedAt: 1700000000000,
    );

    test(
      'a deadline-timed-out send confirmed by the retry becomes '
      'sent-slow on the same localId',
      () async {
        const localId = 'local-slow-1';
        seedOptimisticRow(localId);
        instance.testRegisterSendDeadline(localId);

        final delivered = await instance.testDeliverOutboxEntry(
          entryFor(localId),
        );

        expect(delivered, isTrue);
        final msgs = instance.testSessionMessages(_sessionId);
        expect(msgs, isNotNull);
        expect(
          msgs!,
          hasLength(1),
          reason: 'a slow ack replaces the placeholder, never appends',
        );
        final row = msgs.single;
        expect(
          row['localId'],
          localId,
          reason: 'the canonical localId must survive the retry',
        );
        expect(
          row['sendStatus'],
          'sent',
          reason: 'slow is still delivered — the send state is terminal',
        );
        expect(
          row['sendSlow'],
          isTrue,
          reason: 'the row must be reportable as "Delivered - slow"',
        );
        expect(
          interceptor.capturedLocalIds,
          [localId],
          reason: 'the retry POST reuses the canonical localId',
        );
      },
    );

    test('the slow marker is consumed once, not re-applied on later acks',
        () async {
      const localId = 'local-slow-2';
      seedOptimisticRow(localId);
      instance.testRegisterSendDeadline(localId);

      await instance.testDeliverOutboxEntry(entryFor(localId));
      expect(instance.testHasPendingSendDeadline(localId), isFalse);

      // A duplicate delivery (server re-broadcast / manual retry) must not
      // create a second row or a second logical message.
      await instance.testDeliverOutboxEntry(entryFor(localId));
      final msgs = instance.testSessionMessages(_sessionId);
      expect(msgs, hasLength(1));
      expect(msgs!.single['localId'], localId);
      expect(msgs.single['sendStatus'], 'sent');
    });

    test('an ordinary outbox delivery is never marked slow', () async {
      const localId = 'local-normal';
      seedOptimisticRow(localId);
      // No deadline was registered: this entry was queued for a real
      // failure, not because the client stopped waiting.

      final delivered = await instance.testDeliverOutboxEntry(
        entryFor(localId),
      );

      expect(delivered, isTrue);
      final msgs = instance.testSessionMessages(_sessionId);
      expect(msgs, hasLength(1));
      expect(msgs!.single['localId'], localId);
      expect(msgs.single['sendStatus'], 'sent');
      expect(
        msgs.single['sendSlow'],
        isNot(isTrue),
        reason: 'only a deadline-timed-out send reports as slow',
      );
    });

    test(
      'two identical texts keep distinct localIds through the slow path',
      () async {
        const firstId = 'local-continue-a';
        const secondId = 'local-continue-b';
        instance.testSetSessionMessages(_sessionId, [
          for (final id in [firstId, secondId])
            <String, dynamic>{
              'id': id,
              'localId': id,
              'role': 'user',
              'kind': 'text',
              'content': 'continue',
              'text': 'continue',
              'seq': -1,
              'createdAt': 1700000000000,
              'sendStatus': 'pending',
            },
        ]);
        instance.testRegisterSendDeadline(secondId);

        await instance.testDeliverOutboxEntry(entryFor(secondId));

        final msgs = instance.testSessionMessages(_sessionId);
        expect(msgs, hasLength(2));
        final first = msgs!.firstWhere((m) => m['localId'] == firstId);
        final second = msgs.firstWhere((m) => m['localId'] == secondId);
        expect(
          first['sendSlow'],
          isNot(isTrue),
          reason: 'identical text is never identity — only the acked '
              'localId may be upgraded',
        );
        expect(first['sendStatus'], 'pending');
        expect(second['sendSlow'], isTrue);
        expect(second['sendStatus'], 'sent');
      },
    );
  });
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

Session _session(String id) => Session(
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
);

/// Mirrors the server's idempotent store: a 200 echoing the posted
/// `localId`, which is exactly what the dedupe path returns for a message
/// that was already persisted before the client gave up.
class _AckInterceptor extends Interceptor {
  final List<String?> capturedLocalIds = <String?>[];

  /// Server ids are stable per `localId`: the dedupe path returns the
  /// row that already exists, so a repeated POST must not look like a
  /// different message.
  final Map<String, int> _seqByLocalId = <String, int>{};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final isSend =
        options.method.toUpperCase() == 'POST' &&
        options.path.contains('/messages');
    if (!isSend) {
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 404,
          data: <String, dynamic>{},
        ),
      );
      return;
    }
    final data = options.data;
    String? localId;
    if (data is Map) {
      final messages = data['messages'];
      if (messages is List && messages.isNotEmpty) {
        final first = messages.first;
        if (first is Map) localId = first['localId'] as String?;
      }
    }
    capturedLocalIds.add(localId);
    final seq = _seqByLocalId.putIfAbsent(
      localId ?? '',
      () => _seqByLocalId.length + 1,
    );
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
              'createdAt': 1700000000001,
            },
          ],
        },
      ),
    );
  }
}
