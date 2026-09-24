import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/bounded_concurrency.dart';

void main() {
  test('runs every item', () async {
    final seen = <int>[];
    await forEachBatched(
      [1, 2, 3, 4, 5],
      2,
      (item) async => seen.add(item),
    );
    expect(seen, [1, 2, 3, 4, 5]);
  });

  test('never exceeds the concurrency cap', () async {
    var live = 0;
    var peak = 0;
    final items = List<int>.generate(50, (i) => i);

    await forEachBatched(items, 4, (item) async {
      live++;
      peak = peak > live ? peak : live;
      // Yield so overlapping work is actually observable.
      await Future<void>.delayed(Duration.zero);
      live--;
    });

    expect(peak, lessThanOrEqualTo(4));
    expect(peak, greaterThan(1), reason: 'should actually run in parallel');
  });

  test('handles an empty collection', () async {
    var calls = 0;
    await forEachBatched(<int>[], 4, (item) async => calls++);
    expect(calls, 0);
  });

  test('handles a trailing partial batch', () async {
    final seen = <int>[];
    // 7 items at concurrency 3 -> batches of 3, 3, 1.
    await forEachBatched(
      List<int>.generate(7, (i) => i),
      3,
      (item) async => seen.add(item),
    );
    expect(seen, [0, 1, 2, 3, 4, 5, 6]);
  });

  test('concurrency of 1 runs strictly in order', () async {
    final seen = <int>[];
    await forEachBatched(
      [1, 2, 3],
      1,
      (item) async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        seen.add(item);
      },
    );
    expect(seen, [1, 2, 3]);
  });

  test('rejects a non-positive concurrency', () {
    expect(
      () => forEachBatched([1], 0, (item) async {}),
      throwsArgumentError,
    );
  });

  test('surfaces the first error and stops scheduling', () async {
    final started = <int>[];
    await expectLater(
      forEachBatched(
        List<int>.generate(20, (i) => i),
        2,
        (item) async {
          started.add(item);
          if (item == 1) throw StateError('boom');
        },
      ),
      throwsStateError,
    );
    // The failing batch rejects; later items are never scheduled.
    expect(started.length, lessThan(20));
  });
}
