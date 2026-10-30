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

class _ArchiveEncryption implements Encryption {
  final SessionEncryption _sessionEncryption = _ArchiveSessionEncryption();

  @override
  Future<void> initializeSessions(Map<String, Uint8List?> sessions) async {}

  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      _sessionEncryption;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ArchiveSessionEncryption implements SessionEncryption {
  @override
  Future<Map<String, dynamic>?> decryptMetadata(
    int version,
    String encrypted,
  ) async => null;

  @override
  Future<Map<String, dynamic>> decryptAgentState(
    int version,
    String? encrypted,
  ) async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Session _session(String id, {bool archived = false}) => Session(
  id: id,
  seq: 1,
  createdAt: 1,
  updatedAt: 1,
  active: false,
  activeAt: 1,
  archived: archived,
  metadataVersion: 0,
  agentStateVersion: 0,
  thinking: false,
  presence: 'offline',
);

Map<String, dynamic> _wireSession(String id, {bool archived = false}) => {
  'id': id,
  'seq': 1,
  'createdAt': 1,
  'updatedAt': 1,
  'active': false,
  'activeAt': 1,
  'archived': archived,
  'metadataVersion': 0,
  'agentStateVersion': 0,
};

void main() {
  late Sync sync;
  const id = 'archive-reconciliation';

  setUp(() async {
    sync = createTestSync();
    resetTestSync(sync);
    sync
      ..testIsInitialized = true
      ..testForceFullFetchNext = false
      ..encryption = _ArchiveEncryption();
    sync.testSessions[id] = _session(id);
    await ApiClient().initialize(serverUrl: 'http://localhost');
  });

  tearDown(() {
    ApiClient().dispose();
    sync.testIsInitialized = false;
    resetTestSync(sync);
  });

  Future<void> archiveEvent(bool archived) => sync.handleUpdate({
    't': 'archive-session',
    'sid': id,
    'archived': archived,
  });

  void catalogResponse(bool Function() archived) {
    ApiClient().testDio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'sessions': [_wireSession(id, archived: archived())],
              'hasNext': false,
            },
          ),
        ),
      ),
    );
  }

  test('primary catalog repairs a missed remote unarchive event', () async {
    var serverArchived = true;
    catalogResponse(() => serverArchived);

    await archiveEvent(true);
    expect(sync.sessions[id]?.archived, isTrue);
    expect(sync.isSessionOptimisticallyArchived(id), isFalse);
    await sync.fetchSessions();
    expect(sync.sessions[id]?.archived, isTrue);

    // Another device unarchives while this app misses its socket event.
    serverArchived = false;
    await sync.fetchSessions();

    expect(sync.sessions[id]?.archived, isFalse);
    expect(sync.getOptimisticallyArchivedIds(), isEmpty);
  });

  test('explicit local archive survives remote archive and catalog', () async {
    catalogResponse(() => false);
    sync.markSessionArchived(id);

    await archiveEvent(true);
    await sync.fetchSessions();

    expect(sync.sessions[id]?.archived, isFalse);
    expect(sync.isSessionOptimisticallyArchived(id), isTrue);
  });

  for (final action in ['archive', 'unarchive', 'local-archive', 'delete']) {
    test(
      '$action during a catalog fetch survives its stale response',
      () async {
        final requestStarted = Completer<void>();
        late RequestOptions requestOptions;
        late RequestInterceptorHandler responseHandler;
        // A pending unarchive must also release the explicit local hide.
        if (action == 'unarchive') {
          sync.testSessions[id] = _session(id, archived: true);
          sync.markSessionArchived(id);
        }
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
        switch (action) {
          case 'archive':
            await archiveEvent(true);
          case 'unarchive':
            await archiveEvent(false);
          case 'local-archive':
            sync.markSessionArchived(id);
          case 'delete':
            await archiveEvent(true);
            await sync.handleUpdate({'t': 'delete-session', 'sid': id});
        }
        responseHandler.resolve(
          Response<dynamic>(
            requestOptions: requestOptions,
            statusCode: 200,
            data: {
              'sessions': [_wireSession(id, archived: action == 'unarchive')],
              'hasNext': false,
            },
          ),
        );
        await fetching;

        if (action == 'delete') {
          expect(sync.sessions.containsKey(id), isFalse);
        } else {
          expect(sync.sessions[id]?.archived, action == 'archive');
        }
        expect(
          sync.isSessionOptimisticallyArchived(id),
          action == 'local-archive',
        );
      },
    );
  }
}
