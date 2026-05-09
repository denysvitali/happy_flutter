import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/windowed_message_store.dart';

WindowedMessage _msg(int ts, String id) {
  return WindowedMessage(
    id: id,
    localId: id,
    timestampMs: ts,
    raw: {'id': id, 'createdAt': ts},
  );
}

void main() {
  group('MessageCursor', () {
    test('orders by timestamp then id', () {
      const a = MessageCursor(timestampMs: 100, id: 'a');
      const b = MessageCursor(timestampMs: 100, id: 'b');
      const c = MessageCursor(timestampMs: 200, id: 'a');
      expect(a < b, true);
      expect(b < c, true);
      expect(a < c, true);
    });

    test('zero is the smallest cursor', () {
      const c = MessageCursor(timestampMs: 1, id: '');
      expect(MessageCursor.zero < c, true);
    });
  });

  group('WindowedMessageStore', () {
    test('upsert preserves ascending cursor order', () {
      final store = WindowedMessageStore();
      store.upsert(_msg(200, 'b'));
      store.upsert(_msg(100, 'a'));
      store.upsert(_msg(150, 'aa'));
      final ids = store.window.map((m) => m.id).toList();
      expect(ids, ['a', 'aa', 'b']);
    });

    test('upsert deduplicates by id', () {
      final store = WindowedMessageStore();
      store.upsert(_msg(100, 'a'));
      store.upsert(_msg(100, 'a'));
      expect(store.length, 1);
    });

    test('appendNewer trims oldest when over window size', () {
      final store = WindowedMessageStore(windowSize: 3);
      for (var i = 0; i < 10; i++) {
        store.upsert(_msg(i, 'm$i'));
      }
      expect(store.length, 3);
      expect(store.window.first.id, 'm7');
      expect(store.window.last.id, 'm9');
    });

    test('prependOlder keeps oldest when over window size', () {
      final store = WindowedMessageStore(windowSize: 3);
      for (var i = 5; i < 10; i++) {
        store.upsert(_msg(i, 'm$i'));
      }
      // Now prepend three older messages — the store should keep
      // them and drop the newest entries.
      store.prependOlder([_msg(0, 'm0'), _msg(1, 'm1'), _msg(2, 'm2')]);
      expect(store.length, 3);
      expect(store.window.map((m) => m.id).toList(), ['m0', 'm1', 'm2']);
    });

    test('oldest/newest cursors track window edges', () {
      final store = WindowedMessageStore();
      expect(store.oldestCursor, isNull);
      expect(store.newestCursor, isNull);
      store.upsert(_msg(50, 'a'));
      store.upsert(_msg(100, 'b'));
      expect(store.oldestCursor, const MessageCursor(timestampMs: 50, id: 'a'));
      expect(store.newestCursor, const MessageCursor(timestampMs: 100, id: 'b'));
    });
  });

  group('PaginatedMessageLoader', () {
    test('loadOlder fetches before the current oldest cursor', () async {
      final store = WindowedMessageStore();
      store.upsert(_msg(100, 'a'));
      MessageCursor? receivedCursor;
      final loader = PaginatedMessageLoader(
        store: store,
        fetcher: ({required before, required limit}) async {
          receivedCursor = before;
          return [_msg(50, 'older')];
        },
      );

      final added = await loader.loadOlder();
      expect(added, 1);
      expect(receivedCursor, const MessageCursor(timestampMs: 100, id: 'a'));
      expect(store.window.map((m) => m.id).toList(), ['older', 'a']);
    });

    test('loadOlder uses zero cursor when window is empty', () async {
      final store = WindowedMessageStore();
      MessageCursor? receivedCursor;
      final loader = PaginatedMessageLoader(
        store: store,
        fetcher: ({required before, required limit}) async {
          receivedCursor = before;
          return [];
        },
      );

      await loader.loadOlder();
      expect(receivedCursor, MessageCursor.zero);
    });

    test('loadOlder marks exhausted when page is short', () async {
      final store = WindowedMessageStore();
      var calls = 0;
      final loader = PaginatedMessageLoader(
        store: store,
        pageSize: 50,
        fetcher: ({required before, required limit}) async {
          calls++;
          // Return a page smaller than pageSize so loader marks
          // itself exhausted.
          return List.generate(5, (i) => _msg(i, 'm$i'));
        },
      );

      await loader.loadOlder();
      expect(loader.hasMore, false);
      // Subsequent calls are no-ops.
      await loader.loadOlder();
      expect(calls, 1);
    });

    test('concurrent loadOlder calls are deduped', () async {
      final store = WindowedMessageStore();
      var calls = 0;
      final loader = PaginatedMessageLoader(
        store: store,
        fetcher: ({required before, required limit}) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return [_msg(1, 'm1'), _msg(2, 'm2')];
        },
      );

      await Future.wait([loader.loadOlder(), loader.loadOlder()]);
      expect(calls, 1);
    });
  });
}
