/// Runs [action] for every item, with at most [concurrency] running at once.
///
/// Awaiting `Future.wait` over an unbounded collection starts one task per
/// item simultaneously. That is the wrong shape for work that crosses an
/// isolate boundary: each item triggers an FFI round-trip (and for AES batches,
/// an `Isolate.run`), so a catalog of a few hundred sessions turns one logical
/// batch into a few hundred concurrent isolate opens — slower than a small
/// bounded fan-out, and a memory spike on low-end devices.
///
/// This keeps the useful property of `Future.wait` (the wait costs the slowest
/// batch, not the sum) while capping how many are live at once. Order is
/// preserved: items run in iteration order, [concurrency] at a time.
Future<void> forEachBatched<T>(
  Iterable<T> items,
  int concurrency,
  Future<void> Function(T item) action,
) async {
  if (concurrency < 1) {
    throw ArgumentError.value(
      concurrency,
      'concurrency',
      'must be at least 1',
    );
  }
  var pending = <Future<void>>[];
  for (final item in items) {
    pending.add(action(item));
    if (pending.length < concurrency) continue;
    await Future.wait(pending);
    pending = <Future<void>>[];
  }
  if (pending.isNotEmpty) {
    await Future.wait(pending);
  }
}
