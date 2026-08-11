import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

class _FakeSessionEncryption implements SessionEncryption {
  _FakeSessionEncryption({required this.metadata, required this.agentState});

  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> agentState;

  @override
  Future<Map<String, dynamic>?> decryptMetadata(
    int version,
    String encrypted,
  ) async {
    return metadata;
  }

  @override
  Future<Map<String, dynamic>> decryptAgentState(
    int version,
    String? encrypted,
  ) async {
    return agentState;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEncryption implements Encryption {
  _FakeEncryption(this.sessionEncryption);

  final SessionEncryption sessionEncryption;

  @override
  Future<void> initializeSessions(Map<String, Uint8List?> sessions) async {}

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return sessionEncryption;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Sync.fetchSessions compatibility', () {
    late Sync instance;

    setUp(() async {
      instance = Sync();
      instance.testSessions.clear();
      instance.testLastSessionsFetchedAt = null;
      instance.testForceFullFetchNext = false;
      instance.testIsInitialized = true;

      instance.encryption = _FakeEncryption(
        _FakeSessionEncryption(
          metadata: <String, dynamic>{
            'path': '/legacy/project',
            'host': null,
            'summary': <String, dynamic>{
              'text': 'Legacy summary',
              'updatedAt': 'not-an-int',
            },
            'tools': <dynamic>['bash', 7],
          },
          agentState: <String, dynamic>{},
        ),
      );

      await ApiClient().initialize(serverUrl: 'http://localhost');
    });

    tearDown(() {
      ApiClient().dispose();
      instance.testSessions.clear();
      instance.testLastSessionsFetchedAt = null;
      instance.testForceFullFetchNext = false;
      instance.testIsInitialized = false;
    });

    test(
      'retains sessions when metadata payload has legacy-invalid fields',
      () async {
        ApiClient().testDio!.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/v2/sessions') {
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: <String, dynamic>{
                      'sessions': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'id': 'legacy-session-1',
                          'seq': 1,
                          'createdAt': 1700000000000,
                          'updatedAt': 1700000000001,
                          'active': false,
                          'activeAt': 1700000000001,
                          'metadata': 'opaque-payload',
                          'metadataVersion': 1,
                          'agentState': null,
                          'agentStateVersion': 1,
                          'dataEncryptionKey': null,
                          'lastSeq': 4,
                        },
                      ],
                      'hasNext': false,
                      'nextCursor': null,
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

        await instance.fetchSessions();

        final session = instance.sessions['legacy-session-1'];
        expect(session, isNotNull);
        expect(session?.metadata, isNotNull);
        expect(session?.metadata?.host, '');
        expect(session?.metadata?.summary, isNull);
        expect(session?.metadata?.tools, <String>['bash']);
      },
    );

    test(
      'delta fetch preserves existing timestamps when server omits them',
      () async {
        // Seed an existing session with known older timestamps. This
        // simulates a session that hasn't been touched in a while.
        const oldTimestamp = 1700000000000; // 2023-11-14
        instance.testSessions['delta-session'] = Session(
          id: 'delta-session',
          seq: 5,
          createdAt: oldTimestamp,
          updatedAt: oldTimestamp,
          active: false,
          activeAt: oldTimestamp,
          metadataVersion: 0,
          agentStateVersion: 0,
          thinking: false,
          presence: 'offline',
        );
        // Mark a delta-fetch baseline so the next fetch is incremental.
        instance.testLastSessionsFetchedAt = oldTimestamp + 1;

        ApiClient().testDio!.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/v2/sessions') {
                // Server returns a delta payload that omits the
                // timestamp fields entirely (only the fields that
                // changed are sent on the wire).
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: <String, dynamic>{
                      'sessions': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'id': 'delta-session',
                          'seq': 6,
                          // No createdAt / updatedAt / activeAt here —
                          // the server only sends fields that changed.
                          'metadata': 'opaque-payload',
                          'metadataVersion': 1,
                          'agentState': null,
                          'agentStateVersion': 1,
                          'dataEncryptionKey': null,
                          'lastSeq': 6,
                        },
                      ],
                      'hasNext': false,
                      'nextCursor': null,
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

        await instance.fetchSessions();

        final session = instance.sessions['delta-session'];
        expect(session, isNotNull);
        // Critical: timestamps must not be stamped with DateTime.now().
        // If they were, the session would jump to the top of the list
        // and show "just now" until re-fetched individually.
        expect(session?.createdAt, oldTimestamp);
        expect(session?.updatedAt, oldTimestamp);
        expect(session?.activeAt, oldTimestamp);
      },
    );

    test(
      'does not emit message changes when permission enrichment is unchanged',
      () async {
        var messageChanges = 0;
        final sub = instance.onSessionMessagesChanged.listen((_) {
          messageChanges++;
        });
        addTearDown(sub.cancel);

        instance.testSetSessionMessages('existing-session', [
          <String, dynamic>{
            'id': 'message-1',
            'seq': 1,
            'role': 'user',
            'kind': 'text',
            'content': 'hello',
          },
        ]);

        ApiClient().testDio!.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/v2/sessions') {
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: <String, dynamic>{
                      'sessions': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'id': 'existing-session',
                          'seq': 1,
                          'createdAt': 1700000000000,
                          'updatedAt': 1700000000001,
                          'active': false,
                          'activeAt': 1700000000001,
                          'metadata': 'opaque-payload',
                          'metadataVersion': 1,
                          'agentState': null,
                          'agentStateVersion': 1,
                          'dataEncryptionKey': null,
                          'lastSeq': 1,
                        },
                      ],
                      'hasNext': false,
                      'nextCursor': null,
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

        await instance.fetchSessions();

        expect(messageChanges, 0);
      },
    );
  });
}
