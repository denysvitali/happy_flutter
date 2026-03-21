import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/inline_message_processor.dart';

void main() {
  late InlineMessageProcessor processor;

  setUp(() {
    processor = InlineMessageProcessor();
  });

  group('InlineMessageProcessor', () {
    test('processes single message', () async {
      var called = false;
      processor.enqueue('s1', () async {
        called = true;
      });
      // Let microtask complete
      await Future<void>.delayed(Duration.zero);
      expect(called, isTrue);
    });

    test('serialises messages for same session', () async {
      final order = <int>[];
      final c1 = Completer<void>();
      final c2 = Completer<void>();

      processor.enqueue('s1', () async {
        await c1.future;
        order.add(1);
      });
      processor.enqueue('s1', () async {
        await c2.future;
        order.add(2);
      });

      // Neither has completed yet
      expect(order, isEmpty);

      // Complete second before first — order must be 1, 2
      c2.complete();
      await Future<void>.delayed(Duration.zero);
      // Still waiting on first
      expect(order, isEmpty);

      c1.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(order, [1, 2]);
    });

    test('allows concurrent processing across sessions',
        () async {
      final order = <String>[];
      final c1 = Completer<void>();
      final c2 = Completer<void>();

      processor.enqueue('s1', () async {
        await c1.future;
        order.add('s1');
      });
      processor.enqueue('s2', () async {
        await c2.future;
        order.add('s2');
      });

      // Complete s2 first
      c2.complete();
      await Future<void>.delayed(Duration.zero);
      expect(order, ['s2']);

      c1.complete();
      await Future<void>.delayed(Duration.zero);
      expect(order, ['s2', 's1']);
    });

    test('error does not block next message', () async {
      final order = <int>[];

      processor.enqueue('s1', () async {
        order.add(1);
        throw Exception('boom');
      });
      processor.enqueue('s1', () async {
        order.add(2);
      });

      // Let microtasks complete
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      // Both should have run despite the first throwing
      expect(order, [1, 2]);
    });

    test('clearSession removes queue entry', () {
      processor.enqueue('s1', () async {});
      expect(processor.contains('s1'), isTrue);

      processor.clearSession('s1');
      expect(processor.contains('s1'), isFalse);
    });

    test('clear removes all sessions', () async {
      processor.enqueue('s1', () async {});
      processor.enqueue('s2', () async {});
      expect(processor.length, 2);

      processor.clear();
      expect(processor.length, 0);
    });

    test('contains returns false for unknown session', () {
      expect(processor.contains('unknown'), isFalse);
    });
  });
}
