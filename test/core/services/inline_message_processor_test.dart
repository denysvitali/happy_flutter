import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/inline_message_processor.dart';

void main() {
  test('queue drains after a task with an early return', () async {
    final processor = InlineMessageProcessor();

    processor.enqueue('session-1', () async {
      return;
    });

    await Future<void>.delayed(Duration.zero);

    expect(processor.contains('session-1'), isFalse);
  });

  test('tasks for the same session run in order', () async {
    final processor = InlineMessageProcessor();
    final order = <int>[];

    processor
      ..enqueue('session-1', () async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        order.add(1);
      })
      ..enqueue('session-1', () async {
        order.add(2);
      });

    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(order, [1, 2]);
    expect(processor.contains('session-1'), isFalse);
  });
}
