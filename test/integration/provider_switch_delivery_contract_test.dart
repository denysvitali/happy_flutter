import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/chat_action_notifier.dart';
import 'package:happy_flutter/core/services/message_outbox.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/codex_speed_selection.dart';
import 'package:happy_flutter/core/services/pending_session_configuration.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

import '../helpers/test_helpers.dart';

void main() {
  const sessionId = 'minimax-provider-switch';
  late Sync sync;
  late _TrackingInterceptor http;
  late List<Map<String, dynamic>> spawns;
  final selections = PendingSessionConfiguration();

  setUp(() async {
    InvalidateSync.isBackgrounded = false;
    Sync.testRecentlySpawnedWaitMsOverride = 100;
    Sync.testSpawnHydrateRetryDelaysOverride = const [Duration.zero];
    await MMKVStorage.initialize();
    await MMKVStorage().clearAll();
    messageOutbox.dispose();
    sync = createTestSync();
    sync.testSessions.clear();
    sync.testMachines.clear();
    sync.testClearSessionSpawnedAt();
    sync.testSetSessionMessages(sessionId, []);
    sync.testSettingsSnapshot = Settings();
    sync.encryption = _FakeEncryption();
    sync.testIsInitialized = true;
    sync.testSocketConnectedOverride = true;
    sync.testSocketSendOverride = (_, __) {};
    sync.testFetchMessagesOverride = (_, __, ___) async => {
      'messages': <dynamic>[],
      'hasMore': false,
    };
    sync.testFetchSingleSessionOverride = (_) async => null;
    sync.testGetSpawnEnvVarsOverride = (_) async =>
        (envVars: <String, String>{}, profile: null);
    final now = DateTime.now().millisecondsSinceEpoch;
    sync.testSessions[sessionId] = Session(
      id: sessionId,
      seq: 1,
      createdAt: now,
      updatedAt: now,
      active: true,
      activeAt: now,
      metadataVersion: 1,
      agentStateVersion: 0,
      thinking: false,
      presence: 'online',
      metadata: Metadata(
        host: '',
        machineId: 'machine-1',
        path: '/repo',
        flavor: 'claude',
        model: 'MiniMax-M2.7',
        lifecycleState: 'running',
        lifecycleStateSince: now,
      ),
    );
    sync.testMachines['machine-1'] = Machine(
      id: 'machine-1',
      seq: 1,
      createdAt: now,
      updatedAt: now,
      active: true,
      activeAt: now,
      metadataVersion: 1,
      daemonStateVersion: 0,
    );
    sync.testSetLastEphemeralAt(sessionId, now);
    spawns = [];
    sync.testMachineRPCOverride = (_, method, params) async {
      if (method == 'spawn-happy-session') spawns.add(params);
      return {'type': 'success', 'sessionId': sessionId};
    };
    http = _TrackingInterceptor();
    await ApiClient().initialize(serverUrl: 'http://localhost');
    ApiClient().testDio!.interceptors.add(http);
  });

  tearDown(() async {
    await sync.lastCompleteSendFuture;
    InvalidateSync.isBackgrounded = false;
    messageOutbox.dispose();
    Sync.testResetTimingOverrides();
    sync.testMachineRPCOverride = null;
    sync.testEnsureMachineReachableMachineRPCOverride = null;
    sync.testSocketConnectedOverride = null;
    sync.testSocketSendOverride = null;
    sync.testFetchMessagesOverride = null;
    sync.testFetchSingleSessionOverride = null;
    sync.testGetSpawnEnvVarsOverride = null;
    ApiClient().dispose();
    await MMKVStorage().clearAll();
  });

  test(
    'explicit Default survives lost spawn tracking and applies once',
    () async {
      selections.save(sessionId, profileId: 'default', modelMode: 'default');
      // A new store instance represents reopening the app. No client-run
      // launch history exists, and Default must still replace MiniMax.
      expect(PendingSessionConfiguration().read(sessionId), isNotNull);
      await sync.sendMessage(sessionId, 'continue', clientLocalId: 'first');
      await sync.lastCompleteSendFuture;
      await sync.sendMessage(
        sessionId,
        'continue',
        clientLocalId: 'second',
        profileId: 'default',
        modelMode: 'default',
      );
      await sync.lastCompleteSendFuture;
      expect(spawns, hasLength(1));
      expect(spawns.single['environmentVariables'], {
        'HAPPY_CODEX_FAST_MODE': '0',
      });
      expect(spawns.single['model'], 'default');
      expect(selections.read(sessionId), isNull);
      expect(http.capturedLocalIds, ['first', 'second']);
      expect(sync.testSessionMessages(sessionId), hasLength(2));
    },
  );

  test(
    'Codex speed applies on retry and accepted choices do not respawn',
    () async {
      sync.testSessions[sessionId] = sync.testSessions[sessionId]!.copyWith(
        metadata: sync.testSessions[sessionId]!.metadata!.copyWith(
          flavor: 'codex',
          codexFastMode: false,
        ),
      );
      CodexSpeedSelection().save(sessionId, true);
      selections.save(
        sessionId,
        profileId: 'default',
        modelMode: 'default',
        codexSpeed: 'fast',
      );
      sync.testMachineRPCOverride = (_, method, params) async {
        spawns.add(params);
        return {'type': 'error', 'errorMessage': 'temporary failure'};
      };

      await expectLater(
        sync.sendMessage(sessionId, 'continue', clientLocalId: 'speed-retry'),
        throwsStateError,
      );
      expect(http.capturedLocalIds, isEmpty);
      expect(selections.read(sessionId)?.codexSpeed, 'fast');

      sync.testMachineRPCOverride = (_, method, params) async {
        spawns.add(params);
        return {'type': 'success', 'sessionId': sessionId};
      };
      messageOutbox.testStorage = MMKVStorage();
      final retry = await sync.retryFailedMessage(sessionId, 'speed-retry');
      expect(retry.isQueued, isTrue);
      expect(messageOutbox.entries.single.localId, 'speed-retry');
      expect(spawns.last['environmentVariables'], {
        'HAPPY_CODEX_FAST_MODE': '1',
      });
      expect(selections.read(sessionId), isNull);

      CodexSpeedSelection().save(sessionId, false);
      selections.save(
        sessionId,
        profileId: 'default',
        modelMode: 'default',
        codexSpeed: 'standard',
      );
      await sync.sendMessage(sessionId, 'continue', clientLocalId: 'standard');
      await sync.lastCompleteSendFuture;
      expect(spawns.last['environmentVariables'], {
        'HAPPY_CODEX_FAST_MODE': '0',
      });
      final acceptedSpawnCount = spawns.length;

      await sync.sendMessage(sessionId, 'continue', clientLocalId: 'again');
      await sync.lastCompleteSendFuture;
      expect(spawns, hasLength(acceptedSpawnCount));
    },
  );

  test(
    'newer speed pick survives same-ID and redirected replacements',
    () async {
      final seed = sync.testSessions[sessionId]!;
      final fakeEncryption = sync.encryption as _FakeEncryption;
      final raceCases = <(String sourceId, String restoredId)>[
        (sessionId, sessionId),
        ('redirected-speed-source', 'redirected-speed-result'),
      ];

      for (final (sourceId, restoredId) in raceCases) {
        final sourceSession = seed.copyWith(
          id: sourceId,
          metadata: seed.metadata!.copyWith(
            flavor: 'codex',
            codexFastMode: false,
          ),
        );
        sync.testSessions[sourceId] = sourceSession;
        sync.testSetSessionMessages(sourceId, []);
        sync.testSetLastEphemeralAt(
          sourceId,
          DateTime.now().millisecondsSinceEpoch,
        );
        sync.testClearSessionSpawnedAt();
        CodexSpeedSelection().save(sourceId, true);
        selections.save(
          sourceId,
          profileId: 'default',
          modelMode: 'default',
          codexSpeed: 'fast',
        );
        if (restoredId != sourceId) {
          fakeEncryption.missingSessionIds.add(restoredId);
          sync.sessionsSync = InvalidateSync(() async {
            fakeEncryption.missingSessionIds.remove(restoredId);
          });
        }

        final spawnStarted = Completer<void>();
        final spawnResponse = Completer<Map<String, dynamic>>();
        sync.testMachineRPCOverride = (_, method, params) {
          spawns.add(params);
          if (!spawnStarted.isCompleted) spawnStarted.complete();
          return spawnResponse.future;
        };
        final localId = 'speed-race-$sourceId';
        final sending = sync.sendMessage(
          sourceId,
          'continue',
          clientLocalId: localId,
        );
        await spawnStarted.future;
        CodexSpeedSelection().save(sourceId, false);
        final newer = selections.save(
          sourceId,
          profileId: 'default',
          modelMode: 'default',
          codexSpeed: 'standard',
        );
        spawnResponse.complete({'type': 'success', 'sessionId': restoredId});
        await sending;
        await sync.lastCompleteSendFuture;

        expect(spawns.last['environmentVariables'], {
          'HAPPY_CODEX_FAST_MODE': '1',
        });
        if (restoredId == sourceId) {
          expect(http.capturedLocalIds.last, localId);
          expect(selections.read(sourceId), newer);
        } else {
          expect(
            messageOutbox.entries.map((entry) => entry.localId),
            contains(localId),
          );
          expect(selections.read(sourceId), isNull);
          expect(selections.read(restoredId)?.codexSpeed, 'standard');
          expect(CodexSpeedSelection().read(restoredId), isFalse);
        }
      }
    },
  );

  test(
    'notifier applies explicit Fast when legacy metadata omits its mode',
    () async {
      sync.testSettingsSnapshot = Settings()..codexFastMode = true;
      sync.testSessions[sessionId] = sync.testSessions[sessionId]!.copyWith(
        metadata: sync.testSessions[sessionId]!.metadata!.copyWith(
          flavor: 'codex',
          codexFastMode: null,
        ),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(chatActionNotifierProvider.notifier)
          .saveCodexFastMode(
            sessionId,
            true,
            profileId: null,
            modelMode: 'default',
          );
      expect(selections.read(sessionId)?.codexSpeed, 'fast');

      await sync.sendMessage(
        sessionId,
        'continue',
        clientLocalId: 'legacy-speed',
      );
      await sync.lastCompleteSendFuture;

      expect(spawns, hasLength(1));
      expect(spawns.single['environmentVariables'], {
        'HAPPY_CODEX_FAST_MODE': '1',
      });
      expect(sync.testSessions[sessionId]?.metadata?.codexFastMode, isTrue);
    },
  );

  test(
    'runtime reset during encryption sync blocks stale speed metadata',
    () async {
      const restoredId = 'runtime-reset-speed-restore';
      sync.testSessions[sessionId] = sync.testSessions[sessionId]!.copyWith(
        metadata: sync.testSessions[sessionId]!.metadata!.copyWith(
          flavor: 'codex',
          codexFastMode: false,
        ),
      );
      CodexSpeedSelection().save(sessionId, true);
      selections.save(
        sessionId,
        profileId: 'default',
        modelMode: 'default',
        codexSpeed: 'fast',
      );
      final fakeEncryption = sync.encryption as _FakeEncryption;
      fakeEncryption.missingSessionIds.add(restoredId);
      final syncStarted = Completer<void>();
      final releaseSync = Completer<void>();
      sync.sessionsSync = InvalidateSync(() async {
        if (!syncStarted.isCompleted) syncStarted.complete();
        await releaseSync.future;
        sync.testAdvanceRuntimeGeneration();
        fakeEncryption.missingSessionIds.remove(restoredId);
      });
      addTearDown(sync.testClearSpawnGuardState);
      sync.testMachineRPCOverride = (_, method, params) async => {
        'type': 'success',
        'sessionId': restoredId,
      };

      final sending = expectLater(
        sync.sendMessage(sessionId, 'continue', clientLocalId: 'runtime-speed'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('cancelled by runtime reset'),
          ),
        ),
      );
      await syncStarted.future;
      releaseSync.complete();
      await sending;

      expect(sync.testSessions[restoredId]?.metadata?.codexFastMode, isNull);
      expect(selections.read(sessionId)?.codexSpeed, 'fast');
      expect(selections.read(restoredId), isNull);
      expect(CodexSpeedSelection().read(restoredId), isNull);
    },
  );

  test('pending switch waits for handler readiness before dispatch', () async {
    selections.save(sessionId, profileId: 'default', modelMode: 'default');
    final events = <String>[];
    sync.testEnsureMachineReachableMachineRPCOverride = (_, __, ___) async {
      events.add('ping');
      if (events.length == 1) {
        throw const RpcException(
          code: RpcErrorCode.handlerOffline,
          message: 'reconnecting',
          retryable: true,
        );
      }
      return {'ok': true, 'result': ''};
    };
    sync.testMachineRPCOverride = (_, method, params) async {
      events.add(method);
      spawns.add(params);
      return {'type': 'success', 'sessionId': sessionId};
    };
    await sync.sendMessage(
      sessionId,
      'continue',
      clientLocalId: 'readiness-id',
    );
    await sync.lastCompleteSendFuture;
    expect(events, ['ping', 'ping', 'spawn-happy-session']);
    expect(spawns, hasLength(1));
    expect(http.capturedLocalIds, ['readiness-id']);
    expect(
      sync.testSessionMessages(sessionId)!.single['localId'],
      'readiness-id',
    );
    expect(selections.read(sessionId), isNull);
  });

  test('confirmed spawn survives backgrounding after dispatch', () async {
    sync.testMachineRPCOverride = (_, method, params) async {
      expect(method, 'spawn-happy-session');
      spawns.add(params);
      InvalidateSync.isBackgrounded = true;
      return {'type': 'success', 'sessionId': sessionId};
    };
    final created = await sync.createSession(
      agent: 'claude',
      machineId: 'machine-1',
      path: '/repo',
    );
    expect(created, sessionId);
    expect(spawns, hasLength(1));
    expect(sync.testSessionSpawnedAt, contains(sessionId));
  });

  for (final error in [
    const SocketAckTimeoutException('rpc-call'),
    const SocketNotConnectedException('rpc-call'),
  ]) {
    test(
      'createSession never replays uncertain ${error.runtimeType}',
      () async {
        sync.testMachineRPCOverride = (_, method, params) async {
          expect(method, 'spawn-happy-session');
          spawns.add(params);
          throw error;
        };
        await expectLater(
          sync.createSession(
            agent: 'claude',
            machineId: 'machine-1',
            path: '/repo',
          ),
          throwsA(same(error)),
        );
        expect(spawns, hasLength(1));
      },
    );
  }

  for (final failure in ['response', 'exception', 'ack', 'terminal']) {
    test('failed $failure replacement never delivers to MiniMax', () async {
      sync.testSetSessionSpawnedProfile(sessionId, 'minimax');
      sync.testMachineRPCOverride = (_, method, params) async {
        if (method == 'spawn-happy-session') {
          spawns.add(params);
          if (failure == 'ack') {
            throw const SocketAckTimeoutException('rpc-call');
          }
          if (failure == 'exception') {
            throw const RpcException(
              code: RpcErrorCode.handlerOffline,
              message: 'Timed out',
              retryable: true,
            );
          }
          return {
            'type': 'error',
            'errorMessage': failure == 'terminal'
                ? 'is in terminal state; refusing stale spawn'
                : 'spawn failed',
          };
        }
        return {'type': 'success'};
      };
      for (final id in ['first', 'second']) {
        await expectLater(
          sync.sendMessage(
            sessionId,
            'continue',
            clientLocalId: id,
            profileId: 'anthropic',
            modelMode: 'sonnet:medium',
          ),
          throwsStateError,
        );
      }
      await sync.lastCompleteSendFuture;
      expect(spawns, hasLength(2));
      expect(http.capturedLocalIds, isEmpty);
      final rows = sync.testSessionMessages(sessionId)!;
      expect(rows.map((m) => m['localId']), ['first', 'second']);
      expect(rows.every((m) => m['sendStatus'] == 'failed'), isTrue);
      expect(selections.read(sessionId)?.profileId, 'anthropic');

      // Retry uses the original identity and must retry the provider change
      // before an outbox entry can ever deliver to the old process.
      await expectLater(
        sync.retryFailedMessage(sessionId, 'first'),
        throwsStateError,
      );
      expect(spawns, hasLength(3));
      expect(http.capturedLocalIds, isEmpty);
      expect(sync.testSessionMessages(sessionId), hasLength(2));
    });
  }

  test(
    'offline machine blocks a pending switch before message delivery',
    () async {
      selections.save(sessionId, profileId: 'default', modelMode: 'sonnet');
      sync.testMachines['machine-1'] = sync.testMachines['machine-1']!.copyWith(
        active: false,
        activeAt: 0,
      );
      await expectLater(
        sync.sendMessage(sessionId, 'continue'),
        throwsStateError,
      );
      expect(http.capturedLocalIds, isEmpty);
      expect(selections.read(sessionId), isNotNull);
    },
  );

  test(
    'concurrent sends cannot inherit a failed replacement fallback',
    () async {
      selections.save(
        sessionId,
        profileId: 'anthropic',
        modelMode: 'sonnet:medium',
      );
      final started = Completer<void>();
      final response = Completer<Map<String, dynamic>>();
      sync.testMachineRPCOverride = (_, method, params) async {
        spawns.add(params);
        if (!started.isCompleted) started.complete();
        return response.future;
      };
      final first = expectLater(
        sync.sendMessage(sessionId, 'continue', clientLocalId: 'first'),
        throwsStateError,
      );
      await started.future;
      final second = expectLater(
        sync.sendMessage(sessionId, 'continue', clientLocalId: 'second'),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);
      response.complete({'type': 'error', 'errorMessage': 'spawn failed'});
      await Future.wait([first, second]);
      expect(http.capturedLocalIds, isEmpty);
      expect(sync.testSessionMessages(sessionId), hasLength(2));
    },
  );

  test(
    'successful Retry applies the selection and queues the same localId',
    () async {
      selections.save(
        sessionId,
        profileId: 'anthropic',
        modelMode: 'sonnet:medium',
      );
      sync.testMachineRPCOverride = (_, method, params) async => {
        'type': 'error',
        'errorMessage': 'temporary failure',
      };
      await expectLater(
        sync.sendMessage(sessionId, 'continue', clientLocalId: 'retry-id'),
        throwsStateError,
      );
      sync.testMachineRPCOverride = (_, method, params) async {
        spawns.add(params);
        return {'type': 'success', 'sessionId': sessionId};
      };
      messageOutbox.testStorage = MMKVStorage();
      final result = await sync.retryFailedMessage(sessionId, 'retry-id');
      expect(result.isQueued, isTrue);
      expect(spawns.single['model'], 'sonnet:medium');
      expect(selections.read(sessionId), isNull);
      expect(messageOutbox.entries.single.localId, 'retry-id');
      expect(
        sync.testSessionMessages(sessionId)!.single['localId'],
        'retry-id',
      );

      // Socket echo before outbox completion must replace by identity, even
      // if an old HTTP acknowledgement arrives again afterwards.
      final echo = <String, dynamic>{
        'id': 'server-retry',
        'localId': 'retry-id',
        'seq': 1,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'role': 'user',
        'kind': 'text',
        'content': 'continue',
      };
      sync.testUpsertSessionMessages(sessionId, [echo]);
      sync.testUpsertSessionMessages(sessionId, [echo]);
      final rows = sync.testSessionMessages(sessionId)!;
      expect(rows, hasLength(1));
      expect(rows.single['id'], 'server-retry');
    },
  );

  test(
    'pending selection overrides the recently spawned grace period',
    () async {
      sync.testRegisterSpawn(
        sessionId,
        profileId: 'minimax',
        modelMode: 'MiniMax-M2.7',
        agent: 'claude',
      );
      final session = sync.testSessions[sessionId]!;
      sync.testSessions[sessionId] = session.copyWith(
        presence: 'offline',
        metadata: session.metadata!.copyWith(lifecycleState: 'exited'),
      );
      sync.testLastEphemeralAt.remove(sessionId);
      selections.save(sessionId, profileId: 'default', modelMode: 'sonnet');
      await sync.sendMessage(sessionId, 'continue');
      await sync.lastCompleteSendFuture;
      expect(spawns, hasLength(1));
      expect(spawns.single['model'], 'sonnet');
    },
  );

  test(
    'unresolved explicit profile cannot silently use the default provider',
    () async {
      sync.testGetSpawnEnvVarsOverride = null;
      await expectLater(
        sync.sendMessage(
          sessionId,
          'continue',
          profileId: 'missing-profile',
          modelMode: 'sonnet',
        ),
        throwsStateError,
      );
      expect(http.capturedLocalIds, isEmpty);
      expect(spawns, isEmpty);
      expect(selections.read(sessionId)?.profileId, 'missing-profile');
    },
  );

  test('acknowledging an older selection preserves a newer picker change', () {
    final first = selections.save(
      sessionId,
      profileId: 'anthropic',
      modelMode: 'sonnet:medium',
    );
    selections.save(sessionId, profileId: 'anthropic', modelMode: 'opus');
    selections.clearIfCurrent(sessionId, first);
    expect(selections.read(sessionId)?.modelMode, 'opus');
  });
}

