import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/outgoing_image.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/message_outbox.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

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
    Map<String, dynamic>? successResponseData;
    Object? requestException;

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
      successResponseData = null;
      requestException = null;
      await ApiClient().initialize(serverUrl: 'http://localhost');
      ApiClient().testDio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/v3/sessions/sess-1/messages') {
              final exception = requestException;
              if (exception != null) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    error: exception,
                    type: DioExceptionType.connectionError,
                  ),
                );
                return;
              }
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
                  data:
                      successResponseData ??
                      <String, dynamic>{
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

    test('sends mixed user text and image payload', () async {
      await instance.sendMessage(
        'sess-1',
        'Check this screenshot: ![demo](https://example.com/screen.png)',
      );
      await instance.lastCompleteSendFuture;

      final raw = sessionEncryption.lastRawRecord;
      expect(raw, isNotNull);
      final content = raw!['content'] as List<dynamic>;
      expect(content, hasLength(2));
      expect(content[0], isA<Map<String, dynamic>>());
      expect((content[0] as Map<String, dynamic>)['type'], 'text');
      expect((content[0] as Map<String, dynamic>)['text'],
          'Check this screenshot: ');
      expect(content[1], isA<Map<String, dynamic>>());
      expect((content[1] as Map<String, dynamic>)['type'], 'image');
      expect(
        (content[1] as Map<String, dynamic>)['source'],
        {'type': 'url', 'url': 'https://example.com/screen.png'},
      );

      final localMessages = instance.testSessionMessages('sess-1')!;
      expect(localMessages.first['content'], 'Check this screenshot: ');
    });

    test('uses image placeholder text when message contains only images', () async {
      await instance.sendMessage(
        'sess-1',
        '![only-image](https://example.com/screen.png)',
      );
      await instance.lastCompleteSendFuture;

      final localMessages = instance.testSessionMessages('sess-1')!;
      expect(localMessages.first['content'], '[image]');
    });

    test('sends base64 image attachments as content blocks', () async {
      await instance.sendMessage(
        'sess-1',
        'what is this?',
        images: const [
          OutgoingImage(
            mediaType: 'image/jpeg',
            base64Data: 'aGVsbG8=',
            width: 100,
            height: 50,
          ),
        ],
      );
      await instance.lastCompleteSendFuture;

      final raw = sessionEncryption.lastRawRecord;
      expect(raw, isNotNull);
      final content = raw!['content'] as List<dynamic>;
      expect(content, hasLength(2));
      final textBlock = content[0] as Map<String, dynamic>;
      expect(textBlock['type'], 'text');
      expect(textBlock['text'], 'what is this?');
      final imageBlock = content[1] as Map<String, dynamic>;
      expect(imageBlock['type'], 'image');
      expect(imageBlock['source'], {
        'type': 'base64',
        'media_type': 'image/jpeg',
        'data': 'aGVsbG8=',
      });

      // The optimistic row keeps the blocks in `raw` so the bubble can
      // render the attachment immediately, and the localId contract is
      // unchanged for image sends.
      final requestData = capturedRequestData as Map<String, dynamic>;
      final messages = requestData['messages'] as List<dynamic>;
      final message = messages.first as Map<String, dynamic>;
      expect(message['localId'], 'local-1');
      final localMessages = instance.testSessionMessages('sess-1')!;
      final localRaw = localMessages.first['raw'] as Map<String, dynamic>;
      expect(localRaw['content'], isA<List<dynamic>>());
      expect(localMessages.first['content'], 'what is this?');
    });

    test('image-only send emits no text block and [image] display text', () async {
      await instance.sendMessage(
        'sess-1',
        '',
        clientLocalId: 'img-local-1',
        images: const [
          OutgoingImage(mediaType: 'image/png', base64Data: 'aW1n'),
        ],
      );
      await instance.lastCompleteSendFuture;

      final raw = sessionEncryption.lastRawRecord!;
      final content = raw['content'] as List<dynamic>;
      expect(content, hasLength(1));
      expect((content.first as Map<String, dynamic>)['type'], 'image');

      final requestData = capturedRequestData as Map<String, dynamic>;
      final message =
          (requestData['messages'] as List<dynamic>).first
              as Map<String, dynamic>;
      expect(message['localId'], 'img-local-1');

      final localMessages = instance.testSessionMessages('sess-1')!;
      expect(localMessages.first['content'], '[image]');
    });

    test('retry refuses when image bytes were stripped by cache', () async {
      // Seed a failed message whose raw carries a stripped (hollow)
      // base64 image block, as the offline cache would persist it.
      instance.testSetSessionMessages('sess-1', [
        <String, dynamic>{
          'id': 'strip-1',
          'localId': 'strip-1',
          'role': 'user',
          'kind': 'text',
          'content': '[image]',
          'sendStatus': 'failed',
          'raw': <String, dynamic>{
            'role': 'user',
            'content': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'image',
                'source': <String, dynamic>{
                  'type': 'base64',
                  'media_type': 'image/jpeg',
                  'data': '',
                  'omitted': true,
                },
              },
            ],
          },
        },
      ]);

      await instance.retryFailedMessage('sess-1', 'strip-1');

      // No HTTP attempt, no outbox entry, and the row stays failed.
      expect(capturedRequestData, isNull);
      final localMessages = instance.testSessionMessages('sess-1')!;
      expect(localMessages.first['sendStatus'], 'failed');
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

    test('HTTP 409 is permanent — no outbox retry, row marked failed',
        () async {
      responseStatus = 409;
      responseData = <String, dynamic>{'error': 'session is not accepting'};

      await instance.sendMessage(
        'sess-1',
        'conflict',
        clientLocalId: 'client-local-409',
      );
      await instance.lastCompleteSendFuture;

      expect(messageOutbox.contains('client-local-409'), isFalse);

      final localMessages = instance.testSessionMessages('sess-1')!;
      final matching = localMessages.where(
        (m) => m['localId'] == 'client-local-409',
      );
      expect(matching, hasLength(1));
      expect(matching.single['sendStatus'], 'failed');
    });

    test('HTTP 500 carrying a not-found body is treated as permanent',
        () async {
      // The server collapses NotFound into a bare 500. Trusting the
      // status code alone burns 4 HTTP + 3 outbox attempts on a session
      // that no longer exists.
      responseStatus = 500;
      responseData = <String, dynamic>{'error': 'session not found'};

      await instance.sendMessage(
        'sess-1',
        'gone',
        clientLocalId: 'client-local-gone',
      );
      await instance.lastCompleteSendFuture;

      expect(messageOutbox.contains('client-local-gone'), isFalse);

      final localMessages = instance.testSessionMessages('sess-1')!;
      final matching = localMessages.where(
        (m) => m['localId'] == 'client-local-gone',
      );
      expect(matching, hasLength(1));
      expect(matching.single['sendStatus'], 'failed');
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

    test(
      'outbox delivery with HTTP 200 but no localId ACK marks sent',
      () async {
        successResponseData = <String, dynamic>{
          'messages': <Map<String, dynamic>>[],
        };
        instance
          ..testSocketConnectedOverride = true
          ..testSocketSendOverride = (event, data) {
            capturedSocketEvent = event;
            capturedSocketData = data;
          };
        final raw = <String, dynamic>{
          'role': 'user',
          'content': <String, dynamic>{'type': 'text', 'text': 'outbox'},
        };
        instance.testSetSessionMessages('sess-1', [
          <String, dynamic>{
            'id': 'client-local-outbox-no-ack',
            'localId': 'client-local-outbox-no-ack',
            'role': 'user',
            'kind': 'text',
            'content': 'outbox',
            'raw': raw,
            'sendStatus': 'pending',
          },
        ]);

        final delivered = await instance.testDeliverOutboxEntry(
          OutboxEntry(
            localId: 'client-local-outbox-no-ack',
            sessionId: 'sess-1',
            text: 'outbox',
            encryptedContent: 'encrypted-content',
            rawRecord: raw,
            queuedAt: 1700000000000,
          ),
        );

        expect(delivered, isTrue);
        final localMessages = instance.testSessionMessages('sess-1')!;
        final matching = localMessages.where(
          (m) => m['localId'] == 'client-local-outbox-no-ack',
        );
        expect(matching, hasLength(1));
        expect(matching.single['sendStatus'], 'sent');

        expect(capturedSocketEvent, 'message');
        final socketPayload = capturedSocketData as Map<String, dynamic>;
        expect(socketPayload['sid'], 'sess-1');
        expect(socketPayload['localId'], 'client-local-outbox-no-ack');
        expect(socketPayload['message'], 'encrypted-content');
      },
    );

    test(
      'outbox delivery returns false when the request never reaches the server',
      () async {
        requestException = 'ERR_NAME_NOT_RESOLVED';
        instance.testSocketConnectedOverride = true;
        final raw = <String, dynamic>{
          'role': 'user',
          'content': <String, dynamic>{'type': 'text', 'text': 'outbox'},
        };
        instance.testSetSessionMessages('sess-1', [
          <String, dynamic>{
            'id': 'client-local-outbox-dns',
            'localId': 'client-local-outbox-dns',
            'role': 'user',
            'kind': 'text',
            'content': 'outbox',
            'raw': raw,
            'sendStatus': 'pending',
          },
        ]);

        final delivered = await instance.testDeliverOutboxEntry(
          OutboxEntry(
            localId: 'client-local-outbox-dns',
            sessionId: 'sess-1',
            text: 'outbox',
            encryptedContent: 'encrypted-content',
            rawRecord: raw,
            queuedAt: 1700000000000,
          ),
        );

        expect(delivered, isFalse);
        final localMessages = instance.testSessionMessages('sess-1')!;
        final matching = localMessages.where(
          (m) => m['localId'] == 'client-local-outbox-dns',
        );
        expect(matching, hasLength(1));
        expect(matching.single['sendStatus'], 'pending');
      },
    );

    test('outbox delivery returns false on non-2xx server response', () async {
      responseStatus = 503;
      responseData = <String, dynamic>{'error': 'server overload'};
      instance.testSocketConnectedOverride = true;
      final raw = <String, dynamic>{
        'role': 'user',
        'content': <String, dynamic>{'type': 'text', 'text': 'outbox'},
      };
      instance.testSetSessionMessages('sess-1', [
        <String, dynamic>{
          'id': 'client-local-outbox-503',
          'localId': 'client-local-outbox-503',
          'role': 'user',
          'kind': 'text',
          'content': 'outbox',
          'raw': raw,
          'sendStatus': 'pending',
        },
      ]);

      final delivered = await instance.testDeliverOutboxEntry(
        OutboxEntry(
          localId: 'client-local-outbox-503',
          sessionId: 'sess-1',
          text: 'outbox',
          encryptedContent: 'encrypted-content',
          rawRecord: raw,
          queuedAt: 1700000000000,
        ),
      );

      expect(delivered, isFalse);
      final localMessages = instance.testSessionMessages('sess-1')!;
      final matching = localMessages.where(
        (m) => m['localId'] == 'client-local-outbox-503',
      );
      expect(matching, hasLength(1));
      expect(matching.single['sendStatus'], 'pending');
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
      // 409 Conflict / 410 Gone / 412 Failed Precondition are equally
      // unrecoverable — retrying only burns the outbox budget.
      for (final status in [409, 410, 412]) {
        expect(
          instance.testIsPermanentSendFailure(
            StateError('Failed to send message: $status'),
          ),
          isTrue,
          reason: 'status $status should be permanent',
        );
      }
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
