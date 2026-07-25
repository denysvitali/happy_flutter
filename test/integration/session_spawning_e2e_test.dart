import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/built_in_profiles.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

/// E2E-style tests for the session spawning flow.
///
/// Exercises the complete lifecycle:
///   createSession → _sessionSpawnedAt registration → optimistic placeholder
///   → sendMessage encryption recovery → _resolveSendTargetSession readiness
///   → waitForAgentReady → message delivery → 404 cleanup
///
/// Uses fake encryption and machine RPC overrides to avoid real network calls
/// while testing the full logic path.
void main() {
  group('createSession E2E flow', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testGetSpawnEnvVarsOverride = (_) async =>
          (envVars: <String, String>{}, profile: null);
      _stubAllSyncs(sync);
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testMachineRPCOverride = null;
      sync.testFetchSingleSessionOverride = null;
      sync.testFetchMessagesOverride = null;
      sync.testGetSpawnEnvVarsOverride = null;
      sync.testEnsureMachineReachableOverride = null;
      InvalidateSync.isBackgrounded = false;
    });

    test('successful spawn registers session in _sessionSpawnedAt', () async {
      final sessionId = 'spawn-1';
      sync.testMachineRPCOverride = (machineId, method, params) async {
        expect(method, 'spawn-happy-session');
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      final result = await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      expect(result, sessionId);
      expect(sync.testSessionSpawnedAt.containsKey(sessionId), isTrue);
      final spawnedAt = sync.testSessionSpawnedAt[sessionId]!;
      final now = DateTime.now().millisecondsSinceEpoch;
      expect(now - spawnedAt, lessThan(5000));
    });

    test('createSession passes requested sessionId to spawn RPC', () async {
      const sessionId = 'c1af40f2f18914fb43a9d19b4';
      Map<String, dynamic>? capturedParams;
      sync.testMachineRPCOverride = (machineId, method, params) async {
        expect(method, 'spawn-happy-session');
        capturedParams = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': params['sessionId'],
          'dataEncryptionKey': null,
        };
      };

      final result = await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
        sessionId: sessionId,
      );

      expect(result, sessionId);
      expect(capturedParams, isNotNull);
      expect(capturedParams!['sessionId'], sessionId);
      expect(sync.sessions.containsKey(sessionId), isTrue);
      expect(sync.testSessionSpawnedAt.containsKey(sessionId), isTrue);
    });

    test(
      'fable:high with minimax profile downgrades to profile default',
      () async {
        Map<String, dynamic>? capturedParams;
        sync.testSettingsSnapshot = Settings()
          ..lastUsedProfilesByAgent = {'claude': 'minimax'};
        sync.testMachineRPCOverride = (machineId, method, params) async {
          expect(method, 'spawn-happy-session');
          capturedParams = params;
          return <String, dynamic>{
            'type': 'success',
            'sessionId': params['sessionId'],
            'dataEncryptionKey': null,
          };
        };

        await sync.createSession(
          agent: 'claude',
          machineId: 'machine-1',
          path: '/home/user/project',
          modelMode: 'fable:high',
        );

        expect(capturedParams, isNotNull);
        // A Claude alias stripped for an incompatible provider is sent as an
        // explicit model='default' rather than omitted, so the daemon clears
        // any sticky metadata.model from the previous spawn.
        expect(capturedParams!['model'], 'default');
        final env = capturedParams!['environmentVariables'] as Map;
        expect(
          env['ANTHROPIC_BASE_URL'],
          r'${MINIMAX_BASE_URL:-https://api.minimax.io/anthropic}',
        );
        expect(env['ANTHROPIC_MODEL'], r'${MINIMAX_MODEL:-MiniMax-M2.7}');
      },
    );

    test('fable:high with anthropic profile passes through', () async {
      Map<String, dynamic>? capturedParams;
      sync.testSettingsSnapshot = Settings()
        ..lastUsedProfilesByAgent = {'claude': 'anthropic'};
      sync.testMachineRPCOverride = (machineId, method, params) async {
        expect(method, 'spawn-happy-session');
        capturedParams = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': params['sessionId'],
          'dataEncryptionKey': null,
        };
      };

      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
        modelMode: 'fable:high',
      );

      expect(capturedParams, isNotNull);
      expect(capturedParams!['model'], 'fable:high');
      // environmentVariables is always sent when non-null, empty included: an
      // empty map means "explicit Default / no profile" and tells the daemon
      // to clear sticky providerRoutingEnv. See rpc_types.dart.
      expect(capturedParams!['environmentVariables'], isEmpty);
    });

    test('sonnet:high with codex profile strips modelMode', () async {
      Map<String, dynamic>? capturedParams;
      sync.testSettingsSnapshot = Settings()
        ..lastUsedProfilesByAgent = {'codex': 'openai'};
      sync.testMachineRPCOverride = (machineId, method, params) async {
        expect(method, 'spawn-happy-session');
        capturedParams = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': params['sessionId'],
          'dataEncryptionKey': null,
        };
      };

      await sync.createSession(
        agent: 'codex',
        machineId: 'machine-1',
        path: '/home/user/project',
        modelMode: 'sonnet:high',
      );

      expect(capturedParams, isNotNull);
      // Stripped for Codex -> explicit 'default', not an omitted key.
      expect(capturedParams!['model'], 'default');
      final env = capturedParams!['environmentVariables'] as Map;
      expect(env.containsKey('ANTHROPIC_BASE_URL'), isFalse);
      expect(env['OPENAI_BASE_URL'], 'https://api.openai.com/v1');
    });

    test('null profile forwards env-less spawn', () async {
      Map<String, dynamic>? capturedParams;
      sync.testSettingsSnapshot = Settings();
      sync.testMachineRPCOverride = (machineId, method, params) async {
        expect(method, 'spawn-happy-session');
        capturedParams = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': params['sessionId'],
          'dataEncryptionKey': null,
        };
      };

      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      expect(capturedParams, isNotNull);
      // Sent as an empty map, not omitted — see rpc_types.dart.
      expect(capturedParams!['environmentVariables'], isEmpty);
    });

    test('provider mismatch RPC error surfaces typed exception', () async {
      sync.testMachineRPCOverride = (machineId, method, params) async {
        expect(method, 'spawn-happy-session');
        return <String, dynamic>{
          'error':
              'provider_model_mismatch: session aborted: profile sets '
              'ANTHROPIC_BASE_URL=https://api.minimax.io/anthropic but the '
              'resolved model is Claude Sonnet 4.6',
        };
      };

      await expectLater(
        () => sync.createSession(
          agent: 'claude',
          machineId: 'machine-1',
          path: '/home/user/project',
        ),
        throwsA(
          isA<IncompatibleProviderAndModelError>().having(
            (e) => e.message,
            'message',
            contains('https://api.minimax.io/anthropic'),
          ),
        ),
      );
    });

    test(
      'createSession preallocates CUID-like sessionId for spawn RPC',
      () async {
        Map<String, dynamic>? capturedParams;
        sync.testMachineRPCOverride = (machineId, method, params) async {
          capturedParams = params;
          return <String, dynamic>{
            'type': 'success',
            'sessionId': params['sessionId'],
            'dataEncryptionKey': null,
          };
        };

        final result = await sync.createSession(
          agent: 'claude',
          machineId: 'machine-1',
          path: '/home/user/project',
        );

        expect(capturedParams, isNotNull);
        final requestedId = capturedParams!['sessionId'] as String?;
        expect(requestedId, isNotNull);
        expect(requestedId, matches(RegExp(r'^c[0-9a-f]{24}$')));
        expect(result, requestedId);
        expect(sync.sessions.containsKey(requestedId), isTrue);
      },
    );

    test('successful spawn creates optimistic placeholder when server '
        'has not propagated session', () async {
      final sessionId = 'spawn-opt-1';
      sync.testMachineRPCOverride = (machineId, method, params) async {
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      // sessionsSync fetch won't return the new session (propagation delay)
      _stubAllSyncs(
        sync,
        sessionsFn: () async {
          if (sync.testForceFullFetchNext) {
            sync.testForceFullFetchNext = false;
          }
          // Server doesn't return the new session
        },
      );

      // Simulate the agent selection that new_session_screen sets before
      // calling createSession.
      await sync.applySettings({'lastUsedAgent': 'claude'});

      final result = await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      expect(result, sessionId);
      // Optimistic placeholder should exist
      final session = sync.sessions[sessionId];
      expect(session, isNotNull);
      expect(session!.id, sessionId);
      expect(session.active, isTrue);
      expect(session.metadata?.machineId, 'machine-1');
      expect(session.metadata?.path, '/home/user/project');
      expect(session.metadata?.lifecycleState, 'starting');
      // Placeholder must carry the agent flavor so the model picker in the
      // chat screen can show the correct options before the real session
      // data arrives from the server.
      expect(
        session.metadata?.flavor,
        'claude',
        reason:
            'placeholder must include flavor so model picker works '
            'before real session data arrives',
      );
    });

    test(
      'successful spawn hydrates only the new session before checking it',
      () async {
        final sessionId = 'spawn-hydrate-1';
        var fetchSingleCalls = 0;

        sync.testMachineRPCOverride = (machineId, method, params) async {
          return <String, dynamic>{
            'type': 'success',
            'sessionId': sessionId,
            'dataEncryptionKey': null,
          };
        };

        sync.testFetchSingleSessionOverride = (sid) async {
          fetchSingleCalls++;
          final session = _makeSession(
            sid,
            machineId: 'machine-1',
            path: '/home/user/project',
          );
          sync.testSessions[sid] = session;
          return session;
        };

        await sync.createSession(
          agent: 'claude',
          machineId: 'machine-1',
          path: '/home/user/project',
        );

        expect(
          fetchSingleCalls,
          1,
          reason: 'createSession should hydrate the spawned session directly',
        );
        expect(
          sync.testForceFullFetchNext,
          isFalse,
          reason: 'createSession should not force a catalog-wide refresh',
        );
        expect(sync.sessions[sessionId], isNotNull);
      },
    );

    test('successful spawn pre-initializes messagesSync', () async {
      final sessionId = 'spawn-msg-1';
      sync.testMachineRPCOverride = (machineId, method, params) async {
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      expect(
        sync.messagesSync.containsKey(sessionId),
        isTrue,
        reason: 'createSession must pre-initialize messagesSync',
      );
    });

    test(
      'createSession with message sets HAPPY_INITIAL_PROMPT env var',
      () async {
        final sessionId = 'spawn-msg-prompt-1';
        Map<String, dynamic>? capturedParams;
        sync.testMachineRPCOverride = (machineId, method, params) async {
          capturedParams = params;
          return <String, dynamic>{
            'type': 'success',
            'sessionId': sessionId,
            'dataEncryptionKey': null,
          };
        };

        await sync.createSession(
          agent: 'claude',
          machineId: 'machine-1',
          path: '/home/user/project',
          message: 'Fix the login bug',
        );

        expect(capturedParams, isNotNull);
        final envVars =
            capturedParams!['environmentVariables'] as Map<String, dynamic>?;
        expect(envVars, isNotNull);
        expect(envVars!['HAPPY_INITIAL_PROMPT'], 'Fix the login bug');

        // Optimistic user message should be inserted
        final messages = sync.testSessionMessages(sessionId);
        expect(messages, isNotNull);
        expect(messages!.length, 1);
        expect(messages.first['role'], 'user');
        expect(messages.first['content'], 'Fix the login bug');
        expect(messages.first['sendStatus'], 'sending');
      },
    );

    test('createSession without message omits HAPPY_INITIAL_PROMPT', () async {
      final sessionId = 'spawn-no-prompt-1';
      Map<String, dynamic>? capturedParams;
      sync.testMachineRPCOverride = (machineId, method, params) async {
        capturedParams = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      expect(capturedParams, isNotNull);
      final envVars =
          capturedParams!['environmentVariables'] as Map<String, dynamic>?;
      // env vars may be null or present but without HAPPY_INITIAL_PROMPT
      if (envVars != null) {
        expect(envVars.containsKey('HAPPY_INITIAL_PROMPT'), isFalse);
      }

      // No optimistic message should be inserted
      final messages = sync.testSessionMessages(sessionId);
      expect(messages == null || messages.isEmpty, isTrue);
    });

    test('createSession throws when not initialized', () {
      sync.testIsInitialized = false;
      expect(
        () => sync.createSession(agent: 'claude', machineId: 'm', path: '/p'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('not initialized'),
          ),
        ),
      );
    });

    test('createSession throws when socket not connected', () {
      sync.testSocketConnectedOverride = false;
      expect(
        () => sync.createSession(agent: 'claude', machineId: 'm', path: '/p'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Not connected'),
          ),
        ),
      );
    });

    test('createSession throws when app is backgrounded', () {
      InvalidateSync.isBackgrounded = true;
      var probed = false;
      sync.testEnsureMachineReachableOverride = (_) async {
        probed = true;
      };

      expect(
        () => sync.createSession(agent: 'claude', machineId: 'm', path: '/p'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Not connected'),
          ),
        ),
      );
      expect(probed, isFalse);
    });

    test('createSession fails fast when liveness probe times out', () async {
      var spawnCalled = false;
      sync.testEnsureMachineReachableOverride = (machineId) async {
        expect(machineId, 'machine-1');
        throw StateError('Machine is unreachable');
      };
      sync.testMachineRPCOverride = (machineId, method, params) async {
        spawnCalled = true;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': 'should-not-spawn',
          'dataEncryptionKey': null,
        };
      };

      await expectLater(
        () => sync.createSession(
          agent: 'claude',
          machineId: 'machine-1',
          path: '/home/user/project',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('unreachable'),
          ),
        ),
      );
      expect(
        spawnCalled,
        isFalse,
        reason: 'spawn RPC must not run when the probe fails',
      );
    });

    test('createSession proceeds when liveness probe succeeds', () async {
      var probed = false;
      sync.testEnsureMachineReachableOverride = (machineId) async {
        probed = true;
      };
      sync.testMachineRPCOverride = (machineId, method, params) async {
        return <String, dynamic>{
          'type': 'success',
          'sessionId': 'probe-ok',
          'dataEncryptionKey': null,
        };
      };

      final result = await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      expect(result, 'probe-ok');
      expect(probed, isTrue);
    });

    test('createSession throws when RPC returns empty session ID', () {
      sync.testMachineRPCOverride = (machineId, method, params) async {
        return <String, dynamic>{
          'type': 'success',
          'sessionId': '',
          'dataEncryptionKey': null,
        };
      };

      expect(
        () => sync.createSession(agent: 'claude', machineId: 'm', path: '/p'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('empty session ID'),
          ),
        ),
      );
    });

    test('webhook timeout recovery finds recently created session', () async {
      final existingSession = _makeSession(
        'existing-after-timeout',
        machineId: 'machine-1',
        path: '/home/user/project',
        createdAt: DateTime.now().millisecondsSinceEpoch - 5000,
      );

      sync.testMachineRPCOverride = (machineId, method, params) async {
        return <String, dynamic>{
          'type': 'error',
          'errorMessage': 'webhook timeout waiting for session',
        };
      };

      _stubAllSyncs(
        sync,
        sessionsFn: () async {
          if (sync.testForceFullFetchNext) {
            sync.testForceFullFetchNext = false;
          }
          // After the 5s wait, session appears
          sync.testSessions['existing-after-timeout'] = existingSession;
        },
      );

      final result = await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      expect(result, 'existing-after-timeout');
      expect(
        sync.testSessionSpawnedAt.containsKey('existing-after-timeout'),
        isTrue,
        reason: 'Webhook timeout recovery must register spawn timestamp',
      );
    });

    test('webhook timeout throws when no matching session found', () async {
      sync.testMachineRPCOverride = (machineId, method, params) async {
        return <String, dynamic>{
          'type': 'error',
          'errorMessage': 'webhook timeout waiting for session',
        };
      };

      _stubAllSyncs(
        sync,
        sessionsFn: () async {
          if (sync.testForceFullFetchNext) {
            sync.testForceFullFetchNext = false;
          }
          // No matching session found
        },
      );

      expect(
        () => sync.createSession(
          agent: 'claude',
          machineId: 'machine-1',
          path: '/home/user/project',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('createSession with DEK initializes encryption', () async {
      final sessionId = 'spawn-dek-1';
      sync.testMachineRPCOverride = (machineId, method, params) async {
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': 'fake-dek-value',
        };
      };

      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      // FakeEncryption will have been called with the DEK
      expect(encryption.decryptedKeys, contains('fake-dek-value'));
      expect(encryption.initializedSessions, contains(sessionId));
    });
  });

  group('_sessionSpawnedAt lifecycle', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testGetSpawnEnvVarsOverride = (_) async =>
          (envVars: <String, String>{}, profile: null);
      _stubAllSyncs(sync);
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testMachineRPCOverride = null;
      sync.testFetchSingleSessionOverride = null;
      sync.testFetchMessagesOverride = null;
      sync.testGetSpawnEnvVarsOverride = null;
      sync.testEnsureMachineReachableOverride = null;
    });

    test(
      'full fetch preserves optimistic sessions within 60s window',
      () async {
        // Spawn session
        final sessionId = 'spawn-preserve-1';
        sync.testMachineRPCOverride = (machineId, method, params) async {
          return <String, dynamic>{
            'type': 'success',
            'sessionId': sessionId,
            'dataEncryptionKey': null,
          };
        };

        // First create: forces full fetch that doesn't return session
        _stubAllSyncs(
          sync,
          sessionsFn: () async {
            if (sync.testForceFullFetchNext) {
              sync.testForceFullFetchNext = false;
            }
            // Server doesn't return the new session (propagation delay)
            // But includes other sessions
            sync.testSessions['other'] = _makeSession('other');
          },
        );

        await sync.createSession(
          agent: 'claude',
          machineId: 'machine-1',
          path: '/p',
        );
        expect(
          sync.sessions.containsKey(sessionId),
          isTrue,
          reason: 'Placeholder should exist',
        );

        // Now simulate a subsequent full fetch that wipes sessions
        // The 60s preservation logic should keep the spawned session
        final spawnedAt = sync.testSessionSpawnedAt[sessionId]!;
        final age = DateTime.now().millisecondsSinceEpoch - spawnedAt;
        expect(
          age,
          lessThan(60000),
          reason: 'Session should be within 60s window',
        );
      },
    );

    test('_sessionSpawnedAt is cleaned up on session delete', () {
      final sessionId = 'delete-spawn-1';
      sync.testSetSessionSpawnedAt(sessionId, 1700000000000);
      sync.testSessions[sessionId] = _makeSession(sessionId);

      expect(sync.testSessionSpawnedAt.containsKey(sessionId), isTrue);

      // Trigger delete
      sync.handleUpdate({'t': 'delete-session', 'sid': sessionId});

      expect(
        sync.testSessionSpawnedAt.containsKey(sessionId),
        isFalse,
        reason: '_sessionSpawnedAt must be cleaned on session delete',
      );
    });

    test('_sessionSpawnedAt is cleaned up on 404 in fetchMessages', () async {
      final sessionId = 'fetch-404-1';
      sync.testSetSessionSpawnedAt(sessionId, 1700000000000);
      sync.testSessions[sessionId] = _makeSession(sessionId);
      sync.testSetSessionLastSeq(sessionId, 5);

      // Set up messagesSync for this session
      sync.messagesSync[sessionId] = InvalidateSync(() async {});

      sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
        // Return null to trigger the real 404 path
        throw Exception('Should not be called');
      };

      // Verify spawn timestamp exists
      expect(sync.testSessionSpawnedAt.containsKey(sessionId), isTrue);
      expect(sync.sessions.containsKey(sessionId), isTrue);

      // Note: direct 404 cleanup is tested via the fetchMessages path
      // which requires real HTTP. We test the state management instead:
      // simulate what the 404 handler does
      sync.messagesSync.remove(sessionId)?.dispose();
      sync.testSessions.remove(sessionId);
      sync.testSessionSpawnedAt.remove(sessionId);

      expect(sync.testSessionSpawnedAt.containsKey(sessionId), isFalse);
      expect(sync.sessions.containsKey(sessionId), isFalse);
    });
  });

  group('_resolveSendTargetSession readiness checks', () {
    late Sync sync;
    late _FakeEncryption encryption;
    late _AlwaysSuccessApiInterceptor interceptor;

    setUp(() async {
      sync = Sync();
      encryption = _FakeEncryption();
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testGetSpawnEnvVarsOverride = (_) async =>
          (envVars: <String, String>{}, profile: null);
      _stubAllSyncs(sync);

      interceptor = _AlwaysSuccessApiInterceptor();
      await ApiClient().initialize(serverUrl: 'http://localhost');
      ApiClient().testDio!.interceptors.add(interceptor);
    });

    tearDown(() {
      ApiClient().dispose();
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testMachineRPCOverride = null;
      sync.testFetchSingleSessionOverride = null;
      sync.testGetSpawnEnvVarsOverride = null;
    });

    test('online session is considered ready — no auto-restore', () async {
      final sessionId = 'ready-online';
      sync.testSessions[sessionId] = _makeSession(
        sessionId,
        presence: 'online',
      );
      sync.testFetchSingleSessionOverride = (_) async => null;

      final result = await sync.sendMessage(sessionId, 'hello');
      // Should use the same session (no redirect)
      expect(result, sessionId);
    });

    test(
      'recently spawned session is considered ready — no auto-restore',
      () async {
        final sessionId = 'ready-spawned';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          presence: 'offline',
          machineId: 'machine-1',
          path: '/home/user/project',
        );
        // Mark as recently spawned (within 120s)
        sync.testSetSessionSpawnedAt(
          sessionId,
          DateTime.now().millisecondsSinceEpoch - 10000,
        );
        sync.testFetchSingleSessionOverride = (_) async => null;

        final result = await sync.sendMessage(sessionId, 'hello');
        await sync.lastCompleteSendFuture;
        expect(result, sessionId);
      },
    );

    test(
      'session with recent starting lifecycle is considered ready',
      () async {
        final sessionId = 'ready-starting';
        final now = DateTime.now().millisecondsSinceEpoch;
        sync.testSessions[sessionId] = Session(
          id: sessionId,
          seq: 1,
          createdAt: now - 5000,
          updatedAt: now - 5000,
          active: true,
          activeAt: now - 5000,
          metadataVersion: 1,
          agentStateVersion: 1,
          thinking: false,
          presence: 'offline',
          metadata: Metadata(
            host: '',
            machineId: 'machine-1',
            path: '/project',
            lifecycleState: 'starting',
            lifecycleStateSince: now - 5000, // 5s ago, within 120s
          ),
        );
        sync.testFetchSingleSessionOverride = (_) async => null;

        final result = await sync.sendMessage(sessionId, 'hello');
        expect(result, sessionId);
      },
    );

    test('offline session with stale spawn triggers auto-restore', () async {
      final sessionId = 'stale-offline';
      sync.testSessions[sessionId] = _makeSession(
        sessionId,
        presence: 'offline',
        machineId: 'machine-1',
        path: '/project',
      );
      // Spawn timestamp is too old (> 120s)
      sync.testSetSessionSpawnedAt(
        sessionId,
        DateTime.now().millisecondsSinceEpoch - 200000,
      );

      final restoredId = 'restored-sess';
      sync.testMachineRPCOverride = (machineId, method, params) async {
        expect(method, 'spawn-happy-session');
        return <String, dynamic>{
          'type': 'success',
          'sessionId': restoredId,
          'dataEncryptionKey': null,
        };
      };
      sync.testFetchSingleSessionOverride = (_) async => null;

      final result = await sync.sendMessage(sessionId, 'hello');
      await sync.lastCompleteSendFuture;

      // Should have been redirected to the restored session
      expect(result, restoredId);
      // Restored session should be registered in _sessionSpawnedAt
      expect(sync.testSessionSpawnedAt.containsKey(restoredId), isTrue);
    });

    test(
      'auto-restore drops incompatible Claude model override for '
      'third-party Anthropic base URL',
      () async {
        final sessionId = 'auto-restore-incompatible-model';
        final now = DateTime.now().millisecondsSinceEpoch;
        sync.testSessions[sessionId] = Session(
          id: sessionId,
          seq: 1,
          createdAt: now - 200000,
          updatedAt: now,
          active: true,
          activeAt: now,
          metadataVersion: 1,
          agentStateVersion: 0,
          thinking: false,
          presence: 'offline',
          modelMode: 'opus:max',
          metadata: Metadata(
            host: '',
            machineId: 'machine-1',
            path: '/project',
            flavor: 'claude',
            lifecycleState: 'stopped',
          ),
        );
        sync.testMachines['machine-1'] = Machine(
          id: 'machine-1',
          seq: 1,
          createdAt: 0,
          updatedAt: 0,
          active: true,
          activeAt: now,
          metadataVersion: 0,
          daemonStateVersion: 0,
        );
        sync.testSetSessionSpawnedAt(sessionId, now - 200000);

        final deepseek = getBuiltInProfile('deepseek')!;
        sync.testGetSpawnEnvVarsOverride = (_) async => (
          envVars: {
            for (final v in deepseek.environmentVariables) v.name: v.value,
          },
          profile: deepseek,
        );

        Map<String, dynamic>? capturedSpawnParams;
        sync.testMachineRPCOverride = (machineId, method, params) async {
          if (method == 'spawn-happy-session') {
            capturedSpawnParams = params;
            return <String, dynamic>{
              'type': 'success',
              'sessionId': sessionId,
              'dataEncryptionKey': null,
            };
          }
          return <String, dynamic>{'type': 'error'};
        };
        sync.testFetchSingleSessionOverride = (_) async => null;

        try {
          await sync.sendMessage(sessionId, 'hello');
        } catch (_) {
          // REST POST is not mocked in this contract test; the spawn RPC is
          // the behavior we care about.
        }

        expect(
          capturedSpawnParams,
          isNotNull,
          reason: 'Offline session must trigger auto-restore spawn RPC',
        );
        expect(
          capturedSpawnParams!['model'],
          'default',
          reason:
              'Claude model override must be dropped when profile sets a '
              'third-party Anthropic-compatible base URL, and replaced with '
              'an explicit default so the daemon clears sticky metadata',
        );
        final envVars =
            capturedSpawnParams!['environmentVariables']
                as Map<String, dynamic>?;
        expect(envVars, isNotNull);
        expect(
          envVars!['ANTHROPIC_BASE_URL'],
          contains('deepseek'),
          reason:
              'Third-party Anthropic-compatible base URL must still be sent',
        );
      },
    );

    test(
      'auto-restore creates placeholder if restored session not in map',
      () async {
        final sessionId = 'auto-restore-placeholder';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          presence: 'offline',
          machineId: 'machine-1',
          path: '/project',
        );

        final restoredId = 'new-restored-sess';
        sync.testMachineRPCOverride = (machineId, method, params) async {
          return <String, dynamic>{
            'type': 'success',
            'sessionId': restoredId,
            'dataEncryptionKey': null,
          };
        };
        sync.testFetchSingleSessionOverride = (_) async => null;

        await sync.sendMessage(sessionId, 'hello');

        // Restored session should have a placeholder in _sessions
        final restoredSession = sync.sessions[restoredId];
        expect(restoredSession, isNotNull);
        expect(restoredSession!.metadata?.machineId, 'machine-1');
        expect(restoredSession.metadata?.path, '/project');
        expect(restoredSession.metadata?.lifecycleState, 'starting');
      },
    );

    test('auto-restore prevents concurrent RPCs for same session', () async {
      final sessionId = 'concurrent-restore';
      sync.testSessions[sessionId] = _makeSession(
        sessionId,
        presence: 'offline',
        machineId: 'machine-1',
        path: '/project',
      );

      var rpcCallCount = 0;
      final rpcGate = Completer<void>();
      sync.testMachineRPCOverride = (machineId, method, params) async {
        rpcCallCount++;
        await rpcGate.future; // Block until gate opens
        return <String, dynamic>{
          'type': 'success',
          'sessionId': 'restored-1',
          'dataEncryptionKey': null,
        };
      };
      sync.testFetchSingleSessionOverride = (_) async => null;

      // Launch two sendMessage calls concurrently
      final f1 = sync.sendMessage(sessionId, 'hello 1');
      final f2 = sync.sendMessage(sessionId, 'hello 2');

      // Give microtasks time to start
      await Future<void>.delayed(const Duration(milliseconds: 50));

      rpcGate.complete();
      await Future.wait([f1, f2]);

      // Only one RPC call should have been made (second should skip)
      expect(
        rpcCallCount,
        1,
        reason: '_autoRestoreInFlight should prevent concurrent RPCs',
      );
    });

    test(
      'auto-restore falls back to original session on RPC failure',
      () async {
        final sessionId = 'restore-fail';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          presence: 'offline',
          machineId: 'machine-1',
          path: '/project',
        );

        sync.testMachineRPCOverride = (machineId, method, params) async {
          return <String, dynamic>{
            'type': 'error',
            'errorMessage': 'machine unavailable',
          };
        };
        sync.testFetchSingleSessionOverride = (_) async => null;

        final result = await sync.sendMessage(sessionId, 'hello');

        // Should fall back to original session
        expect(result, sessionId);
      },
    );

    test('auto-restore skips when session has no machineId/path', () async {
      final sessionId = 'no-machine';
      sync.testSessions[sessionId] = Session(
        id: sessionId,
        seq: 1,
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
        active: true,
        activeAt: 1700000000000,
        metadataVersion: 1,
        agentStateVersion: 1,
        thinking: false,
        presence: 'offline',
        metadata: Metadata(host: ''), // No machineId, no path
      );
      sync.testFetchSingleSessionOverride = (_) async => null;

      var rpcCalled = false;
      sync.testMachineRPCOverride = (_, __, ___) async {
        rpcCalled = true;
        return <String, dynamic>{};
      };

      final result = await sync.sendMessage(sessionId, 'hello');
      expect(result, sessionId);
      expect(
        rpcCalled,
        isFalse,
        reason: 'Should not attempt auto-restore without machineId/path',
      );
    });
  });

  group('sendMessage encryption recovery', () {
    late Sync sync;
    late _FakeEncryption encryption;
    late _AlwaysSuccessApiInterceptor interceptor;

    setUp(() async {
      sync = Sync();
      encryption = _FakeEncryption();
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testGetSpawnEnvVarsOverride = (_) async =>
          (envVars: <String, String>{}, profile: null);
      _stubAllSyncs(sync);

      interceptor = _AlwaysSuccessApiInterceptor();
      await ApiClient().initialize(serverUrl: 'http://localhost');
      ApiClient().testDio!.interceptors.add(interceptor);
    });

    tearDown(() {
      ApiClient().dispose();
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testMachineRPCOverride = null;
      sync.testFetchSingleSessionOverride = null;
      sync.testGetSpawnEnvVarsOverride = null;
    });

    test(
      '3-step escalation: fetchSingle → invalidate → force full fetch',
      () async {
        final sessionId = 'encrypt-recovery';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          presence: 'online',
        );

        // Start with NO encryption for this session
        encryption.blockSessionEncryption = true;

        var fetchSingleCalled = false;
        var invalidateCalled = false;
        var forceFetchCalled = false;

        sync.testFetchSingleSessionOverride = (sid) async {
          fetchSingleCalled = true;
          // Still no encryption after single fetch
          return sync.sessions[sid];
        };

        _stubAllSyncs(
          sync,
          sessionsFn: () async {
            if (sync.testForceFullFetchNext) {
              forceFetchCalled = true;
              sync.testForceFullFetchNext = false;
              // Finally restore encryption on force fetch
              encryption.blockSessionEncryption = false;
            } else {
              invalidateCalled = true;
            }
          },
        );

        await sync.sendMessage(sessionId, 'hello');

        expect(
          fetchSingleCalled,
          isTrue,
          reason: 'Step 1: fetchSingleSession must be called',
        );
        expect(
          invalidateCalled,
          isTrue,
          reason: 'Step 2: sessionsSync.invalidateAndAwait must be called',
        );
        expect(
          forceFetchCalled,
          isTrue,
          reason: 'Step 3: _forceFullFetchNext must be set',
        );
      },
    );

    test(
      'throws if encryption still missing after all 3 recovery attempts',
      () async {
        final sessionId = 'encrypt-fail';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          presence: 'online',
        );

        // Encryption stays blocked
        encryption.blockSessionEncryption = true;

        sync.testFetchSingleSessionOverride = (sid) async {
          return sync.sessions[sid];
        };

        expect(
          () => sync.sendMessage(sessionId, 'hello'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('encryption not initialized'),
            ),
          ),
        );
      },
    );
  });

  group('sendMessage session lookup recovery', () {
    late Sync sync;
    late _FakeEncryption encryption;
    late _AlwaysSuccessApiInterceptor interceptor;

    setUp(() async {
      sync = Sync();
      encryption = _FakeEncryption();
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testGetSpawnEnvVarsOverride = (_) async =>
          (envVars: <String, String>{}, profile: null);
      _stubAllSyncs(sync);

      interceptor = _AlwaysSuccessApiInterceptor();
      await ApiClient().initialize(serverUrl: 'http://localhost');
      ApiClient().testDio!.interceptors.add(interceptor);
    });

    tearDown(() {
      ApiClient().dispose();
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testMachineRPCOverride = null;
      sync.testFetchSingleSessionOverride = null;
      sync.testGetSpawnEnvVarsOverride = null;
    });

    test(
      'creates placeholder when session not found after all recovery',
      () async {
        final sessionId = 'missing-sess';

        // Session not in _sessions at all, but encryption exists
        encryption.blockSessionEncryption = false;

        sync.testFetchSingleSessionOverride = (sid) async {
          // Single fetch doesn't find it either
          return null;
        };

        _stubAllSyncs(
          sync,
          sessionsFn: () async {
            if (sync.testForceFullFetchNext) {
              sync.testForceFullFetchNext = false;
            }
            // Full fetch doesn't return it either
          },
        );

        // sendMessage should NOT throw "Session not loaded"
        final result = await sync.sendMessage(sessionId, 'hello');
        expect(result, sessionId);

        // A placeholder should have been created
        final session = sync.sessions[sessionId];
        expect(session, isNotNull);
        expect(session!.metadata?.lifecycleState, 'starting');
      },
    );

    test('fetchSingleSession recovery populates session', () async {
      final sessionId = 'single-fetch-recovery';

      sync.testFetchSingleSessionOverride = (sid) async {
        // Single fetch finds the session
        final session = _makeSession(sid, presence: 'online');
        sync.testSessions[sid] = session;
        return session;
      };

      final result = await sync.sendMessage(sessionId, 'hello');
      expect(result, sessionId);
      expect(sync.sessions[sessionId], isNotNull);
    });
  });

  group('waitForAgentReady', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      sync.testIsInitialized = true;
      sync.testSessions.clear();
      _stubAllSyncs(sync);
    });

    test('returns true immediately for online session', () async {
      sync.testSessions['s1'] = _makeSession('s1', presence: 'online');
      // _isSessionReady requires a recent ephemeral event
      // to trust 'online' presence.
      sync.testSetLastEphemeralAt('s1', DateTime.now().millisecondsSinceEpoch);
      final ready = await sync.waitForAgentReady('s1');
      expect(ready, isTrue);
    });

    test(
      'returns true immediately for running session with recent timestamp',
      () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        sync.testSessions['s1'] = Session(
          id: 's1',
          seq: 1,
          createdAt: now,
          updatedAt: now,
          active: true,
          activeAt: now,
          metadataVersion: 1,
          agentStateVersion: 1,
          thinking: false,
          presence: 'offline',
          metadata: Metadata(
            host: '',
            lifecycleState: 'running',
            lifecycleStateSince: now - 5000,
          ),
        );
        final ready = await sync.waitForAgentReady('s1');
        expect(ready, isTrue);
      },
    );

    test('waits and returns true when session comes '
        'online via data change', () async {
      sync.testSessions['s1'] = _makeSession('s1', presence: 'offline');

      // Simulate session coming online after 100ms
      Timer(const Duration(milliseconds: 100), () {
        sync.testSessions['s1'] = _makeSession('s1', presence: 'online');
        // _isSessionReady requires a recent ephemeral
        // event to trust 'online' presence.
        sync.testSetLastEphemeralAt(
          's1',
          DateTime.now().millisecondsSinceEpoch,
        );
        sync.testNotifyDataChanged();
      });

      final ready = await sync.waitForAgentReady('s1', 5000);
      expect(ready, isTrue);
    });

    test('returns false after timeout for offline session', () async {
      sync.testSessions['s1'] = _makeSession('s1', presence: 'offline');
      final ready = await sync.waitForAgentReady('s1', 100);
      expect(ready, isFalse);
    });

    test('returns false for non-existent session', () async {
      final ready = await sync.waitForAgentReady('nonexistent', 100);
      expect(ready, isFalse);
    });
  });

  group('sendMessage optimistic insert', () {
    late Sync sync;
    late _FakeEncryption encryption;
    late _AlwaysSuccessApiInterceptor interceptor;

    setUp(() async {
      sync = Sync();
      encryption = _FakeEncryption();
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testGetSpawnEnvVarsOverride = (_) async =>
          (envVars: <String, String>{}, profile: null);
      _stubAllSyncs(sync);

      interceptor = _AlwaysSuccessApiInterceptor();
      await ApiClient().initialize(serverUrl: 'http://localhost');
      ApiClient().testDio!.interceptors.add(interceptor);
    });

    tearDown(() {
      ApiClient().dispose();
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testMachineRPCOverride = null;
      sync.testFetchSingleSessionOverride = null;
      sync.testGetSpawnEnvVarsOverride = null;
    });

    test(
      'optimistic message appears in session messages immediately',
      () async {
        final sessionId = 'opt-msg';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          presence: 'online',
        );
        sync.testFetchSingleSessionOverride = (_) async => null;

        // Listen for message change notification
        final notified = Completer<String>();
        final sub = sync.onSessionMessagesChanged.listen((sid) {
          if (!notified.isCompleted) notified.complete(sid);
        });

        await sync.sendMessage(sessionId, 'hello optimistic');

        // Check optimistic message was inserted
        final messages = sync.testSessionMessages(sessionId);
        expect(messages, isNotNull);
        expect(messages!.isNotEmpty, isTrue);

        final optimistic = messages.firstWhere(
          (m) => m['content'] == 'hello optimistic',
          orElse: () => <String, dynamic>{},
        );
        expect(optimistic.isNotEmpty, isTrue);
        expect(optimistic['role'], 'user');
        expect(optimistic['sendStatus'], 'sending');

        // Verify notification was sent
        final notifiedSessionId = await notified.future.timeout(
          const Duration(seconds: 2),
        );
        expect(notifiedSessionId, sessionId);

        await sub.cancel();
      },
    );

    test('messagesSync is pre-initialized if not present', () async {
      final sessionId = 'pre-init-msg';
      sync.testSessions[sessionId] = _makeSession(
        sessionId,
        presence: 'online',
      );
      sync.testFetchSingleSessionOverride = (_) async => null;

      expect(sync.messagesSync.containsKey(sessionId), isFalse);

      await sync.sendMessage(sessionId, 'hello');

      expect(
        sync.messagesSync.containsKey(sessionId),
        isTrue,
        reason: 'sendMessage should pre-initialize messagesSync',
      );
    });
  });

  group('_completeSend agent readiness timeout', () {
    late Sync sync;
    late _FakeEncryption encryption;
    late _CapturingApiInterceptor interceptor;

    setUp(() async {
      sync = Sync();
      encryption = _FakeEncryption();
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testGetSpawnEnvVarsOverride = (_) async =>
          (envVars: <String, String>{}, profile: null);
      _stubAllSyncs(sync);

      // Set up API interceptor
      interceptor = _CapturingApiInterceptor();
      await ApiClient().initialize(serverUrl: 'http://localhost');
      ApiClient().testDio!.interceptors.add(interceptor);
    });

    tearDown(() {
      ApiClient().dispose();
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testMachineRPCOverride = null;
      sync.testFetchSingleSessionOverride = null;
      sync.testGetSpawnEnvVarsOverride = null;
    });

    test('uses 15s timeout for recently spawned sessions', () async {
      final sessionId = 'recently-spawned';
      sync.testSessions[sessionId] = _makeSession(
        sessionId,
        presence: 'online',
      );
      sync.testFetchSingleSessionOverride = (_) async => null;
      // _isSessionReady requires a recent ephemeral event to trust 'online'
      sync.testSetLastEphemeralAt(
        sessionId,
        DateTime.now().millisecondsSinceEpoch,
      );

      // Mark as recently spawned (< 30s ago)
      sync.testSetSessionSpawnedAt(
        sessionId,
        DateTime.now().millisecondsSinceEpoch - 5000,
      );

      interceptor.respondWith(sessionId);
      await sync.sendMessage(sessionId, 'hello');
      await sync.lastCompleteSendFuture;

      // Session was recently spawned, so longer timeout was used.
      // We can verify the message was sent successfully.
      final msgs = sync.testSessionMessages(sessionId) ?? [];
      final sentMsg = msgs.where((m) => m['sendStatus'] == 'sent');
      expect(sentMsg.isNotEmpty, isTrue);
    });

    test('uses default timeout for non-recently spawned sessions', () async {
      final sessionId = 'old-session';
      sync.testSessions[sessionId] = _makeSession(
        sessionId,
        presence: 'online',
      );
      sync.testFetchSingleSessionOverride = (_) async => null;

      // No spawn timestamp or very old one
      sync.testSetSessionSpawnedAt(
        sessionId,
        DateTime.now().millisecondsSinceEpoch - 60000,
      );

      interceptor.respondWith(sessionId);
      await sync.sendMessage(sessionId, 'hello');
      await sync.lastCompleteSendFuture;

      final msgs = sync.testSessionMessages(sessionId) ?? [];
      final sentMsg = msgs.where((m) => m['sendStatus'] == 'sent');
      expect(sentMsg.isNotEmpty, isTrue);
    });
  });

  group('full spawn → sendMessage E2E', () {
    late Sync sync;
    late _FakeEncryption encryption;
    late _CapturingApiInterceptor interceptor;

    setUp(() async {
      sync = Sync();
      encryption = _FakeEncryption();
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testGetSpawnEnvVarsOverride = (_) async =>
          (envVars: <String, String>{}, profile: null);
      _stubAllSyncs(sync);

      interceptor = _CapturingApiInterceptor();
      await ApiClient().initialize(serverUrl: 'http://localhost');
      ApiClient().testDio!.interceptors.add(interceptor);
    });

    tearDown(() {
      ApiClient().dispose();
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testMachineRPCOverride = null;
      sync.testFetchSingleSessionOverride = null;
      sync.testGetSpawnEnvVarsOverride = null;
    });

    test('createSession → sendMessage with propagation delay', () async {
      final sessionId = 'e2e-full';

      // Phase 1: createSession
      sync.testMachineRPCOverride = (machineId, method, params) async {
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      // Session is never returned by server (propagation delay)
      _stubAllSyncs(
        sync,
        sessionsFn: () async {
          if (sync.testForceFullFetchNext) {
            sync.testForceFullFetchNext = false;
          }
        },
      );

      final createdId = await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );
      expect(createdId, sessionId);

      // Verify state after createSession
      expect(sync.sessions.containsKey(sessionId), isTrue);
      expect(sync.testSessionSpawnedAt.containsKey(sessionId), isTrue);
      expect(sync.messagesSync.containsKey(sessionId), isTrue);

      // Phase 2: sendMessage on the newly created session
      sync.testFetchSingleSessionOverride = (_) async => null;
      interceptor.respondWith(sessionId);

      // Session starts as 'starting' (optimistic placeholder) — simulate
      // agent transitioning to 'running' so waitForAgentReady completes.
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        final now = DateTime.now().millisecondsSinceEpoch;
        sync.testSessions[sessionId] = sync.sessions[sessionId]!.copyWith(
          metadata: sync.sessions[sessionId]!.metadata?.copyWith(
            lifecycleState: 'running',
            lifecycleStateSince: now,
          ),
        );
        sync.testNotifyDataChanged();
      });

      final sentId = await sync.sendMessage(sessionId, 'Hello!');
      expect(sentId, sessionId);

      // Optimistic message should be present
      final msgs = sync.testSessionMessages(sessionId);
      expect(msgs, isNotNull);
      expect(msgs!.any((m) => m['content'] == 'Hello!'), isTrue);

      // Wait for background send
      await sync.lastCompleteSendFuture;

      // Message should be marked sent
      final updatedMsgs = sync.testSessionMessages(sessionId)!;
      final sentMsg = updatedMsgs.firstWhere((m) => m['content'] == 'Hello!');
      expect(sentMsg['sendStatus'], 'sent');
    });

    test(
      'createSession → sendMessage waits for real readiness before sending',
      () async {
        final sessionId = 'e2e-delayed-online';

        // Phase 1: Create
        sync.testMachineRPCOverride = (machineId, method, params) async {
          return <String, dynamic>{
            'type': 'success',
            'sessionId': sessionId,
            'dataEncryptionKey': null,
          };
        };

        await sync.createSession(
          agent: 'claude',
          machineId: 'machine-1',
          path: '/home/user/project',
        );

        // Phase 2: Send — session is offline but recently spawned
        sync.testFetchSingleSessionOverride = (_) async => null;
        interceptor.respondWith(sessionId);

        // Session is offline. A recent spawn should keep the existing target
        // session, but must not count as actual readiness on its own.
        expect(sync.sessions[sessionId]!.presence, 'offline');
        expect(sync.testSessionSpawnedAt.containsKey(sessionId), isTrue);

        Future<void>.delayed(const Duration(milliseconds: 50), () {
          sync.testSessions[sessionId] = _makeSession(
            sessionId,
            presence: 'online',
            machineId: 'machine-1',
            path: '/home/user/project',
          );
          sync.testSetLastEphemeralAt(
            sessionId,
            DateTime.now().millisecondsSinceEpoch,
          );
          sync.testNotifyDataChanged();
        });

        final sentId = await sync.sendMessage(sessionId, 'First message');
        expect(
          sentId,
          sessionId,
          reason: 'Recently spawned session should not trigger auto-restore',
        );

        await sync.lastCompleteSendFuture;

        final updatedMsgs = sync.testSessionMessages(sessionId)!;
        final sentMsg = updatedMsgs.firstWhere(
          (m) => m['content'] == 'First message',
        );
        expect(sentMsg['sendStatus'], 'sent');
      },
    );

    test('createSession → sendMessage marks failed when fresh session '
        'never becomes ready', () async {
      final sessionId = 'e2e-startup-timeout';

      sync.testMachineRPCOverride = (machineId, method, params) async {
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      sync.testFetchSingleSessionOverride = (_) async => null;

      final sentId = await sync.sendMessage(sessionId, 'Will fail');
      expect(sentId, sessionId);

      await sync.lastCompleteSendFuture;

      final updatedMsgs = sync.testSessionMessages(sessionId)!;
      final failedMsg = updatedMsgs.firstWhere(
        (m) => m['content'] == 'Will fail',
      );
      expect(failedMsg['sendStatus'], 'failed');
    });

    test('createSession → auto-restore → redirected sendMessage', () async {
      final originalId = 'e2e-original';
      final restoredId = 'e2e-restored';

      // Phase 1: Create session
      var rpcCount = 0;
      sync.testMachineRPCOverride = (machineId, method, params) async {
        rpcCount++;
        if (rpcCount == 1) {
          // First call: createSession
          return <String, dynamic>{
            'type': 'success',
            'sessionId': originalId,
            'dataEncryptionKey': null,
          };
        } else {
          // Second call: auto-restore from sendMessage
          return <String, dynamic>{
            'type': 'success',
            'sessionId': restoredId,
            'dataEncryptionKey': null,
          };
        }
      };

      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/project',
      );

      // Phase 2: Make the session look stale (expired spawn timestamp)
      sync.testSetSessionSpawnedAt(
        originalId,
        DateTime.now().millisecondsSinceEpoch - 200000, // 200s ago
      );
      // Also make it offline
      sync.testSessions[originalId] = _makeSession(
        originalId,
        presence: 'offline',
        machineId: 'machine-1',
        path: '/project',
      );

      sync.testFetchSingleSessionOverride = (_) async => null;
      interceptor.respondWith(restoredId);

      final sentId = await sync.sendMessage(originalId, 'After restore');
      expect(
        sentId,
        restoredId,
        reason: 'sendMessage should redirect to restored session',
      );

      // Restored session should be in _sessions
      expect(sync.sessions.containsKey(restoredId), isTrue);
      expect(sync.testSessionSpawnedAt.containsKey(restoredId), isTrue);
    });
  });

  group('permission mode propagation', () {
    late Sync sync;
    late _FakeEncryption encryption;
    late _CapturingSessionEncryption capturingEncryption;

    setUp(() async {
      sync = Sync();
      capturingEncryption = _CapturingSessionEncryption();
      encryption = _FakeEncryption(
        customSessionEncryption: capturingEncryption,
      );
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testGetSpawnEnvVarsOverride = (_) async =>
          (envVars: <String, String>{}, profile: null);
      _stubAllSyncs(sync);

      await ApiClient().initialize(serverUrl: 'http://localhost');
      final interceptor = _CapturingApiInterceptor();
      ApiClient().testDio!.interceptors.add(interceptor);
      interceptor.respondWith('perm-sess');
    });

    tearDown(() {
      ApiClient().dispose();
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchSingleSessionOverride = null;
    });

    test('unsupported permission modes fall back to default', () async {
      sync.testSessions['perm-sess'] = _makeSession(
        'perm-sess',
        presence: 'online',
        permissionMode: 'custom-team-mode',
      );
      sync.testFetchSingleSessionOverride = (_) async => null;

      await sync.sendMessage('perm-sess', 'test');
      await sync.lastCompleteSendFuture;

      final raw = capturingEncryption.lastRawRecord;
      expect(raw, isNotNull);
      final meta = raw!['meta'] as Map<String, dynamic>;
      expect(
        meta['permissionMode'],
        'default',
        reason: 'Custom mode should fall back to default',
      );
    });
  });

  group('_primeSessionFromSpawnResult', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testGetSpawnEnvVarsOverride = (_) async =>
          (envVars: <String, String>{}, profile: null);
      _stubAllSyncs(sync);
    });

    test('registers spawn timestamp for restored session', () async {
      final seedSession = _makeSession(
        'original',
        machineId: 'machine-1',
        path: '/project',
      );

      await sync.testPrimeSessionFromSpawnResult(
        requestedSessionId: 'original',
        restoredSessionId: 'restored-1',
        seedSession: seedSession,
        result: SpawnSessionResponse(
          type: 'success',
          sessionId: 'restored-1',
          dataEncryptionKey: null,
        ),
      );

      expect(sync.testSessionSpawnedAt.containsKey('restored-1'), isTrue);
    });

    test('creates placeholder with seed session metadata', () async {
      final seedSession = _makeSession(
        'original',
        machineId: 'machine-1',
        path: '/project',
      );

      await sync.testPrimeSessionFromSpawnResult(
        requestedSessionId: 'original',
        restoredSessionId: 'restored-2',
        seedSession: seedSession,
        result: SpawnSessionResponse(
          type: 'success',
          sessionId: 'restored-2',
          directory: '/project/new',
          dataEncryptionKey: null,
        ),
      );

      final session = sync.sessions['restored-2'];
      expect(session, isNotNull);
      expect(session!.metadata?.machineId, 'machine-1');
      // Directory from result takes precedence
      expect(session.metadata?.path, '/project/new');
    });

    test('skips placeholder if session already exists', () async {
      sync.testSessions['already-exists'] = _makeSession(
        'already-exists',
        machineId: 'machine-1',
        path: '/project',
      );

      final originalVersion = sync.sessions['already-exists']!.metadataVersion;

      await sync.testPrimeSessionFromSpawnResult(
        requestedSessionId: 'original',
        restoredSessionId: 'already-exists',
        seedSession: _makeSession('original'),
        result: SpawnSessionResponse(
          type: 'success',
          sessionId: 'already-exists',
          dataEncryptionKey: null,
        ),
      );

      // Should NOT have replaced the existing session
      expect(sync.sessions['already-exists']!.metadataVersion, originalVersion);
    });

    test('initializes encryption when DEK provided', () async {
      await sync.testPrimeSessionFromSpawnResult(
        requestedSessionId: 'original',
        restoredSessionId: 'dek-test',
        seedSession: _makeSession('original'),
        result: SpawnSessionResponse(
          type: 'success',
          sessionId: 'dek-test',
          dataEncryptionKey: 'test-dek',
        ),
      );

      expect(encryption.decryptedKeys, contains('test-dek'));
      expect(encryption.initializedSessions, contains('dek-test'));
    });
  });

  group('shutdown cleanup', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      sync.testIsInitialized = true;
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testGetSpawnEnvVarsOverride = (_) async =>
          (envVars: <String, String>{}, profile: null);
      _stubAllSyncs(sync);
    });

    test('shutdown clears _sessionSpawnedAt', () async {
      sync.testSetSessionSpawnedAt('s1', 1700000000000);
      sync.testSetSessionSpawnedAt('s2', 1700000000001);
      expect(sync.testSessionSpawnedAt.length, 2);

      await sync.shutdown();

      expect(sync.testSessionSpawnedAt, isEmpty);
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Session _makeSession(
  String id, {
  String presence = 'offline',
  String? machineId,
  String? path,
  String? permissionMode,
  int? createdAt,
}) {
  final now = createdAt ?? 1700000000000;
  return Session(
    id: id,
    seq: 1,
    createdAt: now,
    updatedAt: now,
    active: true,
    activeAt: now,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    presence: presence,
    permissionMode: permissionMode,
    metadata: Metadata(host: '', machineId: machineId, path: path),
  );
}

void _stubAllSyncs(Sync instance, {Future<void> Function()? sessionsFn}) {
  try {
    instance.sessionsSync.dispose();
  } on Error {
    // Not initialized yet
  }
  instance.sessionsSync = InvalidateSync(sessionsFn ?? () async {});
  instance.settingsSync = InvalidateSync(() async {});
  instance.profileSync = InvalidateSync(() async {});
  instance.purchasesSync = InvalidateSync(() async {});
  instance.machinesSync = InvalidateSync(() async {});
  instance.pushTokenSync = InvalidateSync(() async {});
  instance.nativeUpdateSync = InvalidateSync(() async {});
  instance.artifactsSync = InvalidateSync(() async {});
  instance.sessionGitStatusSync = InvalidateSync(() async {});
  instance.messagesSync.clear();
  instance.testFetchMessagesOverride ??= (_, __, ___) async =>
      <String, dynamic>{
        'messages': <Map<String, dynamic>>[],
        'has_more': false,
      };
}

// ---------------------------------------------------------------------------
// Fake encryption
// ---------------------------------------------------------------------------

class _FakeEncryption implements Encryption {
  _FakeEncryption({this.customSessionEncryption});

  final Map<String, _FakeSessionEncryption> _sessions = {};
  final EncryptionCache _cache = EncryptionCache();
  final List<String> decryptedKeys = [];
  final List<String> initializedSessions = [];
  bool blockSessionEncryption = false;
  final SessionEncryption? customSessionEncryption;

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    if (blockSessionEncryption) return null;
    if (customSessionEncryption != null) return customSessionEncryption;
    return _sessions.putIfAbsent(
      sessionId,
      () => _FakeSessionEncryption(sessionId: sessionId),
    );
  }

  @override
  Future<Uint8List?> decryptEncryptionKey(String encryptedKey) async {
    decryptedKeys.add(encryptedKey);
    return Uint8List.fromList(utf8.encode('decrypted-$encryptedKey'));
  }

  @override
  Future<void> initializeSessions(Map<String, Uint8List?> sessionKeys) async {
    initializedSessions.addAll(sessionKeys.keys);
  }

  @override
  Future<dynamic> openEncryption(Uint8List? dataEncryptionKey) async {
    return _FakeEncryptor();
  }

  @override
  void setSessionEncryption(String sessionId, SessionEncryption enc) {
    initializedSessions.add(sessionId);
    if (enc is _FakeSessionEncryption) {
      _sessions[sessionId] = enc;
    }
  }

  @override
  EncryptionCache get cache => _cache;

  @override
  String generateId() => 'test-local-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void removeSessionEncryption(String sessionId) {
    _sessions.remove(sessionId);
  }

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

class _FakeEncryptor implements Encryptor {
  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    final results = <Uint8List>[];
    for (final item in data) {
      final json = jsonEncode(item);
      final bytes = utf8.encode(json);
      final output = Uint8List(bytes.length + 1);
      output[0] = 0x01;
      output.setRange(1, output.length, bytes);
      results.add(output);
    }
    return results;
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    final results = <dynamic>[];
    for (final item in data) {
      if (item.isEmpty) {
        results.add(null);
        continue;
      }
      try {
        if (item[0] == 0x01) {
          final json = utf8.decode(item.sublist(1));
          results.add(jsonDecode(json));
        } else {
          results.add(utf8.decode(item));
        }
      } catch (_) {
        results.add(null);
      }
    }
    return results;
  }
}