class _TrackingInterceptor extends Interceptor {
  final List<String> capturedLocalIds = [];
  int _seqCounter = 1;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final isMessagesPath =
        options.path.contains('/v3/sessions/') &&
        options.path.contains('/messages');
    final isPost = options.method.toUpperCase() == 'POST';

    // Only intercept POST to the messages endpoint.
    if (isMessagesPath && isPost) {
      final localId = _extractLocalId(options.data);
      if (localId != null) {
        capturedLocalIds.add(localId);
      }
      final seq = _seqCounter++;
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'messages': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'srv-$seq',
                'seq': seq,
                'localId': localId,
                'createdAt': DateTime.now().millisecondsSinceEpoch,
              },
            ],
          },
        ),
      );
      return;
    }

    // GET or other requests: return 200 with empty data
    // so fetchMessages doesn't trigger 404 cleanup.
    handler.resolve(
      Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: <String, dynamic>{
          'messages': <Map<String, dynamic>>[],
          'hasMore': false,
        },
      ),
    );
  }

  String? _extractLocalId(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final msgs = data['messages'] as List<dynamic>?;
    if (msgs == null || msgs.isEmpty) return null;
    final first = msgs.first;
    if (first is! Map<String, dynamic>) return null;
    return first['localId'] as String?;
  }
}

