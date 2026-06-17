import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/core/services/loop_storage.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';

class _FakeMMKVStorage extends MMKVStorage {
  _FakeMMKVStorage() : super.testConstructor();

  final Map<String, String> _data = <String, String>{};

  @override
  String? getString(String key) => _data[key];

  @override
  void setString(String key, String value) {
    _data[key] = value;
  }

  @override
  void removeKey(String key) {
    _data.remove(key);
  }
}

Loop _sampleLoop({
  String id = 'id1234ab',
  String sessionId = 's1',
  String expression = '*/5 * * * *',
  String prompt = 'check the deploy',
  bool recurring = true,
  int fireCount = 0,
  int? lastFiredAt,
}) {
  return Loop(
    id: id,
    sessionId: sessionId,
    expression: expression,
    prompt: prompt,
    recurring: recurring,
    createdAt: 1700000000000,
    expiresAt: 1700604800000,
    lastFiredAt: lastFiredAt,
    fireCount: fireCount,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeMMKVStorage fake;
  late LoopStorage storage;

  setUp(() {
    fake = _FakeMMKVStorage();
    storage = LoopStorage.instance;
    storage.setStorageForTesting(fake);
  });

  group('LoopStorage', () {
    test('load returns empty list when nothing persisted', () {
      final result = storage.load('missing-session');
      expect(result, isEmpty);
    });

    test('save + load round-trips loops for a session', () {
      final loops = [
        _sampleLoop(id: 'aaaaaaaa', prompt: 'first'),
        _sampleLoop(id: 'bbbbbbbb', prompt: 'second', fireCount: 3),
      ];
      storage.save('s1', loops);

      final loaded = storage.load('s1');
      expect(loaded, hasLength(2));
      expect(loaded[0].id, 'aaaaaaaa');
      expect(loaded[0].prompt, 'first');
      expect(loaded[1].id, 'bbbbbbbb');
      expect(loaded[1].fireCount, 3);
    });

    test('save isolates data between sessions', () {
      storage.save('s1', [_sampleLoop(id: 'aaaaaaaa', sessionId: 's1')]);
      storage.save('s2', [_sampleLoop(id: 'cccccccc', sessionId: 's2')]);

      final s1 = storage.load('s1');
      final s2 = storage.load('s2');
      expect(s1.single.id, 'aaaaaaaa');
      expect(s2.single.id, 'cccccccc');
    });

    test('save overwrites previous data for the same session', () {
      storage.save('s1', [_sampleLoop(id: 'aaaaaaaa')]);
      storage.save('s1', [_sampleLoop(id: 'bbbbbbbb')]);

      final loaded = storage.load('s1');
      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'bbbbbbbb');
    });

    test('clear removes the persisted entry for a session', () {
      storage.save('s1', [_sampleLoop(id: 'aaaaaaaa')]);
      storage.clear('s1');

      expect(storage.load('s1'), isEmpty);
    });

    test('lastFiredAt round-trips as nullable', () {
      final withFire = _sampleLoop(lastFiredAt: 1700000060000);
      final withoutFire = _sampleLoop();
      storage.save('s1', [withFire, withoutFire]);

      final loaded = storage.load('s1');
      expect(loaded[0].lastFiredAt, 1700000060000);
      expect(loaded[1].lastFiredAt, isNull);
    });

    test('corrupt payload returns empty list and logs warning', () {
      fake.setString('loops:s1', jsonEncode({'not': 'a list'}));
      expect(storage.load('s1'), isEmpty);
    });
  });
}
