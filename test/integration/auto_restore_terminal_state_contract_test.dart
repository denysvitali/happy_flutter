// Contract test for the auto-restore "terminal state" race.
//
// Pins the HAPPY_FLUTTER-3EP/3EN fix: when sendMessage triggers
// auto-restore and the daemon replies with "is in terminal state;
// refusing stale spawn" (a race between the killSession ACK and
// the server's `lifecycleState=exited` write), the client must:
//
//   1. NOT throw — throwing strands the message and the user has
//      no way to recover except a force-close.
//   2. Strip the terminal flag locally so the very next send
//      doesn't re-hit the same race.
//   3. Return the fallback session so the chat screen stays in a
//      consistent state.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';

void main() {
  group('auto-restore terminal-state race', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() async {
      sync = Sync();
      encryption = _FakeEncryption();

      for (final id in sync.sessionMessages.keys.toList()) {
        sync.testSetSessionMessages(id, []);
      }
      for (final id in sync.testSessions.keys.toList()) {
        sync.testSetSessionLastSeq(id, 0);
      }
      sync.sessionsSync = InvalidateSync(() async {});
      sync.settingsSync = InvalidateSync(() async {});
      sync.profileSync = InvalidateSync(() async {});
      sync.purchasesSync = InvalidateSync(() async {});
      sync.machinesSync = InvalidateSync(() async {});
      sync.pushTokenSync = InvalidateSync(() async {});
      sync.nativeUpdateSync = InvalidateSync(() async {});
      sync.artifactsSync = InvalidateSync(() async {});
      sync.sessionGitStatusSync = InvalidateSync(() async {});
      sync.messagesSync.clear();

      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};

      sync.encryption = encryption;
      sync.testIsInitialized = true;

      // Always-success interceptor for the message POST; the spawn RPC
      // stub is wired in each test.
      await ApiClient().initialize(serverUrl: 'http://localhost');
      ApiClient().testDio!.interceptors.add(_PostSuccessInterceptor());
    });

    tearDown(() async {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testMachineRPCOverride = null;
      sync.testFetchSingleSessionOverride = null;
      ApiClient().dispose();
    });

    test(
      'auto-restore hitting "is in terminal state" does NOT throw '
      'and clears the local terminal flag',
      () async {
        final sessionId = 'sess-terminal-race';
        final now = DateTime.now().millisecondsSinceEpoch;

        // Session is in the "exited" state — what the server sets after
        // a successful killSession. looksReady is false (so the
        // function falls through to auto-restore).
        sync.testSessions[sessionId] = Session(
          id: sessionId,
          seq: 1,
          createdAt: now,
          updatedAt: now,
          active: false,
          activeAt: now,
          metadata: Metadata(
            host: '',
            machineId: 'machine-1',
            path: '/repo',
            flavor: 'claude',
            lifecycleState: 'exited',
            lifecycleStateSince: now,
          ),
          metadataVersion: 1,
          agentStateVersion: 1,
          thinking: false,
          presence: 'offline',
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
          metadata: const MachineMetadata(homeDir: '/home/user'),
        );

        // Daemon replies with the "terminal state" error the server
        // returns when the killSession ACK races the lifecycleState
        // write.
        sync.testMachineRPCOverride = (
          machineId,
          method,
          params,
        ) async {
          if (method == 'spawn-happy-session') {
            return <String, dynamic>{
              'type': 'error',
              'errorMessage':
                  'session $sessionId is in terminal state; refusing stale spawn',
            };
          }
          return <String, dynamic>{'ok': true};
        };

        // The user sends a message. With the fix this MUST NOT throw.
        // Without the fix (HAPPY_FLUTTER-3EP/3EN) it throws
        // StateError("Could not restore stopped session ...") and
        // the message is lost.
        final result = await sync.sendMessage(sessionId, 'hello');

        // The send should succeed by returning the requested sessionId
        // (the fallback path), so the chat screen can keep going.
        expect(result, sessionId);

        // The local lifecycle flag should be reset to "starting" so
        // the next send doesn't re-hit the same race.
        final updated = sync.testSessions[sessionId];
        expect(
          updated?.metadata?.lifecycleState,
          'starting',
          reason:
              'Local terminal flag must be stripped after the server '
              'refuses a stale spawn so the next send can succeed.',
        );
        expect(
          updated?.metadata?.lifecycleStateError,
          isNull,
          reason: 'Stale terminal error must be cleared locally.',
        );
      },
    );

    test(
      'auto-restore hitting "refusing stale spawn" (server variant wording) '
      'also recovers',
      () async {
        final sessionId = 'sess-refusing-stale';
        final now = DateTime.now().millisecondsSinceEpoch;

        sync.testSessions[sessionId] = Session(
          id: sessionId,
          seq: 1,
          createdAt: now,
          updatedAt: now,
          active: false,
          activeAt: now,
          metadata: Metadata(
            host: '',
            machineId: 'machine-1',
            path: '/repo',
            flavor: 'claude',
            lifecycleState: 'exited',
            lifecycleStateSince: now,
          ),
          metadataVersion: 1,
          agentStateVersion: 1,
          thinking: false,
          presence: 'offline',
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
          metadata: const MachineMetadata(homeDir: '/home/user'),
        );

        // Same race, different server-side error wording.
        sync.testMachineRPCOverride = (
          machineId,
          method,
          params,
        ) async {
          if (method == 'spawn-happy-session') {
            return <String, dynamic>{
              'type': 'error',
              'errorMessage':
                  'refusing stale spawn for terminal session $sessionId',
            };
          }
          return <String, dynamic>{'ok': true};
        };

        // Must not throw.
        final result = await sync.sendMessage(sessionId, 'hello');
        expect(result, sessionId);
      },
    );
  });
}

class _FakeEncryption implements Encryption {
  final Map<String, _FakeSessionEncryption> _sessions = {};

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return _sessions.putIfAbsent(
      sessionId,
      () => _FakeSessionEncryption(sessionId: sessionId),
    );
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

class _PostSuccessInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Short-circuit the message POST so the test focuses on the
    // auto-restore path; the success path is well-covered elsewhere.
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
}
