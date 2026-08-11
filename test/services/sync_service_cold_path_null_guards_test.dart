import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

/// Regression coverage for the production fatal HAPPY_FLUTTER-17O,
/// "Null check operator used on a null value" (2,518 hits) — observed
/// on the sessions cold-path after `_invalidateAllSyncs` logs
/// "Invalidated critical syncs (sessions)".
///
/// These tests construct sessions cold-path inputs with missing /
/// stale fields and assert that the new defensive guards do not
/// crash. The previous code paths used `_sessions[sid]!` and
/// `_visibleSessionId!` after `containsKey` / `!= null` checks; this
/// suite covers the cases where a racing mutation or a malformed
/// payload could surface as a null-check fatal.
class _FakeSessionEncryption implements SessionEncryption {
  _FakeSessionEncryption();

  @override
  Future<Map<String, dynamic>?> decryptMetadata(
    int version,
    String encrypted,
  ) async => <String, dynamic>{'path': '/p'};

  @override
  Future<Map<String, dynamic>> decryptAgentState(
    int version,
    String? encrypted,
  ) async => <String, dynamic>{};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEncryption implements Encryption {
  _FakeEncryption(this._inner);

  final SessionEncryption _inner;

  @override
  Future<void> initializeSessions(Map<String, Uint8List?> sessions) async {}

  @override
  SessionEncryption? getSessionEncryption(String sessionId) => _inner;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Sync cold-path null guards', () {
    late Sync instance;

    setUp(() async {
      instance = Sync();
      instance.testSessions.clear();
      instance.testClearSessionSpawnedAt();
      instance.testLastSessionsFetchedAt = null;
      instance.testForceFullFetchNext = false;
      instance.testIsInitialized = true;
      instance.encryption = _FakeEncryption(_FakeSessionEncryption());
      await ApiClient().initialize(serverUrl: 'http://localhost');
    });

    tearDown(() {
      ApiClient().dispose();
      instance.testSessions.clear();
      instance.testClearSessionSpawnedAt();
      instance.testLastSessionsFetchedAt = null;
      instance.testForceFullFetchNext = false;
      instance.testIsInitialized = false;
    });

    test(
      'full fetch does not crash when spawnedAt entry lacks an in-memory '
      'session (racy delete-session between containsKey and deref)',
      () async {
        // Seed a stale spawnedAt entry whose session row has already been
        // evicted (simulates `_handleDeleteSession` firing between the
        // checks and the `_sessions[sid]!` deref). The previous code
        // would crash here with "Null check operator used on a null
        // value"; the new code should skip the entry safely.
        instance.testSetSessionSpawnedAt(
          'ghost-session',
          DateTime.now().millisecondsSinceEpoch,
        );

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
                          'id': 'real-session',
                          'seq': 1,
                          'createdAt': 1700000000000,
                          'updatedAt': 1700000000001,
                          'active': false,
                          'activeAt': 1700000000001,
                          'metadata': 'opaque',
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

        await expectLater(instance.fetchSessions(), completes);
        // The real session should land. The ghost (spawnedAt without a
        // session row) should be silently dropped, not crash.
        expect(instance.sessions['real-session'], isNotNull);
        expect(instance.sessions.containsKey('ghost-session'), isFalse);
        expect(
          instance.testSyncProgress,
          isNull,
          reason:
              'fetchSessions owns the conversation progress label and must '
              'clear it when the fetch completes, even if other sync work is '
              'still active',
        );
      },
    );

    test('full fetch tolerates missing/malformed top-level fields', () async {
      ApiClient().testDio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/v2/sessions') {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{
                    'sessions': <dynamic>[
                      // Missing id — should be skipped without throwing.
                      <String, dynamic>{'seq': 1, 'createdAt': 1700000000000},
                      // Non-map entry — should be skipped.
                      'not-a-map',
                      // Empty id — should be skipped.
                      <String, dynamic>{'id': ''},
                      // Valid entry — should land.
                      <String, dynamic>{
                        'id': 'good-session',
                        'seq': 1,
                        'createdAt': 1700000000000,
                        'updatedAt': 1700000000001,
                        'active': true,
                        'activeAt': 1700000000001,
                        'metadata': 'opaque',
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

      await expectLater(instance.fetchSessions(), completes);
      expect(instance.sessions.length, 1);
      expect(instance.sessions['good-session'], isNotNull);
    });
  });
}
