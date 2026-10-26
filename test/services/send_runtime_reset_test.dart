import 'dart:async';

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
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

import '../helpers/test_helpers.dart';

class _OutboxStorage extends MMKVStorage {
  _OutboxStorage() : super.testConstructor();
  String? data;
  @override
  Future<String?> getOutboxEntries() async => data;
  @override
  Future<void> saveOutboxEntries(String value) async {
    data = value;
  }
}

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
    messageOutbox.testStorage = _OutboxStorage();
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
            final message =
                (body['messages'] as List<dynamic>).single
                    as Map<String, dynamic>;
            final localId = message['localId'] as String;
            deliveryOrder.add(localId);
            handler.resolve(
              Response<dynamic>(
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

  tearDown(() async {
    await instance.shutdown();
    ApiClient().dispose();
    messageOutbox.dispose();
    instance.testSocketConnectedOverride = null;
    instance.testSessionRPCOverride = null;
    instance.testSocketSendOverride = null;
    instance.testFetchMessagesOverride = null;
    InvalidateSync.isBackgrounded = false;
  });

  test(
    'Har switch cannot overtake a foreground POST after send returns',
    () async {
      const luna = 'codex/gpt-6-luna';
      const sol = 'codex/gpt-6.1-sol';
      instance.testSessions['fifo'] = instance.testSessions['fifo']!.copyWith(
        modelMode: luna,
        metadata: const Metadata(
          host: '',
          flavor: 'har',
          model: luna,
          harRuntimeId: 'runtime-1',
          harModelSwitchBarrier: {'version': 1, 'runtimeId': 'runtime-1'},
          harModels: [
            PrimeAgentModelInfo(id: luna, name: 'Luna'),
            PrimeAgentModelInfo(id: sol, name: 'Sol'),
          ],
        ),
      );
      instance.testSetSessionSpawnedModel('fifo', luna);
      final postStarted = Completer<void>();
      late RequestInterceptorHandler postHandler;
      late RequestOptions postOptions;
      final events = <String>[];
      ApiClient().testDio!.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/v3/sessions/fifo/messages') {
              postHandler = handler;
              postOptions = options;
              events.add('post-start');
              postStarted.complete();
            } else {
              handler.next(options);
            }
          },
        ),
      );
      encryption.releaseFirst.complete();
      await instance.sendMessage('fifo', 'continue', modelMode: luna);
      await postStarted.future;
      final delivery = instance.lastCompleteSendFuture!;
      instance.testSessionRPCOverride = (_, _, params) async {
        expect(params, {
          'model': sol,
          'afterSeq': 2,
          'runtimeId': 'runtime-1',
          'barrierVersion': 1,
        });
        events.add('model-rpc');
        return {'model': sol};
      };
      final switching = instance.setSessionModel('fifo', sol);
      await Future<void>.delayed(Duration.zero);
      expect(events, ['post-start']);
      events.add('post-ack');
      postHandler.resolve(
        Response<dynamic>(
          requestOptions: postOptions,
          statusCode: 200,
          data: <String, dynamic>{
            'messages': [
              {
                'id': 'server-local-1',
                'localId': 'local-1',
                'seq': 2,
                'createdAt': DateTime.now().millisecondsSinceEpoch,
              },
            ],
          },
        ),
      );
      await delivery;
      await switching;
      expect(events, ['post-start', 'post-ack', 'model-rpc']);
      expect(
        instance.testSessionMessages('fifo')!.single['sendStatus'],
        'sent',
      );
      expect(instance.testSessions['fifo']!.metadata!.model, sol);
    },
  );

  for (final useOutbox in [false, true]) {
    test('Har ${useOutbox ? 'outbox' : 'foreground'} delivery waits for '
        'ACK sequence before model switch', () async {
      const luna = 'codex/gpt-6-luna';
      const sol = 'codex/gpt-6.1-sol';
      instance.testSessions['fifo'] = instance.testSessions['fifo']!.copyWith(
        metadata: const Metadata(
          host: '',
          flavor: 'har',
          model: luna,
          harRuntimeId: 'runtime-1',
          harModelSwitchBarrier: {'version': 1, 'runtimeId': 'runtime-1'},
        ),
      );
      ApiClient().testDio!.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/v3/sessions/fifo/messages') {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{'messages': <dynamic>[]},
                ),
              );
            } else {
              handler.next(options);
            }
          },
        ),
      );
      encryption.releaseFirst.complete();
      if (useOutbox) {
        instance.testSetSessionMessages('fifo', [
          {
            'id': 'local-1',
            'localId': 'local-1',
            'role': 'user',
            'sendStatus': 'pending',
            'content': 'continue',
          },
        ]);
        messageOutbox.configure(
          deliver: instance.testDeliverOutboxEntryClassified,
        );
        await messageOutbox.add(
          const OutboxEntry(
            sessionId: 'fifo',
            localId: 'local-1',
            text: 'continue',
            encryptedContent: 'encrypted',
            rawRecord: {
              'meta': {'model': luna},
            },
            queuedAt: 1,
          ),
        );
        await messageOutbox.testAttemptNow('local-1');
        expect(messageOutbox.entries, isEmpty);
      } else {
        await instance.sendMessage('fifo', 'continue');
        await instance.lastCompleteSendFuture;
      }
      expect(
        instance.testSessionMessages('fifo')!.single['sendStatus'],
        useOutbox ? 'sent' : 'pending',
      );
      var rpcCalls = 0;
      instance.testSessionRPCOverride = (_, _, params) async {
        rpcCalls++;
        expect(params, {
          'model': sol,
          'afterSeq': 9,
          'runtimeId': 'runtime-1',
          'barrierVersion': 1,
        });
        return {'model': sol};
      };
      await expectLater(
        instance.setSessionModel('fifo', sol),
        throwsStateError,
      );
      expect(rpcCalls, 0);
      // A matching durable row supplies the missing ACK sequence later.
      instance.testUpsertSessionMessages('fifo', [
        {
          'id': 'server-local-1',
          'localId': 'local-1',
          'seq': 9,
          'role': 'user',
          'sendStatus': 'sent',
          'content': 'continue',
        },
      ]);
      await instance.setSessionModel('fifo', sol);
      expect(rpcCalls, 1);
    });
  }

  test('stale pending and dead outbox cannot regress confirmed sent rows', () {
    for (final id in ['server-id', 'local']) {
      instance.testSetSessionMessages('fifo', [
        {'id': id, 'localId': 'local', 'role': 'user', 'sendStatus': 'sent'},
      ]);
      final entry = OutboxEntry(
        localId: 'local',
        sessionId: 'fifo',
        text: 'continue',
        encryptedContent: 'ciphertext',
        rawRecord: const {},
        queuedAt: 1,
      );
      messageOutbox.testInsertPending(entry);
      expect(instance.reconcileOutboxStatuses('fifo'), 0);
      expect(
        instance.testSessionMessages('fifo')!.single['sendStatus'],
        'sent',
      );
      messageOutbox.dispose();
      messageOutbox.testInsertDead(entry);
      expect(instance.reconcileOutboxStatuses('fifo'), 0);
      expect(
        instance.testSessionMessages('fifo')!.single['sendStatus'],
        'sent',
      );
      messageOutbox.dispose();
    }
  });

  test('runtime reset during preparation fences the old send', () async {
    final send = instance.sendMessage('fifo', 'continue');
    final rejected = expectLater(
      send,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Send cancelled by runtime reset',
        ),
      ),
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
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'preparation failed',
        ),
      ),
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
      await Future.wait([rejected, firstDelivery, secondDelivery, sharedLane]);
    }
    expect(deliveryOrder, ['local-2', 'outbox-lane']);
    final rows = instance.testSessionMessages('fifo')!;
    expect(rows, hasLength(2));
    final failed = rows.singleWhere((row) => row['localId'] == 'local-1');
    final sent = rows.singleWhere((row) => row['localId'] == 'local-2');
    expect(failed['sendStatus'], 'failed');
    expect(sent['sendStatus'], 'sent');
  });

  test(
    'failed foreground head cannot be overtaken by a rapid follow-up',
    () async {
      final attempts = <String>[];
      ApiClient().testDio!.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.endsWith('/messages')) {
              final body = options.data as Map<String, dynamic>;
              final message =
                  (body['messages'] as List<dynamic>).single
                      as Map<String, dynamic>;
              final localId = message['localId'] as String;
              attempts.add(localId);
              if (localId == 'local-1') {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    error: StateError('synthetic transport failure'),
                  ),
                );
                return;
              }
            }
            handler.next(options);
          },
        ),
      );
      final successes = <String>[];
      messageOutbox.configure(
        deliver: (entry) async {
          successes.add(entry.localId);
          return null;
        },
      );
      final first = instance.sendMessage('fifo', 'continue');
      await encryption.firstStarted.future;
      final firstDelivery = instance.lastCompleteSendFuture!;
      final second = instance.sendMessage('fifo', 'continue');
      final secondDelivery = instance.lastCompleteSendFuture!;
      await second;
      encryption.releaseFirst.complete();
      await Future.wait([first, firstDelivery, secondDelivery]);
      expect(attempts, ['local-1']);
      expect(deliveryOrder, isEmpty);
      expect(messageOutbox.entries.map((entry) => entry.localId), [
        'local-1',
        'local-2',
      ]);
      await messageOutbox.testAttemptNow('local-2');
      expect(successes, isEmpty);
      await messageOutbox.testAttemptNow('local-1');
      await messageOutbox.testAttemptNow('local-2');
      expect(successes, ['local-1', 'local-2']);
      expect(instance.testSessionMessages('fifo'), hasLength(2));
    },
  );

  test(
    'pending head queues foreground follow-up and completes its Future',
    () async {
      final storedIds = <String>[];
      var headAttempts = 0;
      messageOutbox.configure(
        deliver: (entry) async {
          if (entry.localId == 'head' && ++headAttempts == 1) {
            return OutboxDeliveryFailure.transient;
          }
          storedIds.add(entry.localId);
          return null;
        },
        onStatusChanged: (_, localId, status) {
          for (final row in instance.testSessionMessages('fifo') ?? []) {
            if (row['localId'] == localId) row['sendStatus'] = status;
          }
        },
      );
      await messageOutbox.add(
        OutboxEntry(
          localId: 'head',
          sessionId: 'fifo',
          text: 'continue',
          encryptedContent: 'head-ciphertext',
          rawRecord: const {},
          queuedAt: 1,
        ),
      );
      await messageOutbox.testAttemptNow('head');
      final followUp = instance.sendMessage('fifo', 'continue');
      await encryption.firstStarted.future;
      encryption.releaseFirst.complete();
      await followUp;
      await instance.lastCompleteSendFuture!;
      expect(deliveryOrder, isEmpty);
      expect(messageOutbox.entries.map((e) => e.localId), ['head', 'local-1']);
      expect(
        instance.testSessionMessages('fifo')!.single['localId'],
        'local-1',
      );
      expect(
        instance.testSessionMessages('fifo')!.single['sendStatus'],
        'pending',
      );
      await messageOutbox.testAttemptNow('head');
      await messageOutbox.testAttemptNow('local-1');
      expect(storedIds, ['head', 'local-1']);
      expect(messageOutbox.entries, isEmpty);
    },
  );

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
      expect(
        deliveryOrder,
        isEmpty,
        reason: 'Preparation completion must not determine delivery order',
      );
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
