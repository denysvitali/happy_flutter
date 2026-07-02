import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/core/services/loop_storage.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
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

Map<String, dynamic> _agentEvent(Map<String, dynamic> event) => {
      'id': 'm-${event['type']}',
      'seq': 1,
      'createdAt': 1700000000000,
      'role': 'agent',
      'kind': 'agent-event',
      'event': event,
      'content': '',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Sync sync;

  setUp(() {
    sync = createTestSync()..testLoopsBySession.clear();
    sync.testSessions.clear();
    sync.testIsInitialized = true;
    LoopStorage.instance.setStorageForTesting(_FakeMMKVStorage());
  });

  group('consumeLoopControlMessages', () {
    test('routes loops-updated into state and strips the control event', () {
      final out = sync.consumeLoopControlMessages('s1', [
        _agentEvent({
          'type': 'loops-updated',
          'sid': 's1',
          'loops': [_sample(id: 'aaaaaaaa').toJson()],
        }),
      ]);

      // Control event must not survive into the chat list.
      expect(out, isEmpty);
      expect(sync.loopsForSession('s1'), hasLength(1));
      expect(sync.loopsForSession('s1').single.id, 'aaaaaaaa');
    });

    test('loop-fired bumps fireCount and lastFiredAt', () {
      sync.testLoopsBySession['s1'] = [_sample(id: 'aaaaaaaa')];

      final out = sync.consumeLoopControlMessages('s1', [
        _agentEvent({
          'type': 'loop-fired',
          'sid': 's1',
          'loopId': 'aaaaaaaa',
          'firedAt': 1700000123000,
          'fireCount': 3,
        }),
      ]);

      expect(out, isEmpty);
      final loop = sync.loopsForSession('s1').single;
      expect(loop.fireCount, 3);
      expect(loop.lastFiredAt, 1700000123000);
    });

    test('loop-expired removes the loop', () {
      sync.testLoopsBySession['s1'] = [
        _sample(id: 'aaaaaaaa'),
        _sample(id: 'bbbbbbbb'),
      ];

      final out = sync.consumeLoopControlMessages('s1', [
        _agentEvent({
          'type': 'loop-expired',
          'sid': 's1',
          'loopId': 'aaaaaaaa',
        }),
      ]);

      expect(out, isEmpty);
      expect(sync.loopsForSession('s1'), hasLength(1));
      expect(sync.loopsForSession('s1').single.id, 'bbbbbbbb');
    });

    test('non-loop messages pass through untouched', () {
      final chat = {
        'id': 'm1',
        'seq': 2,
        'role': 'agent',
        'kind': 'agent-text',
        'content': 'hello',
      };
      final out = sync.consumeLoopControlMessages('s1', [chat]);
      expect(out, hasLength(1));
      expect(identical(out.single, chat), isTrue);
    });

    test('falls back to the owning session when sid is absent', () {
      final out = sync.consumeLoopControlMessages('s2', [
        _agentEvent({
          'type': 'loops-updated',
          'loops': [_sample(id: 'cccccccc', sessionId: 's2').toJson()],
        }),
      ]);
      expect(out, isEmpty);
      expect(sync.loopsForSession('s2'), hasLength(1));
    });

    test('routes bump the loops domain counter so LoopsNotifier wakes up', () {
      // Regression: if the in-band routing path forgets to call
      // _notifyDataChanged({SyncDomain.loops}), the notifier's
      // _lastChangeCounter guard short-circuits loadFromSync and
      // the Riverpod state stays empty even though _loopsBySession
      // has the new data. Pin the bump explicitly for all 3 control
      // event types.
      final before = sync.domainChangeCounter(SyncDomain.loops);

      sync.consumeLoopControlMessages('s1', [
        _agentEvent({
          'type': 'loops-updated',
          'sid': 's1',
          'loops': [_sample(id: 'aaaaaaaa').toJson()],
        }),
      ]);
      expect(
        sync.domainChangeCounter(SyncDomain.loops),
        greaterThan(before),
        reason: 'loops-updated must bump the loops domain counter',
      );

      final afterFirst = sync.domainChangeCounter(SyncDomain.loops);
      sync.testLoopsBySession['s1'] = [_sample(id: 'aaaaaaaa')];
      sync.consumeLoopControlMessages('s1', [
        _agentEvent({
          'type': 'loop-fired',
          'sid': 's1',
          'loopId': 'aaaaaaaa',
          'firedAt': 1700000123000,
          'fireCount': 2,
        }),
      ]);
      expect(
        sync.domainChangeCounter(SyncDomain.loops),
        greaterThan(afterFirst),
        reason: 'loop-fired must bump the loops domain counter',
      );

      final afterSecond = sync.domainChangeCounter(SyncDomain.loops);
      sync.consumeLoopControlMessages('s1', [
        _agentEvent({
          'type': 'loop-expired',
          'sid': 's1',
          'loopId': 'aaaaaaaa',
        }),
      ]);
      expect(
        sync.domainChangeCounter(SyncDomain.loops),
        greaterThan(afterSecond),
        reason: 'loop-expired must bump the loops domain counter',
      );
    });

    test('malformed entry in loops-updated is skipped, valid ones survive', () {
      // Regression: prior to the WireParsers migration,
      // Loop.fromJson would throw on a single malformed entry and
      // the whole batch would fail. With tryFromJson the bad entry
      // is silently dropped and the rest of the list is honored.
      final out = sync.consumeLoopControlMessages('s1', [
        _agentEvent({
          'type': 'loops-updated',
          'sid': 's1',
          'loops': [
            _sample(id: 'good1').toJson(),
            // missing all required fields
            <String, dynamic>{'id': 'bad1'},
            _sample(id: 'good2').toJson(),
            // string-typed numerics (legacy backend shape) — now valid
            <String, dynamic>{
              'id': 'good3',
              'sessionId': 's1',
              'expression': '*/5 * * * *',
              'prompt': 'check',
              'recurring': true,
              'createdAt': '1700000000000',
              'expiresAt': '1700604800000',
            },
          ],
        }),
      ]);

      expect(out, isEmpty);
      final ids = sync.loopsForSession('s1').map((l) => l.id).toList();
      expect(ids, ['good1', 'good2', 'good3']);
    });
  });

  group('listLoops non-List fallback', () {
    test('non-List "loops" payload mirrors empty, persists, fires counter', () async {
      // Regression: the previous code returned `const <Loop>[]` silently
      // on a non-List payload — no breadcrumb, no _loopsChangeController
      // fire, no _notifyDataChanged, no MMKV clear. A daemon that
      // legitimately has no loops (or returned a non-List shape by
      // mistake) would leave the user looking at a stale cached list
      // forever. The fix mirrors the empty list through every
      // notification path so subscribers and the notifier both wake up.
      sync.testSessionRPCOverride = (sid, method, params) async => <String, dynamic>{
            'ok': true,
            // 'loops' is intentionally not a List — a buggy daemon
            // could return a string, a map, or be missing entirely.
            'loops': 'not-a-list',
          };

      final counterBefore = sync.domainChangeCounter(SyncDomain.loops);
      final streamEventsBefore = <String>[];
      final sub = sync.onLoopsChanged.listen(streamEventsBefore.add);

      final loops = await sync.listLoops(sessionId: 's1');

      // Empty list returned, but every notification path fired.
      expect(loops, isEmpty);
      expect(sync.loopsForSession('s1'), isEmpty);
      expect(
        sync.domainChangeCounter(SyncDomain.loops),
        greaterThan(counterBefore),
        reason: 'listLoops must bump the loops domain counter on the '
            'non-List fallback, so the notifier wakes up and clears '
            'any stale cached list',
      );

      // Allow the stream event to flush.
      await Future<void>.delayed(Duration.zero);
      expect(
        streamEventsBefore,
        contains('s1'),
        reason: 'listLoops must fire onLoopsChanged even on the '
            'non-List fallback so per-session subscribers rebuild',
      );
      await sub.cancel();
    });

    test('daemon ok:false preserves local loops and rethrows', () async {
      sync.testLoopsBySession['s1'] = [
        _sample(id: 'aaaaaaaa'),
        _sample(id: 'bbbbbbbb'),
      ];
      sync.testSessionRPCOverride = (sid, method, params) async {
        expect(method, 'loop-list');
        return {'ok': false, 'error': 'scheduler unavailable'};
      };

      final counterBefore = sync.domainChangeCounter(SyncDomain.loops);

      await expectLater(
        sync.listLoops(sessionId: 's1'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'loop-list failed: scheduler unavailable',
          ),
        ),
      );

      expect(
        sync.loopsForSession('s1').map((l) => l.id).toList(),
        ['aaaaaaaa', 'bbbbbbbb'],
        reason: 'daemon rejection must not clear the cached loop mirror',
      );
      expect(
        sync.domainChangeCounter(SyncDomain.loops),
        counterBefore,
        reason: 'failed listLoops must not publish a loops domain change',
      );
    });
  });

  group('deleteLoop', () {
    test('removes the confirmed delete from local loop state', () async {
      sync.testLoopsBySession['s1'] = [
        _sample(id: 'aaaaaaaa'),
        _sample(id: 'bbbbbbbb'),
      ];
      sync.testSessionRPCOverride = (sid, method, params) async {
        expect(sid, 's1');
        expect(method, 'loop-delete');
        expect(params['loopId'], 'aaaaaaaa');
        return {'ok': true};
      };
      final counterBefore = sync.domainChangeCounter(SyncDomain.loops);
      final streamEvents = <String>[];
      final sub = sync.onLoopsChanged.listen(streamEvents.add);

      await sync.deleteLoop(sessionId: 's1', loopId: 'aaaaaaaa');

      final ids = sync.loopsForSession('s1').map((l) => l.id).toList();
      expect(ids, ['bbbbbbbb']);
      expect(
        sync.domainChangeCounter(SyncDomain.loops),
        greaterThan(counterBefore),
      );

      await Future<void>.delayed(Duration.zero);
      expect(streamEvents, contains('s1'));
      await sub.cancel();
    });

    test('optimistic deletion removes loop before RPC round-trip', () async {
      sync.testLoopsBySession['s1'] = [
        _sample(id: 'aaaaaaaa'),
        _sample(id: 'bbbbbbbb'),
      ];
      // RPC returns success after a microtask delay
      sync.testSessionRPCOverride = (sid, method, params) async {
        await Future<void>.delayed(Duration.zero);
        return {'ok': true};
      };

      // Start the delete but do not await it fully
      final future = sync.deleteLoop(sessionId: 's1', loopId: 'aaaaaaaa');

      // Immediately after calling (before RPC resolves), the loop should
      // already be gone from local state.
      expect(
        sync.loopsForSession('s1').map((l) => l.id).toList(),
        ['bbbbbbbb'],
        reason: 'loop must be optimistically removed before RPC completes',
      );

      await future;
      // Still gone after RPC resolves.
      expect(sync.loopsForSession('s1').map((l) => l.id).toList(), ['bbbbbbbb']);
    });

    test('StateError "Session encryption not found" is swallowed, loop stays removed', () async {
      sync.testLoopsBySession['s1'] = [
        _sample(id: 'aaaaaaaa'),
        _sample(id: 'bbbbbbbb'),
      ];
      sync.testSessionRPCOverride = (sid, method, params) async {
        throw StateError('Session encryption not found for s1');
      };

      await sync.deleteLoop(sessionId: 's1', loopId: 'aaaaaaaa');

      expect(
        sync.loopsForSession('s1').map((l) => l.id).toList(),
        ['bbbbbbbb'],
        reason: 'loop must stay removed when session is dead',
      );
    });

    test('StateError "no scheduler for session" is swallowed, loop stays removed', () async {
      sync.testLoopsBySession['s1'] = [
        _sample(id: 'aaaaaaaa'),
        _sample(id: 'bbbbbbbb'),
      ];
      sync.testSessionRPCOverride = (sid, method, params) async {
        throw StateError('no scheduler for session s1');
      };

      await sync.deleteLoop(sessionId: 's1', loopId: 'aaaaaaaa');

      expect(
        sync.loopsForSession('s1').map((l) => l.id).toList(),
        ['bbbbbbbb'],
        reason: 'loop must stay removed when daemon has no scheduler',
      );
    });

    test('SocketNotConnectedException is swallowed, loop stays removed', () async {
      sync.testLoopsBySession['s1'] = [
        _sample(id: 'aaaaaaaa'),
        _sample(id: 'bbbbbbbb'),
      ];
      sync.testSessionRPCOverride = (sid, method, params) async {
        throw SocketNotConnectedException('test');
      };

      await sync.deleteLoop(sessionId: 's1', loopId: 'aaaaaaaa');

      expect(
        sync.loopsForSession('s1').map((l) => l.id).toList(),
        ['bbbbbbbb'],
        reason: 'loop must stay removed when socket is disconnected',
      );
    });

    test('SocketAckTimeoutException is swallowed, loop stays removed', () async {
      sync.testLoopsBySession['s1'] = [
        _sample(id: 'aaaaaaaa'),
        _sample(id: 'bbbbbbbb'),
      ];
      sync.testSessionRPCOverride = (sid, method, params) async {
        throw SocketAckTimeoutException('ack timeout');
      };

      await sync.deleteLoop(sessionId: 's1', loopId: 'aaaaaaaa');

      expect(
        sync.loopsForSession('s1').map((l) => l.id).toList(),
        ['bbbbbbbb'],
        reason: 'loop must stay removed when RPC times out',
      );
    });

    test('unexpected StateError is rethrown and loop stays removed', () async {
      sync.testLoopsBySession['s1'] = [
        _sample(id: 'aaaaaaaa'),
        _sample(id: 'bbbbbbbb'),
      ];
      sync.testSessionRPCOverride = (sid, method, params) async {
        throw StateError('something else went wrong');
      };

      await expectLater(
        sync.deleteLoop(sessionId: 's1', loopId: 'aaaaaaaa'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'something else went wrong')),
      );

      // Optimistic removal happened before the throw.
      expect(
        sync.loopsForSession('s1').map((l) => l.id).toList(),
        ['bbbbbbbb'],
      );
    });

    test('daemon ok:false rolls back and rethrows', () async {
      sync.testLoopsBySession['s1'] = [
        _sample(id: 'aaaaaaaa'),
        _sample(id: 'bbbbbbbb'),
      ];
      // First call: delete rejection. Second call: listLoops rollback.
      var callCount = 0;
      sync.testSessionRPCOverride = (sid, method, params) async {
        callCount++;
        if (method == 'loop-delete') {
          return {'ok': false, 'error': 'loop not found'};
        }
        if (method == 'loop-list') {
          return {
            'ok': true,
            'loops': [
              _sample(id: 'aaaaaaaa').toJson(),
              _sample(id: 'bbbbbbbb').toJson(),
            ],
          };
        }
        return {'ok': true};
      };

      await expectLater(
        sync.deleteLoop(sessionId: 's1', loopId: 'aaaaaaaa'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'loop-delete failed: loop not found')),
      );

      expect(callCount, 2, reason: 'must call loop-delete then loop-list for rollback');
      // After rollback, the loop should be back.
      expect(
        sync.loopsForSession('s1').map((l) => l.id).toList(),
        ['aaaaaaaa', 'bbbbbbbb'],
        reason: 'loop must be restored after daemon rejection',
      );
    });
  });

  group('pauseLoop', () {
    test('optimistic pause toggles before RPC round-trip', () async {
      sync.testLoopsBySession['s1'] = [
        _sample(id: 'aaaaaaaa').copyWith(paused: false),
        _sample(id: 'bbbbbbbb').copyWith(paused: false),
      ];
      sync.testSessionRPCOverride = (sid, method, params) async {
        await Future<void>.delayed(Duration.zero);
        return {'ok': true};
      };

      final future = sync.pauseLoop(
        sessionId: 's1',
        loopId: 'aaaaaaaa',
        paused: true,
      );

      // Immediately after calling, the paused flag should be toggled.
      expect(
        sync.loopsForSession('s1').firstWhere((l) => l.id == 'aaaaaaaa').paused,
        isTrue,
        reason: 'paused flag must be toggled optimistically before RPC completes',
      );

      await future;
      expect(
        sync.loopsForSession('s1').firstWhere((l) => l.id == 'aaaaaaaa').paused,
        isTrue,
      );
    });

    test('StateError "no scheduler for session" is swallowed, pause retained', () async {
      sync.testLoopsBySession['s1'] = [
        _sample(id: 'aaaaaaaa').copyWith(paused: false),
      ];
      sync.testSessionRPCOverride = (sid, method, params) async {
        throw StateError('no scheduler for session s1');
      };

      await sync.pauseLoop(
        sessionId: 's1',
        loopId: 'aaaaaaaa',
        paused: true,
      );

      expect(
        sync.loopsForSession('s1').single.paused,
        isTrue,
        reason: 'optimistic pause must be retained when session is dead',
      );
    });

    test('StateError "Session encryption not found" is swallowed, pause retained', () async {
      sync.testLoopsBySession['s1'] = [
        _sample(id: 'aaaaaaaa').copyWith(paused: false),
      ];
      sync.testSessionRPCOverride = (sid, method, params) async {
        throw StateError('Session encryption not found for s1');
      };

      await sync.pauseLoop(
        sessionId: 's1',
        loopId: 'aaaaaaaa',
        paused: true,
      );

      expect(
        sync.loopsForSession('s1').single.paused,
        isTrue,
        reason: 'optimistic pause must be retained when encryption is gone',
      );
    });

    test('SocketNotConnectedException is swallowed, pause retained', () async {
      sync.testLoopsBySession['s1'] = [
        _sample(id: 'aaaaaaaa').copyWith(paused: false),
      ];
      sync.testSessionRPCOverride = (sid, method, params) async {
        throw SocketNotConnectedException('test');
      };

      await sync.pauseLoop(
        sessionId: 's1',
        loopId: 'aaaaaaaa',
        paused: true,
      );

      expect(
        sync.loopsForSession('s1').single.paused,
        isTrue,
        reason: 'optimistic pause must be retained when socket is disconnected',
      );
    });

    test('SocketAckTimeoutException is swallowed, pause retained', () async {
      sync.testLoopsBySession['s1'] = [
        _sample(id: 'aaaaaaaa').copyWith(paused: false),
      ];
      sync.testSessionRPCOverride = (sid, method, params) async {
        throw SocketAckTimeoutException('ack timeout');
      };

      await sync.pauseLoop(
        sessionId: 's1',
        loopId: 'aaaaaaaa',
        paused: true,
      );

      expect(
        sync.loopsForSession('s1').single.paused,
        isTrue,
        reason: 'optimistic pause must be retained when RPC times out',
      );
    });

    test('daemon ok:false rolls back and rethrows', () async {
      sync.testLoopsBySession['s1'] = [
        _sample(id: 'aaaaaaaa').copyWith(paused: false),
      ];
      var callCount = 0;
      sync.testSessionRPCOverride = (sid, method, params) async {
        callCount++;
        if (method == 'loop-pause') {
          return {'ok': false, 'error': 'loop not found'};
        }
        if (method == 'loop-list') {
          return {
            'ok': true,
            'loops': [_sample(id: 'aaaaaaaa').copyWith(paused: false).toJson()],
          };
        }
        return {'ok': true};
      };

      await expectLater(
        sync.pauseLoop(sessionId: 's1', loopId: 'aaaaaaaa', paused: true),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'loop-pause failed: loop not found')),
      );

      expect(callCount, 2);
      expect(
        sync.loopsForSession('s1').single.paused,
        isFalse,
        reason: 'paused flag must be rolled back after daemon rejection',
      );
    });
  });

  group('clearLoopsForSession', () {
    test('fires onLoopsChanged + bumps the domain counter', () {
      // Regression: clear was the only mutating path that didn't
      // publish — every other mutator in _sync_loops.dart
      // (_applyLoopsUpdate / _applyLoopFired / _applyLoopExpired /
      // listLoops) fires the stream and bumps the counter. Session
      // delete would leave the loops screen rendering a stale list
      // until the next unrelated change.
      sync.testLoopsBySession['s1'] = [_sample(id: 'aaaaaaaa')];
      final counterBefore = sync.domainChangeCounter(SyncDomain.loops);
      final streamEvents = <String>[];
      final sub = sync.onLoopsChanged.listen(streamEvents.add);

      sync.clearLoopsForSession('s1');

      expect(sync.loopsBySession['s1'], isNull);
      expect(
        sync.domainChangeCounter(SyncDomain.loops),
        greaterThan(counterBefore),
      );

      return Future<void>.delayed(Duration.zero).then((_) {
        expect(streamEvents, contains('s1'));
        return sub.cancel();
      });
    });
  });
}
