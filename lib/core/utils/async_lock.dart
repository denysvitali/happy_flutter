/// AsyncLock class for mutual exclusion pattern.
///
/// Provides a mutex-like mechanism for serializing access to shared resources
/// in asynchronous code.

/// AsyncLock - A mutex implementation for Dart async operations.
///
/// Allows only one operation to proceed at a time within [inLock].
/// Uses a permit-based system where acquiring a permit blocks until one is available.
///
/// Example:
/// ```dart
/// final lock = AsyncLock();
///
/// Future<void> safeOperation() async {
///   await lock.inLock(() async {
///     // Only one execution can be here at a time
///     await _sharedResource.write(data);
///   });
/// }
/// ```
class AsyncLock {
  int _permits = 1;
  final List<Completer<bool>> _promiseResolverQueue = [];

  /// Execute a function with exclusive access to the lock.
  ///
  /// The function will be called when the lock is acquired.
  /// The lock is automatically released after the function completes,
  /// even if it throws an exception.
  ///
  /// [func] - The async or sync function to execute
  ///
  /// Returns the result of the function
  Future<T> inLock<T>(Future<T> Function() func) async {
    try {
      await _lock();
      return await func();
    } finally {
      _unlock();
    }
  }

  Future<void> _lock() async {
    if (_permits > 0) {
      _permits = _permits - 1;
      return;
    }
    final completer = Completer<bool>();
    _promiseResolverQueue.add(completer);
    await completer.future;
  }

  void _unlock() {
    _permits += 1;
    if (_permits > 1 && _promiseResolverQueue.isNotEmpty) {
      throw StateError(
        'permits should never be > 0 when there is someone waiting.',
      );
    } else if (_permits == 1 && _promiseResolverQueue.isNotEmpty) {
      // If there is someone else waiting, immediately consume the permit that was released
      // at the beginning of this function and let the waiting function resume.
      _permits -= 1;

      final nextResolver = _promiseResolverQueue.shift();
      // Resolve on the next tick
      if (nextResolver != null) {
        Future.value(nextResolver(true));
      }
    }
  }

  /// Whether the lock is currently available (no pending waiters)
  bool get isAvailable => _permits > 0;

  /// Number of available permits
  int get availablePermits => _permits;

  /// Number of waiting operations
  int get waitingCount => _promiseResolverQueue.length;
}

/// A simpler async mutex that uses a single Future as a lock.
///
/// This is a simpler implementation that uses a Future as a semaphore.
/// It's easier to understand but may have different performance characteristics
/// for high-contention scenarios.
class SimpleAsyncLock {
  Future<void>? _currentLock;
  final _completer = Completer<void>();

  SimpleAsyncLock() {
    _currentLock = _completer.future;
  }

  /// Execute a function with exclusive access.
  Future<T> withLock<T>(Future<T> Function() func) async {
    final previousLock = _currentLock;
    final thisLock = Completer<void>();

    _currentLock = thisLock.future;

    try {
      await previousLock;
      return await func();
    } finally {
      thisLock.complete();
    }
  }

  /// Whether the lock is currently free
  bool get isFree => !_completer.isCompleted;
}
