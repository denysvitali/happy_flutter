import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/message_outbox.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

import '../helpers/test_helpers.dart';

class _PausedEncryption implements SessionEncryption {
  final firstStarted = Completer<void>();
  final releaseFirst = Completer<void>();
  int calls = 0;
  bool failFirst = false;

  @override
  Future<String> encryptRawRecord(Map<String, dynamic> record) async {
    final call = ++calls;
    if (call == 1) {
      firstStarted.complete();
      await releaseFirst.future;
      if (failFirst) throw StateError('preparation failed');
    }
    return 'encrypted-$call';
  }

  @override
  Future<ProcessedMessages> decryptAndProcessMessages(
    List<Map<String, dynamic>> messages,
    String sessionId,
  ) async => const ProcessedMessages(
    messages: [],
    toolResults: [],
    usageUpdates: [],
    maxSeq: 0,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Encryption implements Encryption {
  _Encryption(this.session);
  final SessionEncryption session;
  int ids = 0;

  @override
  SessionEncryption? getSessionEncryption(String sessionId) => session;

  @override
  String generateId() => 'local-${++ids}';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Sync instance;
  late _PausedEncryption encryption;
  late List<String> deliveryOrder;

  setUp(() async {
    instance = createTestSync();
    resetTestSync(instance);
    messageOutbox.dispose();
    InvalidateSync.isBackgrounded = false;
    encryption = _PausedEncryption();
    deliveryOrder = [];
    final now = DateTime.now().millisecondsSinceEpoch;
    instance
      ..testIsInitialized = true
      ..encryption = _Encryption(encryption)
      ..testSocketConnectedOverride = true
      ..testSocketSendOverride = (_, _) {}
      ..testFetchMessagesOverride = (_, _, _) async => <String, dynamic>{
        'messages': <Map<String, dynamic>>[],
        'pagination': <String, dynamic>{'hasMore': false},
      };
    instance.testSessions['fifo'] = Session(
      id: 'fifo',
      seq: 1,
      createdAt: now,
      updatedAt: now,
      active: true,
      activeAt: now,
      metadataVersion: 1,
      agentStateVersion: 1,
      thinking: false,
      presence: 'online',
    );
    instance.testSetLastEphemeralAt('fifo', now);
    await ApiClient().initialize(serverUrl: 'http://localhost');
    ApiClient().testDio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/v3/sessions/fifo/messages') {
            final body = options.data as Map<String, dynamic>;
            final message = (body['messages'] as List<dynamic>).single
                as Map<String, dynamic>;
            final localId = message['localId'] as String;
            deliveryOrder.add(localId);
            handler.resolve(Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{
                'messages': <Map<String, dynamic>>[
                  {
                    'id': 'server-$localId',
                    'localId': localId,
                    'seq': deliveryOrder.length + 1,
                    'createdAt': now,
                  },
                ],
              },
            ));
            return;
          }
          handler.resolve(Response<dynamic>(
            requestOptions: options,
            statusCode: 404,
            data: <String, dynamic>{},
          ));
        },
      ),
    );
  });

  tearDown(() async {
    await instance.shutdown();
    ApiClient().dispose();
    messageOutbox.dispose();
    instance.testSocketConnectedOverride = null;
    instance.testSocketSendOverride = null;
    instance.testFetchMessagesOverride = null;
    InvalidateSync.isBackgrounded = false;
  });

  test('runtime reset during preparation fences the old send', () async {
    final send = instance.sendMessage('fifo', 'continue');
    final rejected = expectLater(
      send,
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        'Send cancelled by runtime reset',
      )),
    );
    await encryption.firstStarted.future;
    final delivery = instance.lastCompleteSendFuture!;
    expect(instance.testSessionMessages('fifo'), hasLength(1));
    try {
      await instance.shutdown();
      resetTestSync(instance);
      // A new initialized runtime must not accept the old continuation.
      instance = createTestSync()..testIsInitialized = true;
    } finally {
      encryption.releaseFirst.complete();
      await rejected;
      await delivery;
    }
    expect(deliveryOrder, isEmpty);
    expect(instance.testSessionMessages('fifo') ?? [], isEmpty);
    expect(instance.testSessions, isEmpty);
  });

  test('preparation failure releases the reserved delivery lane', () async {
    encryption.failFirst = true;
    final first = instance.sendMessage('fifo', 'continue');
    final rejected = expectLater(
      first,
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        'preparation failed',
      )),
    );
    await encryption.firstStarted.future;
    final firstDelivery = instance.lastCompleteSendFuture!;
    final second = instance.sendMessage('fifo', 'continue');
    final secondDelivery = instance.lastCompleteSendFuture!;
    final sharedLane = messageOutbox.serialize<void>('fifo', () async {
      deliveryOrder.add('outbox-lane');
    });
    try {
      await second;
      expect(deliveryOrder, isEmpty);
    } finally {
      encryption.releaseFirst.complete();
      await Future.wait([
        rejected,
        firstDelivery,
        secondDelivery,
        sharedLane,
      ]);
    }
    expect(deliveryOrder, ['local-2', 'outbox-lane']);
    final rows = instance.testSessionMessages('fifo')!;
    expect(rows, hasLength(2));
    final failed = rows.singleWhere((row) => row['localId'] == 'local-1');
    final sent = rows.singleWhere((row) => row['localId'] == 'local-2');
    expect(failed['sendStatus'], 'failed');
    expect(sent['sendStatus'], 'sent');
  });

  test('FIFO send reservation survives out-of-order preparation', () async {
    final first = instance.sendMessage('fifo', 'continue');
    await encryption.firstStarted.future;
    final firstDelivery = instance.lastCompleteSendFuture!;
    final second = instance.sendMessage('fifo', 'continue');
    final secondDelivery = instance.lastCompleteSendFuture!;
    final sharedLane = messageOutbox.serialize<void>('fifo', () async {
      deliveryOrder.add('outbox-lane');
    });
    try {
      await second;
      await Future<void>.delayed(Duration.zero);
      expect(encryption.calls, 2);
      expect(deliveryOrder, isEmpty,
          reason: 'Preparation completion must not determine delivery order');
    } finally {
      encryption.releaseFirst.complete();
      await Future.wait([first, firstDelivery, secondDelivery, sharedLane]);
    }
    expect(deliveryOrder, ['local-1', 'local-2', 'outbox-lane']);
    final rows = instance.testSessionMessages('fifo')!;
    expect(rows, hasLength(2));
    expect(rows.map((row) => row['localId']).toSet(), {'local-1', 'local-2'});
    expect(rows.every((row) => row['sendStatus'] == 'sent'), isTrue);
  });
}
