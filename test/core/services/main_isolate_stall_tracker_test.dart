import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/main_isolate_stall_tracker.dart';

void main() {
  final tracker = MainIsolateStallTracker.instance;

  tearDown(tracker.reset);

  test('track records work long enough to delay a frame', () {
    var now = 0;
    tracker.clock = () => now;

    final result = tracker.track('slow', () {
      now += 50000;
      return 42;
    });
    tracker.track('fast', () => now += 1000);

    expect(result, 42);
    expect(tracker.blockerBetween(0, 60000), 'slow');
    expect(tracker.blockerBetween(50000, 51000), isNull);
  });

  test('track records work that throws', () {
    var now = 0;
    tracker.clock = () => now;

    expect(
      () => tracker.track<void>('throws', () {
        now += 20000;
        throw StateError('boom');
      }),
      throwsStateError,
    );
    expect(tracker.blockerBetween(0, 20000), 'throws');
  });

  test('blockerBetween picks the largest overlap', () {
    tracker
      ..record('a', 0, 20000)
      ..record('b', 20000, 120000);

    expect(tracker.blockerBetween(10000, 110000), 'b');
    expect(tracker.blockerBetween(200000, 300000), isNull);
    expect(tracker.blockerBetween(10, 10), isNull);
  });

  test('keeps a bounded history', () {
    for (var i = 0; i < 40; i++) {
      tracker.record('w$i', i * 100000, i * 100000 + 10000);
    }

    expect(tracker.blockerBetween(0, 10000), isNull);
    expect(tracker.blockerBetween(3900000, 3910000), 'w39');
  });
}
