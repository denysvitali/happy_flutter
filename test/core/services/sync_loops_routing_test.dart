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
  });
}
