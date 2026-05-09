import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/crdt/lww_register.dart';
import 'package:happy_flutter/core/crdt/settings_crdt.dart';

void main() {
  group('LwwTag', () {
    test('compareTo orders by timestamp then replicaId', () {
      const a = LwwTag(timestamp: 1, replicaId: 'a');
      const b = LwwTag(timestamp: 2, replicaId: 'a');
      const c = LwwTag(timestamp: 1, replicaId: 'b');
      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
      expect(a.compareTo(c), lessThan(0));
      expect(a.compareTo(a), 0);
    });

    test('roundtrips through JSON', () {
      const t = LwwTag(timestamp: 42, replicaId: 'r-7');
      final back = LwwTag.fromJson(t.toJson());
      expect(back, t);
    });
  });

  group('LwwMap', () {
    test('local set + get returns the value', () {
      var clock = 0;
      final m = LwwMap<String>(
          replicaId: 'A', clock: () => ++clock);
      m.set('theme', 'dark');
      expect(m.get('theme'), 'dark');
    });

    test('merge is commutative — same final state regardless of order', () {
      var clockA = 10;
      var clockB = 5;
      final a = LwwMap<String>(replicaId: 'A', clock: () => ++clockA);
      final b = LwwMap<String>(replicaId: 'B', clock: () => ++clockB);
      a.set('theme', 'dark'); // ts=11, replica=A
      b.set('theme', 'light'); // ts=6, replica=B  (older)

      final aThenB = a.copy()..merge(b);
      final bThenA = b.copy()..merge(a);

      expect(aThenB.get('theme'), 'dark');
      expect(bThenA.get('theme'), 'dark');
    });

    test('merge is idempotent', () {
      var clock = 0;
      final a = LwwMap<String>(replicaId: 'A', clock: () => ++clock);
      a.set('k', 'v');
      final b = a.copy();
      a.merge(b);
      a.merge(b);
      expect(a.get('k'), 'v');
    });

    test('higher timestamp wins; replicaId breaks ties', () {
      final a = LwwMap<String>(replicaId: 'A', clock: () => 1);
      final b = LwwMap<String>(replicaId: 'B', clock: () => 1);
      a.set('k', 'a');
      b.set('k', 'b');
      a.merge(b);
      expect(a.get('k'), 'b'); // 'B' > 'A' lexicographically
    });

    test('snapshot roundtrips through JSON', () {
      var clock = 0;
      final a = LwwMap<String>(replicaId: 'A', clock: () => ++clock);
      a.set('k', 'v');
      final json = a.toJson();
      final back = LwwMap.fromJson<String>(
        json,
        replicaId: 'A',
        clock: () => 99,
      );
      expect(back.get('k'), 'v');
    });
  });

  group('SettingsCrdt', () {
    test('local update returns wire patch and updates snapshot', () {
      final crdt = SettingsCrdt(replicaId: 'A', clock: () => 1);
      final patch = crdt.updateSetting('themeMode', 'dark');
      expect(crdt.snapshot()['themeMode'], 'dark');
      expect(patch.containsKey('themeMode'), isTrue);
      expect((patch['themeMode']! as Map)['value'], 'dark');
    });

    test('two replicas converge after exchanging patches', () {
      var clockA = 0;
      var clockB = 100;
      final a = SettingsCrdt(replicaId: 'A', clock: () => ++clockA);
      final b = SettingsCrdt(replicaId: 'B', clock: () => ++clockB);
      a.updateSetting('themeMode', 'dark');     // ts=1
      final bPatch = b.updateSetting('themeMode', 'light'); // ts=101
      final aPatch = {
        'themeMode': {
          'value': 'dark',
          'tag': {'timestamp': 1, 'replicaId': 'A'},
        },
      };
      a.applyRemote(bPatch);
      b.applyRemote(aPatch);
      expect(a.snapshot()['themeMode'], 'light');
      expect(b.snapshot()['themeMode'], 'light');
    });

    test('apply order does not matter (commutativity)', () {
      var clockA = 0;
      var clockB = 100;
      final a = SettingsCrdt(replicaId: 'A', clock: () => ++clockA);
      final b = SettingsCrdt(replicaId: 'B', clock: () => ++clockB);
      final p1 = a.updateSetting('themeMode', 'dark');
      final p2 = b.updateSetting('themeMode', 'light');
      final c1 = SettingsCrdt(replicaId: 'C', clock: () => 1)
        ..applyRemote(p1)
        ..applyRemote(p2);
      final c2 = SettingsCrdt(replicaId: 'C', clock: () => 1)
        ..applyRemote(p2)
        ..applyRemote(p1);
      expect(c1.snapshot()['themeMode'], c2.snapshot()['themeMode']);
    });

    test('applyRemote ignores non-map cell payloads silently', () {
      final crdt = SettingsCrdt(replicaId: 'A');
      crdt.applyRemote({'k': 'not a cell'});
      expect(crdt.get('k'), isNull);
    });
  });
}