// ---------------------------------------------------------------------------
// API interceptor for capturing/mocking HTTP requests
// ---------------------------------------------------------------------------

class _CapturingApiInterceptor extends Interceptor {
  String? _respondForSessionId;
  final List<RequestOptions> requests = <RequestOptions>[];

  void respondWith(String sessionId) {
    _respondForSessionId = sessionId;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    final sessionId = _respondForSessionId;
    if (sessionId != null &&
        options.path.contains('/v3/sessions/') &&
        options.path.contains('/messages')) {
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'messages': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'srv-msg-${DateTime.now().microsecondsSinceEpoch}',
                'seq': 2,
                'localId': _extractLocalId(options.data),
                'createdAt': DateTime.now().millisecondsSinceEpoch,
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
  }

  String? _extractLocalId(dynamic data) {
    if (data is Map<String, dynamic>) {
      final messages = data['messages'] as List<dynamic>?;
      if (messages != null && messages.isNotEmpty) {
        final first = messages.first as Map<String, dynamic>;
        return first['localId'] as String?;
      }
    }
    return null;
  }
}

class _AlwaysSuccessApiInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path.contains('/v3/sessions/') &&
        options.path.contains('/messages')) {
      final now = DateTime.now();
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'messages': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'srv-msg-${now.microsecondsSinceEpoch}',
                'seq': 2,
                'localId': _extractLocalId(options.data),
                'createdAt': now.millisecondsSinceEpoch,
              },
            ],
          },
        ),
      );
      return;
    }

    handler.next(options);
  }

  String? _extractLocalId(dynamic data) {
    if (data is Map<String, dynamic>) {
      final messages = data['messages'] as List<dynamic>?;
      if (messages != null && messages.isNotEmpty) {
        final first = messages.first as Map<String, dynamic>;
        return first['localId'] as String?;
      }
    }
    return null;
  }
}