// ---------------------------------------------------------------------------
// Fake encryption
// ---------------------------------------------------------------------------

class _FakeEncryption implements Encryption {
  final Map<String, _FakeSessionEncryption> _sessions = {};
  final Set<String> missingSessionIds = {};

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    if (missingSessionIds.contains(sessionId)) return null;
    return _sessions.putIfAbsent(
      sessionId,
      () => _FakeSessionEncryption(sessionId: sessionId),
    );
  }

  @override
  String generateId() => 'test-local-${DateTime.now().microsecondsSinceEpoch}';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSessionEncryption extends SessionEncryption {
  _FakeSessionEncryption({required String sessionId})
    : super(
        sessionId: sessionId,
        encryptor: _FakeEncryptor(),
        decryptor: _FakeEncryptor(),
        cache: EncryptionCache(),
      );
}

class _FakeEncryptor implements Encryptor {
  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    return data.map((item) {
      final jsonStr = jsonEncode(item);
      final bytes = utf8.encode(jsonStr);
      final output = Uint8List(bytes.length + 1);
      output[0] = 0x01;
      output.setRange(1, output.length, bytes);
      return output;
    }).toList();
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    return data.map((item) {
      if (item.isEmpty) return null;
      try {
        return item[0] == 0x01
            ? jsonDecode(utf8.decode(item.sublist(1)))
            : utf8.decode(item);
      } catch (_) {
        return null;
      }
    }).toList();
  }
}
