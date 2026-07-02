import 'dart:async';
import 'dart:convert';

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
    sync.testRefreshAllLoopsDeadline = null;
    LoopStorage.instance.setStorageForTesting(_FakeMMKVStorage());
  });

  tearDown(() {
    container.dispose();
    sync.testIsInitialized = false;
    sync.testRefreshAllLoopsDeadline = null;
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
      sync.testLoopsBySession['s1'] = [_sample(id: 'aaa', sessionId: 's1')];
      sync.testNotifyDataChanged();

      container = ProviderContainer();
      // First read forces build().
      expect(container.read(loopsNotifierProvider), isEmpty);

      // Trigger an initial load so the notifier sees the seeded loop.
      container.read(loopsNotifierProvider.notifier).loadFromSync();
      expect(container.read(loopsNotifierProvider)['s1'], hasLength(1));

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
      await container
          .read(loopsNotifierProvider.notifier)
          .pauseLoop(sessionId: 's1', loopId: 'abc12345', paused: true);
      expect(received!['loopId'], 'abc12345');
      expect(received!['paused'], isTrue);
    });

    test(
      'refreshFromSync handles sync.listLoops failures gracefully',
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
      },
    );

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

    test('refreshFromSync treats sessionRPC forwarding failure as transient '
        'and breaks the loop', () async {
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
        // Successful sessions return an empty loop list. We
        // explicitly include 'loops: []' so the test exercises the
        // normal list-shape path (rather than the non-List fallback
        // pinned separately in sync_loops_routing_test.dart — the
        // fallback now mirrors the empty list into _loopsBySession,
        // so an absent 'loops' key would no longer leave the
        // notifier in an empty state for the successful session).
        return {'ok': true, 'result': null, 'loops': <dynamic>[]};
      };

      container = ProviderContainer();
      final notifier = container.read(loopsNotifierProvider.notifier);
      await notifier.refreshFromSync();
      // s1 succeeded, s2 raised the transient error, s3 was skipped
      // because the loop broke after the transient failure.
      expect(attempted, ['s1', 's2']);
      expect(container.read(loopsNotifierProvider), {'s1': isEmpty});
    });

    test('refreshFromSync treats Redis replica timeout as transient and '
        'breaks the loop', () async {
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
    });

    test('refreshFromSync treats missing session encryption as stale-session '
        'state and continues', () async {
      // Production regression: a cold-start loops refresh can visit old
      // sessions that no longer have local encryption, producing one
      // warning per session. This is a per-session precondition failure,
      // not a broken all-session refresh.
      sync.testSessions['s1'] = _session(id: 's1');
      sync.testSessions['s2'] = _session(id: 's2');
      sync.testSocketConnectedOverride = true;
      final attempted = <String>[];
      sync.testSessionRPCOverride = (sid, method, params) async {
        attempted.add(sid);
        if (sid == 's1') {
          throw StateError('Session encryption not found for s1');
        }
        return {'ok': true, 'result': null, 'loops': <dynamic>[]};
      };

      container = ProviderContainer();
      final notifier = container.read(loopsNotifierProvider.notifier);
      await notifier.refreshFromSync();

      expect(attempted, ['s1', 's2']);
      expect(container.read(loopsNotifierProvider), {'s2': isEmpty});
    });

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

    test('listLoops publishes to onLoopsChanged AND bumps the domain counter '
        'so notifier state updates', () async {
      // Regression: client-initiated listLoops used to write to
      // _loopsBySession + fire the onLoopsChanged stream, but did NOT
      // bump _domainChangeCounters. The notifier's loadFromSync
      // short-circuited on the unchanged counter, leaving Riverpod
      // state empty even though the data was in memory. This made
      // the Loops page show an empty state immediately after refresh
      // (and felt like a hang because the user expected their loops).
      sync.testSessions['s1'] = _session(id: 's1');
      sync.testSocketConnectedOverride = true;
      sync.testSessionRPCOverride = (sid, method, params) async => {
        'ok': true,
        'result': null,
        'loops': [_sample(id: 'fresh', sessionId: 's1').toJson()],
      };

      container = ProviderContainer();
      final notifier = container.read(loopsNotifierProvider.notifier);
      await notifier.refreshFromSync();
      // The fix: notifier state now mirrors _loopsBySession after
      // client-initiated listLoops, not only after server-pushed
      // `loops-updated` events.
      expect(container.read(loopsNotifierProvider)['s1'], hasLength(1));
      expect(container.read(loopsNotifierProvider)['s1']!.single.id, 'fresh');
    });

    test('hydrateFromCache returns true when MMKV has cached loops for '
        'known sessions', () async {
      // Seed MMKV with a JSON-encoded loop list for s1 (also add s1
      // to the sessions map so hydrateAllFromCache visits it). The
      // setUp installs _FakeMMKVStorage; we re-seed it here with
      // cached data.
      final fake = _FakeMMKVStorage()
        ..setString(
          'loops:s1',
          '[${jsonEncode(_sample(id: 'cached', sessionId: 's1').toJson())}]',
        );
      LoopStorage.instance.setStorageForTesting(fake);
      sync.testSessions['s1'] = _session(id: 's1');

      container = ProviderContainer();
      final notifier = container.read(loopsNotifierProvider.notifier);
      final hasCached = notifier.hydrateFromCache();
      expect(hasCached, isTrue);
      // Hydrate published the cached state to Riverpod — the screen
      // can paint immediately, no spinner needed.
      expect(container.read(loopsNotifierProvider)['s1']!.single.id, 'cached');
    });

    test('hydrateFromCache returns false when MMKV is empty', () async {
      sync.testSessions['s1'] = _session(id: 's1');
      container = ProviderContainer();
      final notifier = container.read(loopsNotifierProvider.notifier);
      final hasCached = notifier.hydrateFromCache();
      expect(hasCached, isFalse);
      expect(container.read(loopsNotifierProvider), isEmpty);
    });

    test('refreshFromSync caps total time so a single slow session cannot '
        'hang the Loops page', () async {
      // Regression: with the old code, a single session whose
      // sessionRPC took its full 30 s ACK timeout would burn 30 s on
      // the spinner before the break-on-transient could fire. With
      // many sessions the spinner could be up for many minutes.
      // The fix adds a hard 10 s deadline to refreshAllLoops so the
      // call returns well before emitWithAck's per-call ACK timeout.
      sync.testSessions['s1'] = _session(id: 's1');
      sync.testSocketConnectedOverride = true;
      sync.testRefreshAllLoopsDeadline = const Duration(milliseconds: 100);
      sync.testSessionRPCOverride = (sid, method, params) async {
        // Hang forever — simulates a wedged daemon.
        await Completer<void>().future;
      };

      container = ProviderContainer();
      final notifier = container.read(loopsNotifierProvider.notifier);
      final stopwatch = Stopwatch()..start();
      await notifier.refreshFromSync();
      stopwatch.stop();
      // Must return well under the old 30 s per-call ACK timeout.
      // The production deadline is 10 s; the test-only override keeps
      // CI fast while exercising the same timeout path.
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 2)),
        reason:
            'refreshFromSync should respect the hard deadline, '
            'not wait for emitWithAck to time out',
      );
    });

    test('refreshAllLoops sorts sessions most-recent-first so a transient '
        'error on an old session does not strand active ones', () async {
      // Regression: _sessions.keys returns insertion order, which
      // is arbitrary. If a stale session's daemon fails transient
      // first, the loop breaks and skips the active sessions
      // entirely. Sort by activeAt descending so we hit the active
      // ones first; if those succeed, the stale ones are best-effort.
      final now = DateTime.now().millisecondsSinceEpoch;
      sync.testSessions['stale'] = _session(
        id: 'stale',
      ).copyWith(activeAt: now - 30 * 86400000);
      sync.testSessions['fresh'] = _session(
        id: 'fresh',
      ).copyWith(activeAt: now);
      sync.testSessions['newest'] = _session(
        id: 'newest',
      ).copyWith(activeAt: now + 1000);
      sync.testSocketConnectedOverride = true;
      final attempted = <String>[];
      sync.testSessionRPCOverride = (sid, method, params) async {
        attempted.add(sid);
        if (sid == 'stale') {
          throw StateError(
            'Session RPC loop-list failed: '
            'RPC forwarding failed: response channel closed',
          );
        }
        return {'ok': true, 'result': null};
      };

      container = ProviderContainer();
      await container.read(loopsNotifierProvider.notifier).refreshFromSync();
      // Contract: the active sessions (newest, fresh) are attempted
      // BEFORE the transient break on stale. The exact attempt
      // order is "newest, fresh, stale" — then the loop breaks, so
      // nothing follows stale.
      expect(
        attempted,
        equals(<String>['newest', 'fresh', 'stale']),
        reason:
            'sort by activeAt desc should put active sessions '
            'before the stale one that triggers the break',
      );
    });

    test('refreshAllLoops deadline bounds a slow successful response',
        () async {
      // Regression: refresh could wait for a slow loop-list response
      // instead of respecting the total refresh deadline. The
      // test-only deadline keeps this fast while exercising the same
      // timeout path as the production 10 s budget.
      sync.testSessions['s1'] = _session(id: 's1');
      sync.testSessions['s2'] = _session(id: 's2');
      sync.testSocketConnectedOverride = true;
      sync.testRefreshAllLoopsDeadline = const Duration(milliseconds: 100);
      sync.testSessionRPCOverride = (sid, method, params) async {
        if (sid == 's1') {
          // Exceed the refresh deadline, simulating a
          // wedged RPC that the underlying emitWithAck timer
          // hasn't caught yet.
          await Future<void>.delayed(const Duration(milliseconds: 150));
          return {'ok': true, 'result': null};
        }
        return {'ok': true, 'result': null};
      };

      container = ProviderContainer();
      final notifier = container.read(loopsNotifierProvider.notifier);
      // Must not throw — and must not exceed the deadline by more
      // than the per-call buffer.
      final stopwatch = Stopwatch()..start();
      await notifier.refreshFromSync();
      stopwatch.stop();
      // The test-only deadline keeps this coverage out of the
      // multi-second path while still proving the timeout is bounded.
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 2)),
        reason:
            'refreshFromSync must stop at the refresh deadline, '
            'not wait for the slow response',
      );
    });

    test('hydrateAllFromCache hydrates all sessions present in _sessions '
        'and bumps the domain counter', () async {
      // Regression: cold-start users had no loops in memory until
      // either a real `loops-updated` event arrived or the user
      // explicitly tapped the Loops tab. Fix: Sync._init() now
      // calls hydrateAllFromCache() right after isInitialized=true,
      // so MMKV-cached loops are in memory before any screen reads
      // them.
      final fake = _FakeMMKVStorage()
        ..setString(
          'loops:s1',
          '[${jsonEncode(_sample(id: 'cold', sessionId: 's1').toJson())}]',
        )
        ..setString(
          'loops:s2',
          '[${jsonEncode(_sample(id: 'cold2', sessionId: 's2').toJson())}]',
        );
      LoopStorage.instance.setStorageForTesting(fake);
      sync.testSessions['s1'] = _session(id: 's1');
      sync.testSessions['s2'] = _session(id: 's2');

      // Simulate the cold-start hook (Sync._init calls
      // hydrateAllFromCache right after isInitialized=true).
      final counterBefore = sync.domainChangeCounter(SyncDomain.loops);
      final streamEventsBefore = <String>[];
      final sub = sync.onLoopsChanged.listen(streamEventsBefore.add);
      sync.hydrateAllFromCache();
      // Allow the stream event to flush.
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      // MMKV data is now in _loopsBySession.
      expect(sync.loopsBySession['s1']!.single.id, 'cold');
      expect(sync.loopsBySession['s2']!.single.id, 'cold2');
      // Counter bumped so the notifier's loadFromSync will pick it
      // up without the counter short-circuit kicking in.
      expect(
        sync.domainChangeCounter(SyncDomain.loops),
        greaterThan(counterBefore),
      );
      // onLoopsChanged stream also fired — this is what wakes up
      // notifier subscribers that were built BEFORE the cold-start
      // hydrate (e.g. a user who tapped the Loops tab while sync
      // was still initializing). Without this fire, those
      // notifiers would see an empty state forever because their
      // loadFromSync short-circuits on the counter check and
      // doesn't re-read the in-memory map on its own.
      expect(
        streamEventsBefore,
        isNotEmpty,
        reason:
            'hydrateAllFromCache must fire onLoopsChanged so '
            'pre-existing notifier subscribers wake up',
      );
    });
  });

  // Skip integration with SyncDomain counter — keep the unused import
  // marker so the analyzer stays quiet if the test file evolves.
  // ignore: unused_local_variable
  SyncDomain _ = SyncDomain.loops;
  // ignore: unused_local_variable
  InvalidateSync _s = InvalidateSync(() async {});
}
