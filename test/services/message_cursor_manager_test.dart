import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/message_cursor_manager.dart';

void main() {
  late MessageCursorManager manager;

  setUp(() {
    manager = MessageCursorManager();
  });

  group('advanceSeqCursor', () {
    test('sets initial value', () {
      final advanced = manager.advanceSeqCursor('s1', 10);
      expect(advanced, isTrue);
      expect(manager.lastSeq['s1'], 10);
    });

    test('advances to higher value', () {
      manager.advanceSeqCursor('s1', 10);
      final advanced = manager.advanceSeqCursor('s1', 20);
      expect(advanced, isTrue);
      expect(manager.lastSeq['s1'], 20);
    });

    test('ignores equal value', () {
      manager.advanceSeqCursor('s1', 10);
      final advanced = manager.advanceSeqCursor('s1', 10);
      expect(advanced, isFalse);
      expect(manager.lastSeq['s1'], 10);
    });

    test('ignores lower value', () {
      manager.advanceSeqCursor('s1', 10);
      final advanced = manager.advanceSeqCursor('s1', 5);
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

    test('no cursor with small serverLastSeq returns 0', () {
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
      expect(manager.firstLoadedSeq.containsKey('s1'), isFalse);
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
      manager.restore({'s1': 100, 's2': 200}, {'s1': 50});

      expect(manager.lastSeq['s1'], 100);
      expect(manager.lastSeq['s2'], 200);
      expect(manager.firstLoadedSeq['s1'], 50);
    });

    test('clears existing data first', () {
      manager.advanceSeqCursor('s1', 999);
      manager.firstLoadedSeq['s1'] = 500;

      manager.restore({'s2': 10}, {});

      expect(manager.lastSeq.containsKey('s1'), isFalse);
      expect(manager.lastSeq['s2'], 10);
    });
  });

  group('computeFetchWindow', () {
    // Characterization suite for the window decision extracted out of the
    // 1,141-line fetchMessages. Each case pins the behaviour that was inline
    // before the extraction, so a future edit to the arithmetic fails here
    // rather than silently changing what the client asks the server for.

    MessageFetchWindow compute({
      bool isFirstLoad = false,
      bool forceTailRefresh = false,
      bool hasStrippedImages = false,
      int cursorSeq = 0,
      int serverLastSeq = 0,
      int? strippedImageAfterSeq,
      int initialLoad = 200,
    }) => manager.computeFetchWindow(
      's1',
      isFirstLoad: isFirstLoad,
      forceTailRefresh: forceTailRefresh,
      hasStrippedImages: hasStrippedImages,
      cursorSeq: cursorSeq,
      serverLastSeq: serverLastSeq,
      strippedImageAfterSeq: strippedImageAfterSeq,
      initialLoad: initialLoad,
    );

    group('tail load selection', () {
      test('first load always tail loads', () {
        expect(compute(isFirstLoad: true).useTailLoad, isTrue);
      });

      test('stripped images always tail loads', () {
        expect(compute(hasStrippedImages: true).useTailLoad, isTrue);
      });

      test('forced refresh tail loads only without a cursor', () {
        expect(compute(forceTailRefresh: true).useTailLoad, isTrue);
        expect(
          compute(forceTailRefresh: true, cursorSeq: 50).useTailLoad,
          isFalse,
          reason:
              'with an in-memory prefix a tail jump would leave a missing '
              'middle, so the fetch must continue from the cursor',
        );
      });

      test('plain delta fetch does not tail load', () {
        expect(compute(cursorSeq: 50, serverLastSeq: 60).useTailLoad, isFalse);
      });
    });

    group('gap recovery flag', () {
      test('set for a forced refresh with no cursor', () {
        expect(compute(forceTailRefresh: true).isGapRecovery, isTrue);
      });

      test('set for stripped images', () {
        expect(compute(hasStrippedImages: true).isGapRecovery, isTrue);
      });

      test('not set for an ordinary first load', () {
        expect(compute(isFirstLoad: true).isGapRecovery, isFalse);
      });

      test('not set when the forced refresh continues from a cursor', () {
        expect(
          compute(forceTailRefresh: true, cursorSeq: 50).isGapRecovery,
          isFalse,
        );
      });
    });

    group('tail window arithmetic', () {
      test('short session loads from the very beginning', () {
        // knownMax <= initialLoad, so there is nothing older to skip.
        expect(compute(isFirstLoad: true, serverLastSeq: 150).afterSeq, 0);
      });

      test('long session starts initialLoad messages from the end', () {
        expect(compute(isFirstLoad: true, serverLastSeq: 1000).afterSeq, 800);
      });

      test('window barely over initialLoad rounds down to zero', () {
        // after_seq=N returns seq > N, so 1..10 would skip the first
        // message(s) of the conversation entirely.
        expect(compute(isFirstLoad: true, serverLastSeq: 205).afterSeq, 0);
        expect(compute(isFirstLoad: true, serverLastSeq: 210).afterSeq, 0);
        expect(compute(isFirstLoad: true, serverLastSeq: 211).afterSeq, 11);
      });

      test('uses the higher of cursor and server seq', () {
        expect(
          compute(
            isFirstLoad: true,
            cursorSeq: 1000,
            serverLastSeq: 400,
          ).afterSeq,
          800,
        );
      });

      test('stripped-image seq overrides the computed window', () {
        expect(
          compute(
            hasStrippedImages: true,
            serverLastSeq: 1000,
            strippedImageAfterSeq: 42,
          ).afterSeq,
          42,
        );
      });

      test('honours a non-default initialLoad (web uses 100)', () {
        expect(
          compute(
            isFirstLoad: true,
            serverLastSeq: 1000,
            initialLoad: 100,
          ).afterSeq,
          900,
        );
      });
    });

    group('delta window', () {
      test('continues from the cursor when one exists', () {
        expect(compute(cursorSeq: 50, serverLastSeq: 60).afterSeq, 50);
      });

      test('falls back to tailAfterSeq when no cursor exists', () {
        // No cursor and a gap larger than initialLoad: tailAfterSeq trims to
        // the last initialLoad messages.
        expect(compute(serverLastSeq: 1000).afterSeq, 800);
      });

      test('falls back to tailAfterSeq for a small gap', () {
        expect(compute(serverLastSeq: 30).afterSeq, 0);
      });
    });

    group('firstLoadedSeq', () {
      test('is afterSeq + 1 on a first load with older history', () {
        final window = compute(isFirstLoad: true, serverLastSeq: 1000);
        expect(window.afterSeq, 800);
        expect(
          window.firstLoadedSeq,
          801,
          reason: 'the oldest message actually loaded is afterSeq + 1',
        );
      });

      test('is 0 on a first load that covers the whole history', () {
        expect(
          compute(isFirstLoad: true, serverLastSeq: 150).firstLoadedSeq,
          0,
        );
      });

      test('is null on any non-first load, so the caller leaves it alone', () {
        expect(
          compute(cursorSeq: 50, serverLastSeq: 60).firstLoadedSeq,
          isNull,
        );
        expect(compute(forceTailRefresh: true).firstLoadedSeq, isNull);
        expect(compute(hasStrippedImages: true).firstLoadedSeq, isNull);
      });
    });
  });
}
