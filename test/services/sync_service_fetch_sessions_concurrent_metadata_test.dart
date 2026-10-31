import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

class _VersionedEncryption implements Encryption {
  final SessionEncryption _sessionEncryption = _VersionedSessionEncryption();

  @override
  Future<void> initializeSessions(Map<String, Uint8List?> sessions) async {}

  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      _sessionEncryption;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The wire "ciphertext" is the plaintext lifecycle state.
class _VersionedSessionEncryption implements SessionEncryption {
  @override
  Future<Map<String, dynamic>?> decryptMetadata(
    int version,
    String encrypted,
  ) async => {'host': 'h', 'lifecycleState': encrypted};

  @override
  Future<Map<String, dynamic>> decryptAgentState(
    int version,
    String? encrypted,
  ) async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Session _session(String id, {required int metadataVersion, String? state}) =>
    Session(
      id: id,
      seq: 1,
      createdAt: 1,
      updatedAt: 1,
      active: true,
      activeAt: 1,
      archived: false,
      metadata: Metadata(host: 'h', lifecycleState: state),
      metadataVersion: metadataVersion,
      agentStateVersion: 0,
      thinking: false,
      presence: 'online',
    );

Map<String, dynamic> _wireSession(
  String id, {
  required int metadataVersion,
  required String state,
}) => {
  'id': id,
  'seq': 1,
  'createdAt': 1,
  'updatedAt': 1,
  'active': true,
  'activeAt': 1,
  'archived': false,
  'metadata': state,
  'metadataVersion': metadataVersion,
  'agentStateVersion': 0,
};

void main() {
  late Sync sync;
  const id = 'concurrent-metadata';

  setUp(() async {
    sync = createTestSync();
    resetTestSync(sync);
    sync
      ..testIsInitialized = true
      ..testForceFullFetchNext = false
      ..encryption = _VersionedEncryption();
    await ApiClient().initialize(serverUrl: 'http://localhost');
  });

  tearDown(() {
    ApiClient().dispose();
    sync.testIsInitialized = false;
    resetTestSync(sync);
  });

  Future<void> fetchWithConcurrentThinkingPatch(
    Map<String, dynamic> wire,
  ) async {
    final requestStarted = Completer<void>();
    late RequestOptions requestOptions;
    late RequestInterceptorHandler responseHandler;
    ApiClient().testDio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestOptions = options;
          responseHandler = handler;
          requestStarted.complete();
        },
      ),
    );

    final fetching = sync.fetchSessions();
    await requestStarted.future;
    // A streaming session is patched by update-session while the fetch runs.
    await sync.handleUpdate({
      't': 'update-session',
      'id': id,
      'thinking': true,
      'thinkingAt': 2,
    });
    responseHandler.resolve(
      Response<dynamic>(
        requestOptions: requestOptions,
        statusCode: 200,
        data: {
          'sessions': [wire],
          'hasNext': false,
        },
      ),
    );
    await fetching;
  }

  test(
    'Sync_fetchSessions_newerMetadataReplacesStaleLifecycleDuringStreaming',
    () async {
      sync.testSessions[id] = _session(
        id,
        metadataVersion: 14,
        state: 'errored',
      );

      await fetchWithConcurrentThinkingPatch(
        _wireSession(id, metadataVersion: 16, state: 'running'),
      );

      final session = sync.sessions[id]!;
      expect(session.metadata?.lifecycleState, 'running');
      expect(session.metadataVersion, 16);
      expect(session.hasLifecycleError, isFalse);
      // The live socket patch still wins over the REST snapshot.
      expect(session.thinking, isTrue);
    },
  );

  test(
    'Sync_fetchSessions_optimisticMetadataSurvivesSameVersionResponse',
    () async {
      sync.testSessions[id] = _session(
        id,
        metadataVersion: 14,
        state: 'starting',
      );

      await fetchWithConcurrentThinkingPatch(
        _wireSession(id, metadataVersion: 14, state: 'errored'),
      );

      expect(sync.sessions[id]?.metadata?.lifecycleState, 'starting');
    },
  );
}
