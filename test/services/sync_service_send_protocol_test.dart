import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/message_outbox.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';

class _CapturingSessionEncryption implements SessionEncryption {
  Map<String, dynamic>? lastRawRecord;

  @override
  Future<String> encryptRawRecord(Map<String, dynamic> record) async {
    lastRawRecord = Map<String, dynamic>.from(record);
    return 'encrypted-content';
  }

  @override
  Future<ProcessedMessages> decryptAndProcessMessages(
    List<Map<String, dynamic>> messages,
    String sessionId,
  ) async {
    return const ProcessedMessages(
      messages: [],
      toolResults: [],
      usageUpdates: [],
      maxSeq: 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEncryption implements Encryption {
  _FakeEncryption({required this.sessionEncryption, required this.fixedId});

  final SessionEncryption sessionEncryption;
  final String fixedId;

  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      sessionEncryption;

  @override
  String generateId() => fixedId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  instance.messagesSync.clear();
}

Session _readySession(String id, {String? permissionMode}) => Session(
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
  permissionMode: permissionMode,
);

void main() {
  group('Sync.sendMessage protocol', () {
    late Sync instance;
    late _CapturingSessionEncryption sessionEncryption;
    dynamic capturedRequestData;
    String? capturedSocketEvent;
    dynamic capturedSocketData;
    var responseStatus = 200;
    Map<String, dynamic>? responseData;

    setUp(() async {
      instance = Sync();
      _stubAllSyncs(instance);
      instance.testIsInitialized = true;
      instance.testClearSessionMessageState('sess-1');
      instance.testSessions.clear();
      instance.testSessions['sess-1'] = _readySession(
        'sess-1',
        permissionMode: 'team-custom-mode',
      );
      instance.testSetLastEphemeralAt(
        'sess-1',
        DateTime.now().millisecondsSinceEpoch,
      );

      sessionEncryption = _CapturingSessionEncryption();
      instance.encryption = _FakeEncryption(
        sessionEncryption: sessionEncryption,
        fixedId: 'local-1',
      );
      instance.testSocketConnectedOverride = null;
      instance.testSocketSendOverride = null;
      instance.testFetchMessagesOverride = (_, __, ___) async =>
          <String, dynamic>{
            'messages': <Map<String, dynamic>>[],
            'pagination': <String, dynamic>{'hasMore': false},
          };

      capturedRequestData = null;
      capturedSocketEvent = null;
      capturedSocketData = null;
      responseStatus = 200;
      responseData = null;
      await ApiClient().initialize(serverUrl: 'http://localhost');
      ApiClient().testDio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/v3/sessions/sess-1/messages') {
              capturedRequestData = options.data;
              final request = options.data as Map<String, dynamic>;
              final requestMessages = request['messages'] as List<dynamic>;
              final requestMessage =
                  requestMessages.first as Map<String, dynamic>;
              final requestLocalId = requestMessage['localId'] as String?;
              if (responseStatus != 200) {
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: responseStatus,
                    data: responseData ?? <String, dynamic>{},
                  ),
                );
                return;
              }
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{
                    'messages': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'id': 'srv-msg-1',
                        'seq': 2,
                        'localId': requestLocalId,
                        'createdAt': 1700000005000,
                      },
                    ],
                  },
                ),
              );
              return;
            }

            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 404,
                data: <String, dynamic>{},
              ),
            );
          },
        ),
      );
      messageOutbox.dispose();
      messageOutbox.testStorage = _FakeMMKVStorage();
      messageOutbox.configure(
        deliver: (_) async => false,
        onStatusChanged: (sid, lid, status) {
          final msgs = instance.testSessionMessages(sid);
          if (msgs == null) return;
          instance.testSetSessionMessages(
            sid,
            msgs.map((m) {
              if (m['localId'] == lid || m['id'] == lid) {
                return <String, dynamic>{...m, 'sendStatus': status};
              }
              return m;
            }).toList(),
          );
        },
      );
    });

    tearDown(() {
      ApiClient().dispose();
      messageOutbox.dispose();
      messageOutbox.testStorage = MMKVStorage.testConstructor();
      instance.testSessions.clear();
      instance.testIsInitialized = false;
      InvalidateSync.isBackgrounded = false;
      instance.testSocketConnectedOverride = null;
      instance.testSocketSendOverride = null;
      instance.testFetchMessagesOverride = null;
    });

    test('sends legacy user payload and sanitizes permission mode', () async {
      await instance.sendMessage('sess-1', 'Hello from Flutter');
      await instance.lastCompleteSendFuture;

      final raw = sessionEncryption.lastRawRecord;
      expect(raw, isNotNull);
      expect(raw!['role'], 'user');

      final content = raw['content'] as Map<String, dynamic>;
      expect(content['type'], 'text');
      expect(content['text'], 'Hello from Flutter');

      final meta = raw['meta'] as Map<String, dynamic>;
      expect(meta['sentFrom'], isA<String>());
      expect(meta['appendSystemPrompt'], isA<String>());
      expect(meta['permissionMode'], 'default');

      final requestData = capturedRequestData as Map<String, dynamic>;
      final messages = requestData['messages'] as List<dynamic>;
      expect(messages, hasLength(1));
      final message = messages.first as Map<String, dynamic>;
      expect(message['localId'], 'local-1');
      expect(message['content'], 'encrypted-content');
    });

    test('uses caller supplied localId when provided', () async {
      await instance.sendMessage(
        'sess-1',
        'Hello from Flutter',
        clientLocalId: 'client-local-42',
      );
      await instance.lastCompleteSendFuture;

      final requestData = capturedRequestData as Map<String, dynamic>;
      final messages = requestData['messages'] as List<dynamic>;
      expect(messages, hasLength(1));
      final message = messages.first as Map<String, dynamic>;
      expect(message['localId'], 'client-local-42');
      expect(message['content'], 'encrypted-content');

      final localMessages = instance.testSessionMessages('sess-1')!;
      final optimistic = localMessages.where(
        (m) => m['localId'] == 'client-local-42',
      );
      expect(optimistic, isNotEmpty);
    });

    test('REST ACK advances message cursor and session lastSeq', () async {
      expect(instance.sessionMessageCursors['sess-1'], isNull);
      expect(instance.testSessions['sess-1']!.lastSeq, isNull);

      await instance.sendMessage('sess-1', 'Hello from Flutter');
      await instance.lastCompleteSendFuture;

      expect(instance.sessionMessageCursors['sess-1'], 2);
      expect(instance.testSessions['sess-1']!.lastSeq, 2);
    });

    test('HTTP 500 queues retry with the same localId and one row', () async {
      responseStatus = 500;
      responseData = <String, dynamic>{'error': 'failed to send messages'};

      await instance.sendMessage(
        'sess-1',
        'retry me',
        clientLocalId: 'client-local-500',
      );
      await instance.lastCompleteSendFuture;

      expect(messageOutbox.contains('client-local-500'), isTrue);

      final localMessages = instance.testSessionMessages('sess-1')!;
      final matching = localMessages.where(
        (m) => m['localId'] == 'client-local-500',
      );
      expect(matching, hasLength(1));
      expect(matching.single['sendStatus'], 'pending');
    });

    test('explicit retry requeues the same localId and one row', () async {
      final raw = <String, dynamic>{
        'role': 'user',
        'content': <String, dynamic>{'type': 'text', 'text': 'retry me'},
        'meta': <String, dynamic>{'sentFrom': 'test'},
      };
      instance.testSetSessionMessages('sess-1', [
        <String, dynamic>{
          'id': 'client-local-retry',
          'localId': 'client-local-retry',
          'role': 'user',
          'kind': 'text',
          'text': 'retry me',
          'content': 'retry me',
          'raw': raw,
          'sendStatus': 'failed',
        },
      ]);

      await instance.retryFailedMessage('sess-1', 'client-local-retry');

      expect(messageOutbox.contains('client-local-retry'), isTrue);
      final entry = messageOutbox.entries.single;
      expect(entry.localId, 'client-local-retry');
      expect(entry.sessionId, 'sess-1');
      expect(entry.text, 'retry me');
      expect(entry.encryptedContent, 'encrypted-content');
      expect(entry.rawRecord, raw);
      expect(entry.retryCount, 0);

      final localMessages = instance.testSessionMessages('sess-1')!;
      final matching = localMessages.where(
        (m) => m['localId'] == 'client-local-retry',
      );
      expect(matching, hasLength(1));
      expect(matching.single['sendStatus'], 'pending');
    });

    test('outbox delivery applies REST ACK with the same localId', () async {
      instance.testSocketConnectedOverride = true;
      instance.testSocketSendOverride = (event, data) {
        capturedSocketEvent = event;
        capturedSocketData = data;
      };
      final raw = <String, dynamic>{
        'role': 'user',
        'content': <String, dynamic>{'type': 'text', 'text': 'outbox'},
      };
      instance.testSetSessionMessages('sess-1', [
        <String, dynamic>{
          'id': 'client-local-outbox',
          'localId': 'client-local-outbox',
          'role': 'user',
          'kind': 'text',
          'content': 'outbox',
          'raw': raw,
          'sendStatus': 'pending',
        },
      ]);

      final delivered = await instance.testDeliverOutboxEntry(
        OutboxEntry(
          localId: 'client-local-outbox',
          sessionId: 'sess-1',
          text: 'outbox',
          encryptedContent: 'encrypted-content',
          rawRecord: raw,
          queuedAt: 1700000000000,
        ),
      );

      expect(delivered, isTrue);
      expect(instance.sessionMessageCursors['sess-1'], 2);
      final localMessages = instance.testSessionMessages('sess-1')!;
      final matching = localMessages.where(
        (m) => m['localId'] == 'client-local-outbox',
      );
      expect(matching, hasLength(1));
      expect(matching.single['id'], 'srv-msg-1');
      expect(matching.single['sendStatus'], 'sent');

      expect(capturedSocketEvent, 'message');
      final socketPayload = capturedSocketData as Map<String, dynamic>;
      expect(socketPayload['sid'], 'sess-1');
      expect(socketPayload['localId'], 'client-local-outbox');
      expect(socketPayload['message'], 'encrypted-content');
    });

    test('backgrounded send queues retry without touching REST', () async {
      InvalidateSync.isBackgrounded = true;

      await instance.sendMessage(
        'sess-1',
        'retry after foreground',
        clientLocalId: 'client-local-bg',
      );
      await instance.lastCompleteSendFuture;

      expect(capturedRequestData, isNull);
      expect(messageOutbox.contains('client-local-bg'), isTrue);

      final localMessages = instance.testSessionMessages('sess-1')!;
      final matching = localMessages.where(
        (m) => m['localId'] == 'client-local-bg',
      );
      expect(matching, hasLength(1));
      expect(matching.single['sendStatus'], 'pending');
    });

    test('uses REST as primary path even when socket is connected', () async {
      instance.testSocketConnectedOverride = true;
      instance.testSocketSendOverride = (event, data) {
        capturedSocketEvent = event;
        capturedSocketData = data;
      };

      await instance.sendMessage('sess-1', 'Hello over socket');
      await instance.lastCompleteSendFuture;

      final raw = sessionEncryption.lastRawRecord;
      expect(raw, isNotNull);
      final meta = raw!['meta'] as Map<String, dynamic>;
      expect(meta['permissionMode'], 'default');

      final requestData = capturedRequestData as Map<String, dynamic>;
      final messages = requestData['messages'] as List<dynamic>;
      expect(messages, hasLength(1));
      final message = messages.first as Map<String, dynamic>;
      expect(message['localId'], 'local-1');
      expect(message['content'], 'encrypted-content');

      // After REST ACK, a socket 'message' event is also emitted so the
      // daemon picks up the message (server deduplicates by localId).
      expect(capturedSocketEvent, 'message');
      final socketPayload = capturedSocketData as Map<String, dynamic>;
      expect(socketPayload['sid'], 'sess-1');
      expect(socketPayload['localId'], 'local-1');
      expect(socketPayload['message'], 'encrypted-content');
    });

    test('visible connected session delays post-send catch-up probe', () async {
      final fetchCalls = <int>[];
      instance.testVisibleSessionId = 'sess-1';
      instance.testSocketConnectedOverride = true;
      instance.testSocketSendOverride = (_, __) {};
      instance.messagesSync['sess-1'] = InvalidateSync(
        () => instance.fetchMessages('sess-1'),
      );
      instance.testFetchMessagesOverride = (_, afterSeq, ___) async {
        fetchCalls.add(afterSeq);
        return <String, dynamic>{
          'messages': <Map<String, dynamic>>[],
          'pagination': <String, dynamic>{'hasMore': false},
        };
      };

      await instance.sendMessage('sess-1', 'Hello from Flutter');
      await instance.lastCompleteSendFuture;
      final fetchCountAfterSend = fetchCalls.length;

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(
        fetchCalls.length,
        fetchCountAfterSend,
        reason:
            'Visible session with live socket should not do an eager '
            'post-send history fetch',
      );

      await Future<void>.delayed(const Duration(milliseconds: 2300));
      expect(
        fetchCalls.length,
        greaterThan(fetchCountAfterSend),
        reason:
            'REST ACK only proves the user message was stored. The fallback '
            'probe must still run so a missed assistant response can heal.',
      );
    });

    test(
      'non-visible session probes after REST ACK until a response arrives',
      () async {
        final fetchCalls = <int>[];
        instance.testVisibleSessionId = 'other-session';
        instance.messagesSync['sess-1'] = InvalidateSync(
          () => instance.fetchMessages('sess-1'),
        );
        instance.testFetchMessagesOverride = (_, afterSeq, ___) async {
          fetchCalls.add(afterSeq);
          return <String, dynamic>{
            'messages': <Map<String, dynamic>>[],
            'pagination': <String, dynamic>{'hasMore': false},
          };
        };

        await instance.sendMessage('sess-1', 'Hello from Flutter');
        await instance.lastCompleteSendFuture;
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(
          fetchCalls,
          isNotEmpty,
          reason:
              'The REST ACK already moved the cursor to the user message, '
              'but background catch-up must still look for the response',
        );
      },
    );
  });

  group('Sync send-failure classification', () {
    late Sync instance;

    setUp(() {
      instance = Sync();
      _stubAllSyncs(instance);
    });

    test('unrestorable-session errors are permanent (no outbox retry)', () {
      // These are thrown by the auto-restore path when the session no
      // longer exists / cannot be restored. Retrying via the outbox is
      // pointless, so they must classify as permanent.
      expect(
        instance.testIsPermanentSendFailure(
          StateError('Session not found: sess-1 — failed to resolve session'),
        ),
        isTrue,
      );
      expect(
        instance.testIsPermanentSendFailure(
          StateError('Could not restore stopped session sess-1: timeout'),
        ),
        isTrue,
      );
      expect(
        instance.testIsPermanentSendFailure(
          StateError('Failed to send message: 404'),
        ),
        isTrue,
      );
      // And they must not be treated as retryable.
      expect(
        instance.testIsRetryableSendFailure(
          StateError('Session not found: sess-1'),
        ),
        isFalse,
      );
    });

    test('transient server/ack errors stay retryable, not permanent', () {
      final ackError = StateError(
        'Failed to send message: server did not acknowledge message',
      );
      final serverError = StateError('Failed to send message: 503');
      for (final e in [ackError, serverError]) {
        expect(instance.testIsRetryableSendFailure(e), isTrue);
        expect(instance.testIsPermanentSendFailure(e), isFalse);
      }
    });
  });
}

class _FakeMMKVStorage extends MMKVStorage {
  _FakeMMKVStorage() : super.testConstructor();

  String? _outboxData;

  @override
  Future<String?> getOutboxEntries() async => _outboxData;

  @override
  Future<void> saveOutboxEntries(String json) async {
    _outboxData = json;
  }
}
