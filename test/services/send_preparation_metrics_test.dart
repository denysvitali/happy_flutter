import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/opentelemetry_service.dart';

import '../helpers/test_helpers.dart';

class _MetricSessionEncryption implements SessionEncryption {
  @override
  bool get canDecryptAes => false;

  @override
  Future<String> encryptRawRecord(Map<String, dynamic> record) async {
    return 'encrypted-content';
  }

  @override
  Future<ProcessedMessages> decryptAndProcessMessages(
    List<Map<String, dynamic>> messages,
    String sessionId,
  ) async {
    return const ProcessedMessages(
      messages: <Map<String, dynamic>>[],
      toolResults: <Map<String, dynamic>>[],
      usageUpdates: <Map<String, dynamic>>[],
      maxSeq: 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MetricEncryption implements Encryption {
  _MetricEncryption(this.sessionEncryption);

  final SessionEncryption sessionEncryption;

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return sessionEncryption;
  }

  @override
  String generateId() => 'local-observability-contract';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('send preparation emits bounded subphase metrics without changing '
      'the canonical localId contract', () async {
    final samples = <(String, Duration, Map<String, Object?>)>[];
    OpenTelemetryService.debugDurationSink = (name, duration, attributes) {
      samples.add((name, duration, attributes));
    };
    addTearDown(() => OpenTelemetryService.debugDurationSink = null);

    final sync = createTestSync();
    sync.testIsInitialized = true;
    sync.testSessions.clear();
    sync.testClearSessionMessageState('sess-observability');
    sync.testSessions['sess-observability'] = const Session(
      id: 'sess-observability',
      seq: 0,
      createdAt: 0,
      updatedAt: 0,
      active: true,
      activeAt: 0,
      metadataVersion: 0,
      agentStateVersion: 0,
      thinking: false,
      presence: 'online',
      lifecycleStateCleartext: 'running',
      metadata: Metadata(lifecycleState: 'running', flavor: 'claude'),
    );
    sync.testSetLastEphemeralAt(
      'sess-observability',
      DateTime.now().millisecondsSinceEpoch,
    );
    sync.encryption = _MetricEncryption(_MetricSessionEncryption());

    await ApiClient().initialize(serverUrl: 'http://localhost');
    ApiClient().testDio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: const <String, dynamic>{
                'messages': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'server-observability',
                    'seq': 1,
                    'localId': 'local-observability-contract',
                    'createdAt': 1,
                  },
                ],
              },
            ),
            true,
          );
        },
      ),
    );
    addTearDown(ApiClient().dispose);

    await sync.sendMessage('sess-observability', 'same text');
    await sync.lastCompleteSendFuture;

    final phases = samples
        .where((sample) => sample.$1 == 'app.chat.send.prepare')
        .map((sample) => sample.$3['phase'])
        .toSet();
    expect(
      phases,
      containsAll(<String>{
        'encryption_context',
        'session_context',
        'send_options',
        'target_resolution',
        'payload_build',
        'optimistic_insert',
        'encryption',
        'total',
      }),
    );

    for (final sample in samples.where(
      (sample) => sample.$1 == 'app.chat.send.prepare',
    )) {
      expect(sample.$3.keys, isNot(contains('session.id')));
      expect(sample.$3.keys, isNot(contains('message.local_id')));
      expect(sample.$3.keys, isNot(contains('message.text')));
    }

    final logicalMessages = sync.messagesForSession('sess-observability');
    expect(logicalMessages, hasLength(1));
    expect(logicalMessages.single['localId'], 'local-observability-contract');
    expect(logicalMessages.single['sendStatus'], 'sent');

    sync.testIsInitialized = false;
    sync.testSessions.clear();
    sync.testClearSessionMessageState('sess-observability');
  });
}
