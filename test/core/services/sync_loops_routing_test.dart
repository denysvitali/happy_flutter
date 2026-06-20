import 'package:flutter_test/flutter_test.dart';
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
    test('non-List "loops" payload mirrors empty, persists, fires counter', () {
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

      final loops = sync.listLoops(sessionId: 's1');

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

      return Future<void>.delayed(Duration.zero).then((_) {
        expect(
          streamEventsBefore,
          contains('s1'),
          reason: 'listLoops must fire onLoopsChanged even on the '
              'non-List fallback so per-session subscribers rebuild',
        );
        return sub.cancel();
      });
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
