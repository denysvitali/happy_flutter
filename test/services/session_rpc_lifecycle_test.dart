import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/services/loop_storage.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

import '../helpers/test_helpers.dart';

void main() {
  late Sync sync;
  late Encryption originalEncryption;

  setUp(() {
    sync = createTestSync();
    originalEncryption = sync.encryption;
    sync.testSessionRPCOverride = null;
    sync.testForceFullFetchNext = false;
    InvalidateSync.isBackgrounded = false;
    sync.testSessions.clear();
    sync.testMachines.clear();
    socketIoClient.disconnect();
  });

  tearDown(() {
    sync.testSessionRPCOverride = null;
    sync.testResetRpcCapabilitiesPolicy();
    sync.encryption = originalEncryption;
    socketIoClient.disconnect();
    socketIoClient.testSetCredentials();
    sync.sessionsSync.dispose();
    LoopStorage.instance.setStorageForTesting(MMKVStorage());
  });

  Matcher staleRpc() => throwsA(
    isA<StateError>().having(
      (error) => error.message,
      'message',
      'Session RPC runtime changed',
    ),
  );

  test('override results are fenced across runtime replacement', () async {
    final response = Completer<dynamic>();
    sync.testSessionRPCOverride = (_, _, _) => response.future;
    final result = expectLater(
      sync.sessionRPC('s1', 'loop-list', {}),
      staleRpc(),
    );

    sync.testAdvanceRuntimeGeneration();
    response.complete({'ok': true, 'loops': <dynamic>[]});
    await result;
  });

  test('readiness cannot force a fetch in the replacement runtime', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    var fetches = 0;
    sync.encryption = _SessionEncryptionStore(null);
    sync.sessionsSync.dispose();
    sync.sessionsSync = InvalidateSync(() async {
      fetches++;
      started.complete();
      await release.future;
    });
    final result = expectLater(
      sync.sessionRPC('s1', 'loop-list', {}),
      staleRpc(),
    );
    await started.future;

    sync.testAdvanceRuntimeGeneration();
    release.complete();
    await result;
    expect(fetches, 1);
    expect(sync.testForceFullFetchNext, isFalse);
  });

  test('runtime replacement during encryption prevents dispatch', () async {
    final encryption = _DeferredSessionEncryption(deferEncryption: true);
    sync.encryption = _SessionEncryptionStore(encryption);
    final result = expectLater(
      sync.sessionRPC('s1', 'loop-create', {}),
      staleRpc(),
    );
    await encryption.started.future;

    sync.testAdvanceRuntimeGeneration();
    encryption.release.complete('encrypted');
    await result;
    expect(encryption.decryptCalls, 0);
  });

  for (final stage in ['ack', 'decrypt', 'loop-decrypt']) {
    test('production RPC rejects a stale $stage completion', () async {
      final previousOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = previousOverrides);
      final storage = _MemoryStorage();
      LoopStorage.instance.setStorageForTesting(storage);
      if (stage == 'loop-decrypt') {
        sync.testClearAllLoops();
        sync.testRpcCapabilitiesOverride = (_, _, _) async => {
          'scope': 'session',
          'protocolVersion': 2,
          'methods': ['loop-list'],
        };
      }
      final server = await _RpcSocketServer.start();
      addTearDown(server.close);
      socketIoClient.connect(serverUrl: server.url, token: 'test');
      expect(
        await socketIoClient.waitForConnection(
          timeout: const Duration(seconds: 2),
        ),
        isTrue,
      );
      final encryption = _DeferredSessionEncryption();
      sync.encryption = _SessionEncryptionStore(encryption);
      final result = expectLater(
        stage == 'loop-decrypt'
            ? sync.listLoops(sessionId: 's1')
            : sync.sessionRPC('s1', 'loop-list', {}),
        staleRpc(),
      );
      await server.requested.future;
      if (stage != 'ack') {
        server.reply();
        await encryption.started.future;
      }

      sync.testAdvanceRuntimeGeneration();
      sync.testClearAllLoops();
      LoopStorage.instance.clear('s1');
      final counter = sync.domainChangeCounter(SyncDomain.loops);
      if (stage == 'ack') {
        server.reply();
      } else {
        encryption.release.complete({
          'ok': true,
          'loops': [
            {
              'id': 'old-loop',
              'sessionId': 's1',
              'expression': '*/5 * * * *',
              'prompt': 'old account prompt',
              'recurring': true,
              'createdAt': 1700000000000,
              'expiresAt': 1700604800000,
            },
          ],
        });
      }
      await result;
      expect(encryption.decryptCalls, stage == 'ack' ? 0 : 1);
      expect(sync.loopsBySession, isEmpty);
      expect(LoopStorage.instance.load('s1'), isEmpty);
      expect(storage.writes, 0);
      expect(sync.domainChangeCounter(SyncDomain.loops), counter);
    });
  }
}

class _DeferredSessionEncryption implements SessionEncryption {
  _DeferredSessionEncryption({this.deferEncryption = false});

  final bool deferEncryption;
  final started = Completer<void>();
  final release = Completer<dynamic>();
  int decryptCalls = 0;

  @override
  Future<String> encryptRaw(dynamic data) async {
    if (!deferEncryption) return 'encrypted';
    started.complete();
    return await release.future as String;
  }

  @override
  Future<dynamic> decryptRaw(String data) {
    decryptCalls++;
    started.complete();
    return release.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SessionEncryptionStore implements Encryption {
  _SessionEncryptionStore(this.session);
  final SessionEncryption? session;

  @override
  SessionEncryption? getSessionEncryption(String sessionId) => session;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryStorage extends MMKVStorage {
  _MemoryStorage() : super.testConstructor();

  final data = <String, String>{};
  int writes = 0;

  @override
  String? getString(String key) => data[key];

  @override
  void setString(String key, String value) {
    writes++;
    data[key] = value;
  }

  @override
  void removeKey(String key) => data.remove(key);
}

// A minimal Engine.IO / Socket.IO peer exercises the actual ACK/decrypt path.
class _RpcSocketServer {
  _RpcSocketServer(this.server);

  final HttpServer server;
  final requested = Completer<void>();
  WebSocket? socket;
  String? ackId;

  String get url => 'http://127.0.0.1:${server.port}';

  static Future<_RpcSocketServer> start() async {
    final peer = _RpcSocketServer(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    peer.server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      peer.socket = socket;
      socket.add(
        '0${jsonEncode({'sid': 'engine-test', 'upgrades': <String>[], 'pingInterval': 25000, 'pingTimeout': 20000, 'maxPayload': 1000000})}',
      );
      socket.listen((dynamic frame) {
        final text = frame as String;
        if (text.startsWith('40')) {
          socket.add('40{"sid":"socket-test"}');
        } else if (text.startsWith('42')) {
          peer.ackId = text.substring(2, text.indexOf('['));
          peer.requested.complete();
        }
      });
    });
    return peer;
  }

  void reply() => socket!.add(
    '43$ackId${jsonEncode([
      {'ok': true, 'result': 'encrypted-result'},
    ])}',
  );

  Future<void> close() async {
    socketIoClient.disconnect();
    await socket?.close();
    await server.close(force: true);
  }
}
