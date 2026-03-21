import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/message_cursor_manager.dart';

void main() {
  late MessageCursorManager manager;

  setUp(() {
    manager = MessageCursorManager();
  });

  group('advanceSeqCursor', () {
    test('sets initial value', () {
      final advanced =
          manager.advanceSeqCursor('s1', 10);
      expect(advanced, isTrue);
      expect(manager.lastSeq['s1'], 10);
    });

    test('advances to higher value', () {
      manager.advanceSeqCursor('s1', 10);
      final advanced =
          manager.advanceSeqCursor('s1', 20);
      expect(advanced, isTrue);
      expect(manager.lastSeq['s1'], 20);
    });

    test('ignores equal value', () {
      manager.advanceSeqCursor('s1', 10);
      final advanced =
          manager.advanceSeqCursor('s1', 10);
      expect(advanced, isFalse);
      expect(manager.lastSeq['s1'], 10);
    });

    test('ignores lower value', () {
      manager.advanceSeqCursor('s1', 10);
      final advanced =
          manager.advanceSeqCursor('s1', 5);
      expect(advanced, isFalse);
      expect(manager.lastSeq['s1'], 10);
    });

    test('tracks independent sessions', () {
      manager.advanceSeqCursor('s1', 10);
      manager.advanceSeqCursor('s2', 20);
      expect(manager.lastSeq['s1'], 10);
      expect(manager.lastSeq['s2'], 20);
    });
  });

  group('tailAfterSeq', () {
    test('no cursor — returns tail window', () {
      final result = manager.tailAfterSeq(
        's1',
        serverLastSeq: 500,
        initialLoad: 200,
      );
      // Gap = 500 - 0 = 500 > 200 → tail-load
      // knownLastSeq = max(0, 500) = 500
      // 500 - 200 = 300
      expect(result, 300);
    });

    test('cursor < serverLastSeq, small gap — returns '
        'cursor', () {
      manager.advanceSeqCursor('s1', 490);
      final result = manager.tailAfterSeq(
        's1',
        serverLastSeq: 500,
        initialLoad: 200,
      );
      // Gap = 500 - 490 = 10 <= 200 → return cursor
      expect(result, 490);
    });

    test('cursor < serverLastSeq, large gap — returns '
        'tail window', () {
      manager.advanceSeqCursor('s1', 100);
      final result = manager.tailAfterSeq(
        's1',
        serverLastSeq: 500,
        initialLoad: 200,
      );
      // Gap = 500 - 100 = 400 > 200 → tail-load
      // knownLastSeq = max(100, 500) = 500
      // 500 - 200 = 300
      expect(result, 300);
    });

    test('cursor > serverLastSeq — returns cursor (socket '
        'advanced past server)', () {
      manager.advanceSeqCursor('s1', 510);
      final result = manager.tailAfterSeq(
        's1',
        serverLastSeq: 500,
        initialLoad: 200,
      );
      expect(result, 510);
    });

    test('cursor == serverLastSeq — returns cursor (caught '
        'up)', () {
      manager.advanceSeqCursor('s1', 500);
      final result = manager.tailAfterSeq(
        's1',
        serverLastSeq: 500,
        initialLoad: 200,
      );
      // Gap = 0 <= 200 → return cursor
      expect(result, 500);
    });

    test('no cursor with small serverLastSeq returns 0',
        () {
      final result = manager.tailAfterSeq(
        's1',
        serverLastSeq: 50,
        initialLoad: 200,
      );
      // gap = 50 - 0 = 50 <= 200 → return cursor (0)
      expect(result, 0);
    });
  });

  group('removeSession', () {
    test('clears both maps', () {
      manager.advanceSeqCursor('s1', 10);
      manager.firstLoadedSeq['s1'] = 5;

      manager.removeSession('s1');

      expect(manager.lastSeq.containsKey('s1'), isFalse);
      expect(
        manager.firstLoadedSeq.containsKey('s1'),
        isFalse,
      );
    });

    test('does not affect other sessions', () {
      manager.advanceSeqCursor('s1', 10);
      manager.advanceSeqCursor('s2', 20);

      manager.removeSession('s1');

      expect(manager.lastSeq['s2'], 20);
    });
  });

  group('restore', () {
    test('populates from persisted data', () {
      manager.restore(
        {'s1': 100, 's2': 200},
        {'s1': 50},
      );

      expect(manager.lastSeq['s1'], 100);
      expect(manager.lastSeq['s2'], 200);
      expect(manager.firstLoadedSeq['s1'], 50);
    });

    test('clears existing data first', () {
      manager.advanceSeqCursor('s1', 999);
      manager.firstLoadedSeq['s1'] = 500;

      manager.restore({'s2': 10}, {});

      expect(
        manager.lastSeq.containsKey('s1'),
        isFalse,
      );
      expect(manager.lastSeq['s2'], 10);
    });
  });
}
