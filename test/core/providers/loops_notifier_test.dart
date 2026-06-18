import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/loops_notifier.dart';
import 'package:happy_flutter/core/services/loop_storage.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';
import 'package:happy_flutter/core/utils/sync_domain.dart';
import '../../helpers/test_helpers.dart';

class _FakeMMKVStorage extends MMKVStorage {
  _FakeMMKVStorage() : super.testConstructor();
  final Map<String, String> _data = <String, String>{};
  @override
  String? getString(String key) => _data[key];
  @override
  void setString(String key, String value) => _data[key] = value;
  @override
  void removeKey(String key) => _data.remove(key);
}

Loop _sample({String id = 'id1234ab', String sessionId = 's1'}) {
  return Loop(
    id: id,
    sessionId: sessionId,
    expression: '*/5 * * * *',
    prompt: 'check the deploy',
    recurring: true,
    createdAt: 1700000000000,
    expiresAt: 1700604800000,
  );
}

Session _session({required String id}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 0,
    updatedAt: 0,
    active: true,
    activeAt: 0,
    metadataVersion: 0,
    agentStateVersion: 0,
    thinking: false,
    presence: 'offline',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late Sync sync;

  setUp(() {
    sync = createTestSync()..testLoopsBySession.clear();
    // Clear testSessions so the multi-session tests below see a clean
    // slate — Sync is a singleton and prior tests in this file leave
    // their seeded sessions behind.
    sync.testSessions.clear();
    sync.testIsInitialized = true;
    LoopStorage.instance.setStorageForTesting(_FakeMMKVStorage());
  });

  tearDown(() {
    container.dispose();
    sync.testIsInitialized = false;
  });

  group('LoopsNotifier', () {
    test('build() subscribes to onLoopsChanged', () async {
      sync.testLoopsBySession['s1'] = [_sample(id: 'aaa', sessionId: 's1')];
      sync.testNotifyDataChanged();

      container = ProviderContainer();
      // Initial read should be empty — provider starts as {} before
      // loadFromSync is called.
      expect(container.read(loopsNotifierProvider), isEmpty);

      // Fire a change — loadFromSync should pick up the seeded loop.
      container.read(loopsNotifierProvider.notifier).loadFromSync();
      final loops = container.read(loopsNotifierProvider);
      expect(loops['s1'], hasLength(1));
      expect(loops['s1']!.single.id, 'aaa');
    });

    test('loadFromSync no-ops when sync is not initialized', () {
      sync.testIsInitialized = false;
      container = ProviderContainer();
      container.read(loopsNotifierProvider.notifier).loadFromSync();
      // State stays empty because the guard kicked in.
      expect(container.read(loopsNotifierProvider), isEmpty);
    });

    test('onLoopsChanged triggers loadFromSync', () async {
      // Seed initial state with one loop.
      sync.testLoopsBySession['s1'] = [
        _sample(id: 'aaa', sessionId: 's1'),
      ];
      sync.testNotifyDataChanged();

      container = ProviderContainer();
      // First read forces build().
      expect(container.read(loopsNotifierProvider), isEmpty);

      // Trigger an initial load so the notifier sees the seeded loop.
      container.read(loopsNotifierProvider.notifier).loadFromSync();
      expect(
        container.read(loopsNotifierProvider)['s1'],
        hasLength(1),
      );

      // Add a second loop and emit onLoopsChanged.
      sync.testLoopsBySession['s1'] = [
        _sample(id: 'aaa', sessionId: 's1'),
        _sample(id: 'bbb', sessionId: 's1'),
      ];
      sync.testNotifyDataChanged();
      sync.testEmitLoopsChanged('s1');

      // Allow the stream event to flush.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final loops = container.read(loopsNotifierProvider);
      expect(loops['s1'], hasLength(2));
    });

    test('loopsForSession returns empty for unknown sessions', () {
      container = ProviderContainer();
      final notifier = container.read(loopsNotifierProvider.notifier);
      notifier.loadFromSync();
      expect(notifier.loopsForSession('unknown'), isEmpty);
      expect(notifier.countForSession('unknown'), 0);
    });

    test('createLoop delegates to sync.createLoop', () async {
      sync.testSessionRPCOverride = (sid, method, params) async {
        expect(method, 'loop-create');
        expect(sid, 's1');
        expect(params['expression'], '*/5 * * * *');
        expect(params['prompt'], 'check');
        expect(params['recurring'], isTrue);
        return {
          'ok': true,
          'loop': _sample(id: 'created', sessionId: 's1').toJson(),
        };
      };

      container = ProviderContainer();
      final notifier = container.read(loopsNotifierProvider.notifier);
      final loop = await notifier.createLoop(
        sessionId: 's1',
        expression: '*/5 * * * *',
        prompt: 'check',
        recurring: true,
      );
      expect(loop.id, 'created');
    });

    test('deleteLoop delegates to sync.deleteLoop', () async {
      var calledWith = '';
      sync.testSessionRPCOverride = (sid, method, params) async {
        calledWith = '${sid}:${params['loopId']}';
        return {'ok': true};
      };

      container = ProviderContainer();
      await container
          .read(loopsNotifierProvider.notifier)
          .deleteLoop(sessionId: 's1', loopId: 'abc12345');
      expect(calledWith, 's1:abc12345');
    });

    test('pauseLoop forwards paused flag', () async {
      Map<String, dynamic>? received;
      sync.testSessionRPCOverride = (sid, method, params) async {
        received = params;
        return {'ok': true};
      };

      container = ProviderContainer();
      await container.read(loopsNotifierProvider.notifier).pauseLoop(
            sessionId: 's1',
            loopId: 'abc12345',
            paused: true,
          );
      expect(received!['loopId'], 'abc12345');
      expect(received!['paused'], isTrue);
    });

    test('refreshFromSync handles sync.listLoops failures gracefully',
        () async {
      sync.testSessions['fail-session'] = _session(id: 'fail-session');
      sync.testSocketConnectedOverride = true;
      sync.testSessionRPCOverride = (sid, method, params) async {
        throw StateError('boom');
      };

      container = ProviderContainer();
      final notifier = container.read(loopsNotifierProvider.notifier);
      // Should not throw — refreshFromSync logs and continues.
      await notifier.refreshFromSync();
      expect(container.read(loopsNotifierProvider), isEmpty);
    });

    test('refreshFromSync skips RPC when socket is disconnected', () async {
      sync.testSessions['offline-session'] = _session(id: 'offline-session');
      sync.testSocketConnectedOverride = false;
      var rpcCalled = false;
      sync.testSessionRPCOverride = (sid, method, params) async {
        rpcCalled = true;
        throw StateError('should not be called');
      };

      container = ProviderContainer();
      final notifier = container.read(loopsNotifierProvider.notifier);
      // Should complete immediately and not invoke RPC while disconnected.
      await notifier.refreshFromSync();
      expect(rpcCalled, isFalse);
      expect(container.read(loopsNotifierProvider), isEmpty);
    });

    test(
      'refreshFromSync treats SocketNotConnectedException as transient',
      () async {
        sync.testSessions['flaky-session'] = _session(id: 'flaky-session');
        sync.testSocketConnectedOverride = true;
        sync.testSessionRPCOverride = (sid, method, params) async {
          throw const SocketNotConnectedException('rpc-call');
        };

        container = ProviderContainer();
        final notifier = container.read(loopsNotifierProvider.notifier);
        // Should not throw or surface the transient socket error.
        await notifier.refreshFromSync();
        expect(container.read(loopsNotifierProvider), isEmpty);
      },
    );

    test(
      'refreshFromSync treats sessionRPC forwarding failure as transient '
      'and breaks the loop',
      () async {
        // Three sessions — once session #2 raises a forwarding failure,
        // session #3 must NOT be attempted (each attempt waits for
        // emitWithAck to time out, so a stuck daemon would otherwise
        // stall refresh for ~10 s per session and flood Sentry with
        // warnings).
        sync.testSessions['s1'] = _session(id: 's1');
        sync.testSessions['s2'] = _session(id: 's2');
        sync.testSessions['s3'] = _session(id: 's3');
        sync.testSocketConnectedOverride = true;
        final attempted = <String>[];
        sync.testSessionRPCOverride = (sid, method, params) async {
          attempted.add(sid);
          if (sid == 's2') {
            throw StateError(
              'Session RPC loop-list failed: '
              'RPC forwarding failed: response channel closed',
            );
          }
          // Successful sessions return an empty loop list.
          return {'ok': true, 'result': null};
        };

        container = ProviderContainer();
        final notifier = container.read(loopsNotifierProvider.notifier);
        await notifier.refreshFromSync();
        // s1 succeeded, s2 raised the transient error, s3 was skipped
        // because the loop broke after the transient failure.
        expect(attempted, ['s1', 's2']);
        expect(container.read(loopsNotifierProvider), isEmpty);
      },
    );

    test(
      'refreshFromSync treats Redis replica timeout as transient and '
      'breaks the loop',
      () async {
        sync.testSessions['s1'] = _session(id: 's1');
        sync.testSessions['s2'] = _session(id: 's2');
        sync.testSocketConnectedOverride = true;
        final attempted = <String>[];
        sync.testSessionRPCOverride = (sid, method, params) async {
          attempted.add(sid);
          throw StateError(
            'Session RPC loop-list failed: forwarded via Redis, '
            'no replica responded within 5s',
          );
        };

        container = ProviderContainer();
        final notifier = container.read(loopsNotifierProvider.notifier);
        await notifier.refreshFromSync();
        // First session failed with a transient infra error — the loop
        // must break so we don't issue another doomed RPC for s2.
        expect(attempted, ['s1']);
      },
    );

    test(
      'refreshFromSync keeps iterating on non-transient StateError',
      () async {
        // A StateError that isn't transient AND isn't method-not-available
        // should be logged but the loop should continue to the next
        // session — that's the existing "best-effort" contract.
        sync.testSessions['s1'] = _session(id: 's1');
        sync.testSessions['s2'] = _session(id: 's2');
        sync.testSocketConnectedOverride = true;
        final attempted = <String>[];
        sync.testSessionRPCOverride = (sid, method, params) async {
          attempted.add(sid);
          throw StateError('some real failure');
        };

        container = ProviderContainer();
        final notifier = container.read(loopsNotifierProvider.notifier);
        await notifier.refreshFromSync();
        // Both sessions should have been attempted despite the failure.
        expect(attempted, ['s1', 's2']);
        expect(container.read(loopsNotifierProvider), isEmpty);
      },
    );
  });

  // Skip integration with SyncDomain counter — keep the unused import
  // marker so the analyzer stays quiet if the test file evolves.
  // ignore: unused_local_variable
  SyncDomain _ = SyncDomain.loops;
  // ignore: unused_local_variable
  InvalidateSync _s = InvalidateSync(() async {});
}
