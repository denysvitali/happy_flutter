import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/loop_storage.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../../helpers/test_helpers.dart';

Loop _sample() => const Loop(
  id: 'loop1',
  sessionId: 's1',
  expression: '*/5 * * * *',
  prompt: 'check the deploy',
  recurring: true,
  createdAt: 1700000000000,
  expiresAt: 1700604800000,
);

Future<dynamic> _operate(Sync sync, String method) => switch (method) {
  'loop-create' => sync.createLoop(
    sessionId: 's1',
    expression: '*/5 * * * *',
    prompt: 'check the deploy',
    recurring: true,
  ),
  'loop-list' => sync.listLoops(sessionId: 's1'),
  'loop-delete' => sync.deleteLoop(sessionId: 's1', loopId: 'loop1'),
  'loop-pause' => sync.pauseLoop(
    sessionId: 's1',
    loopId: 'loop1',
    paused: true,
  ),
  _ => throw ArgumentError(method),
};

void main() {
  late Sync sync;
  late _MemoryStorage storage;

  setUp(() {
    sync = createTestSync();
    sync.testSessions.clear();
    sync.testMachines.clear();
    sync.testClearAllLoops();
    sync.testIsInitialized = true;
    sync.testSessionRPCOverride = null;
    storage = _MemoryStorage();
    LoopStorage.instance.setStorageForTesting(storage);
  });

  tearDown(() {
    sync.testSessionRPCOverride = null;
    sync.testResetRpcCapabilitiesPolicy();
    sync.testSocketConnectedOverride = null;
    sync.testClearAllLoops();
    LoopStorage.instance.setStorageForTesting(MMKVStorage());
  });

  for (final method in [
    'loop-create',
    'loop-list',
    'loop-delete',
    'loop-pause',
  ]) {
    test('$method cannot continue after a stale capability await', () async {
      sync.testLoopsBySession['s1'] = [_sample()];
      final started = Completer<void>();
      final release = Completer<dynamic>();
      var calls = 0;
      sync.testRpcCapabilitiesOverride = (scope, id, timeout) {
        started.complete();
        return release.future;
      };
      sync.testSessionRPCOverride = (_, _, _) async {
        calls++;
        return {'ok': true, 'loops': <dynamic>[], 'loop': _sample().toJson()};
      };
      final counter = sync.domainChangeCounter(SyncDomain.loops);
      final result = expectLater(_operate(sync, method), throwsStateError);
      await started.future;

      sync.testAdvanceRuntimeGeneration();
      sync.testClearAllLoops();
      release.complete({
        'scope': 'session',
        'protocolVersion': 2,
        'methods': [method],
      });
      await result;
      expect(calls, 0);
      expect(sync.loopsBySession, isEmpty);
      expect(storage.writes, 0);
      expect(sync.domainChangeCounter(SyncDomain.loops), counter);
    });

    test('$method rejects a stale RPC without rewriting reset state', () async {
      sync.testLoopsBySession['s1'] = [_sample()];
      final started = Completer<void>();
      final release = Completer<dynamic>();
      sync.testSessionRPCOverride = (_, _, _) {
        started.complete();
        return release.future;
      };
      final result = expectLater(_operate(sync, method), throwsStateError);
      await started.future;

      sync.testAdvanceRuntimeGeneration();
      sync.testClearAllLoops();
      LoopStorage.instance.clear('s1');
      final writes = storage.writes;
      final counter = sync.domainChangeCounter(SyncDomain.loops);
      release.complete({
        'ok': true,
        'loop': _sample().toJson(),
        'loops': [_sample().toJson()],
      });
      await result;
      expect(sync.loopsBySession, isEmpty);
      expect(LoopStorage.instance.load('s1'), isEmpty);
      expect(storage.writes, writes);
      expect(sync.domainChangeCounter(SyncDomain.loops), counter);
    });
  }

  for (final method in ['loop-create', 'loop-list']) {
    test('$method fences the caller continuation after RPC resolves', () async {
      final release = Completer<dynamic>();
      sync.testSessionRPCOverride = (_, _, _) => release.future;
      final counter = sync.domainChangeCounter(SyncDomain.loops);
      final result = expectLater(_operate(sync, method), throwsStateError);

      release.complete({
        'ok': true,
        'loop': _sample().toJson(),
        'loops': [_sample().toJson()],
      });
      // sessionRPC resumes first; replacement runs before the caller's
      // continuation can publish its successfully fenced RPC result.
      scheduleMicrotask(() {
        sync.testAdvanceRuntimeGeneration();
        sync.testClearAllLoops();
      });
      await result;
      expect(sync.loopsBySession, isEmpty);
      expect(storage.writes, 0);
      expect(sync.domainChangeCounter(SyncDomain.loops), counter);
    });
  }

  for (final method in ['loop-delete', 'loop-pause']) {
    for (final failure in ['transport', 'rejected']) {
      test('$method cannot retain or roll back a stale $failure', () async {
        sync.testLoopsBySession['s1'] = [_sample()];
        final started = Completer<void>();
        final release = Completer<dynamic>();
        var calls = 0;
        sync.testSessionRPCOverride = (_, _, _) {
          calls++;
          started.complete();
          return release.future;
        };
        final result = expectLater(_operate(sync, method), throwsStateError);
        await started.future;

        sync.testAdvanceRuntimeGeneration();
        sync.testClearAllLoops();
        LoopStorage.instance.clear('s1');
        final writes = storage.writes;
        if (failure == 'transport') {
          release.completeError(const SocketAckTimeoutException('rpc-call'));
        } else {
          release.complete({'ok': false, 'error': 'old rejection'});
        }
        await result;
        expect(calls, 1);
        expect(sync.loopsBySession, isEmpty);
        expect(storage.writes, writes);
      });
    }
  }

  test(
    'a stale refresh cannot block replacement-runtime capabilities',
    () async {
      sync.testSocketConnectedOverride = true;
      sync.testSessions['s1'] = Session(
        id: 's1',
        seq: 1,
        createdAt: 1,
        updatedAt: 1,
        active: true,
        activeAt: 1,
        metadataVersion: 1,
        agentStateVersion: 1,
        thinking: false,
      );
      final started = Completer<void>();
      final release = Completer<dynamic>();
      var calls = 0;
      sync.testSessionRPCOverride = (_, _, _) {
        calls++;
        if (calls == 1) {
          started.complete();
          return release.future;
        }
        return Future<dynamic>.value({'ok': true, 'loops': <dynamic>[]});
      };
      final refresh = sync.refreshAllLoops();
      await started.future;

      sync.testAdvanceRuntimeGeneration();
      release.completeError(
        const RpcException(
          code: RpcErrorCode.methodUnsupported,
          message: 'old daemon',
          retryable: false,
        ),
      );
      await refresh;
      await sync.refreshAllLoops();
      expect(calls, 2);
    },
  );
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
