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

  group('InlineMessageProcessor.enqueueBatch coalescing', () {
    test(
      'items enqueued in one synchronous burst drain as ONE list '
      'in arrival order',
      () async {
      final calls = <List<String>>[];
      processor.enqueueBatch<String>(
        's1',
        'a',
        (items) async => calls.add(items),
      );
      processor.enqueueBatch<String>(
        's1',
        'b',
        (items) async => calls.add(items),
      );
      processor.enqueueBatch<String>(
        's1',
        'c',
        (items) async => calls.add(items),
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // One drain consumed all three buffered items in FIFO order.
      expect(calls, [
        ['a', 'b', 'c'],
      ]);
      expect(processor.contains('s1'), isFalse);
    });

    test(
      'items arriving during a drain land in a follow-up drain, '
      'still in arrival order',
      () async {
      final calls = <List<String>>[];
      var firstDrainStarted = false;
      final gate = Completer<void>();

      Future<void> process(List<String> items) async {
        calls.add(items);
        if (!firstDrainStarted) {
          firstDrainStarted = true;
          await gate.future;
        }
      }

      processor.enqueueBatch<String>('s1', 'a', process);
      // Yield so the first drain starts and suspends inside `process`.
      await Future<void>.delayed(Duration.zero);
      expect(firstDrainStarted, isTrue);

      // Arrive while the first drain is still awaiting.
      processor.enqueueBatch<String>('s1', 'b', process);
      processor.enqueueBatch<String>('s1', 'c', process);
      // Nothing may run concurrently for this session.
      expect(calls.length, 1);

      gate.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(calls, [
        ['a'],
        ['b', 'c'],
      ]);
      expect(processor.contains('s1'), isFalse);
    });

    test(
      'an item arriving just before the queue entry is removed is not '
      'stranded',
      () async {
      final calls = <List<String>>[];
      Future<void> process(List<String> items) async {
        calls.add(items);
      }

      // First drain consumes 'a'; while its follow-up loop iterations
      // are pending, 'b' arrives and must be drained too.
      processor.enqueueBatch<String>('s1', 'a', process);
      await Future<void>.delayed(Duration.zero);
      processor.enqueueBatch<String>('s1', 'b', process);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(calls, [
        ['a'],
        ['b'],
      ]);
      expect(processor.contains('s1'), isFalse);
    });

    test('a throwing process call does not strand later items', () async {
      final calls = <List<String>>[];
      Future<void> process(List<String> items) async {
        if (calls.isEmpty) {
          calls.add(items);
          throw Exception('boom');
        }
        calls.add(items);
      }

      processor.enqueueBatch<String>('s1', 'a', process);
      await Future<void>.delayed(Duration.zero);
      processor.enqueueBatch<String>('s1', 'b', process);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(calls, [
        ['a'],
        ['b'],
      ]);
    });

    test('clearSession discards buffered-but-unstarted items', () async {
      final calls = <List<String>>[];
      final started = Completer<void>();
      Future<void> process(List<String> items) async {
        calls.add(items);
        await started.future;
      }

      processor.enqueueBatch<String>('s1', 'a', process);
      await Future<void>.delayed(Duration.zero);
      // Buffered while the first batch is mid-flight.
      processor.enqueueBatch<String>('s1', 'b', process);

      processor.clearSession('s1');
      started.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(calls, [
        ['a'],
      ]);
    });

    test('sessions drain concurrently and independently', () async {
      final order = <String>[];
      final c1 = Completer<void>();
      final c2 = Completer<void>();

      Future<void> s1Process(List<String> _) async {
        await c1.future;
        order.add('s1');
      }

      Future<void> s2Process(List<String> _) async {
        await c2.future;
        order.add('s2');
      }

      processor.enqueueBatch<String>('s1', 'a', s1Process);
      processor.enqueueBatch<String>('s2', 'x', s2Process);
      await Future<void>.delayed(Duration.zero);

      c2.complete();
      await Future<void>.delayed(Duration.zero);
      expect(order, ['s2']);

      c1.complete();
      await Future<void>.delayed(Duration.zero);
      expect(order, ['s2', 's1']);
    });
  });
}
