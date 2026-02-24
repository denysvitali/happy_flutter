import 'dart:async';

/// AsyncLock is a promise-based mutex/locking mechanism for async operations.
/// It provides a queue system for handling multiple waiting lock requests.
class AsyncLock {
  int _permits = 1;
  final List<Completer<bool>> _promiseResolverQueue = [];

  /// Executes a function within a lock, ensuring only one operation
  /// runs at a time. Returns the result of the function.
  Future<T> inLock<T>(Future<T> Function() func) async {
    try {
      await lock();
      return await func();
    } finally {
      unlock();
    }
  }

  Future<void> lock() async {
    if (_permits > 0) {
      _permits = _permits - 1;
      return;
    }
    final completer = Completer<bool>();
    _promiseResolverQueue.add(completer);
    await completer.future;
  }

  void unlock() {
    _permits += 1;
    if (_permits > 1 && _promiseResolverQueue.isNotEmpty) {
      throw StateError(
          'this.permits should never be > 0 when there is someone waiting.');
    } else if (_permits == 1 && _promiseResolverQueue.isNotEmpty) {
      // If there is someone else waiting, immediately consume the permit that
      // was released at the beginning of this function and let it resume.
      _permits -= 1;

      final nextResolver = _promiseResolverQueue.removeAt(0);
      // Resolve on the next tick
      Future.microtask(() {
        nextResolver.complete(true);
      });
    }
  }
}
