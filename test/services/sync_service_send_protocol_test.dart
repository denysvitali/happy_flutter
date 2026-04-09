import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
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
  instance.friendsSync = InvalidateSync(() async {});
  instance.friendRequestsSync = InvalidateSync(() async {});
  instance.feedSync = InvalidateSync(() async {});
  instance.todosSync = InvalidateSync(() async {});
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

    setUp(() async {
      instance = Sync();
      _stubAllSyncs(instance);
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
      instance.testFetchMessagesOverride =
          (_, __, ___) async => <String, dynamic>{
            'messages': <Map<String, dynamic>>[],
            'pagination': <String, dynamic>{'hasMore': false},
          };

      capturedRequestData = null;
      capturedSocketEvent = null;
      capturedSocketData = null;
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
    });

    tearDown(() {
      ApiClient().dispose();
      instance.testSessions.clear();
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
  });
}
