/// Debounce utility functions for rate-limiting function calls.
///
/// Provides custom debounce with optional reducer and advanced debounce
/// with cancel, reset, and flush methods.

import 'dart:async';

/// Options for debounce functions.
class DebounceOptions<T> {
  /// The delay before the function is called
  final Duration delay;

  /// Number of immediate calls before debouncing kicks in (default: 2)
  final int immediateCount;

  /// Optional reducer function to combine pending arguments
  final T Function(T previous, T current)? reducer;

  const DebounceOptions({
    required this.delay,
    this.immediateCount = 2,
    this.reducer,
  });
}

/// Creates a custom debounce function with immediate calls and optional reducer.
///
/// The first [immediateCount] calls execute immediately without debouncing.
/// After that, calls are debounced with the specified delay. If a reducer
/// is provided, pending arguments are combined using it instead of using
/// the latest value.
///
/// Example:
/// ```dart
/// final debounced = createCustomDebounce(
///   (count) => print('Count: $count'),
///   DebounceOptions(delay: Duration(milliseconds: 300)),
/// );
/// ```
void Function(T args) createCustomDebounce<T>(
  void Function(T args) fn,
  DebounceOptions<T> options,
) {
  final delay = options.delay;
  final immediateCount = options.immediateCount;
  final reducer = options.reducer;

  var callCount = 0;
  Timer? timeoutId;
  T? pendingArgs;

  return (T args) {
    // First few calls execute immediately
    if (callCount < immediateCount) {
      callCount++;
      fn(args);
      return;
    }

    // After immediate calls, apply debouncing
    if (pendingArgs != null && reducer != null) {
      // Combine the pending args with new args using the reducer
      pendingArgs = reducer(pendingArgs as T, args);
    } else {
      // Default behavior: use the latest args
      pendingArgs = args;
    }

    // Clear existing timeout
    if (timeoutId != null) {
      timeoutId!.cancel();
    }

    // Set new timeout
    timeoutId = Timer(delay, () {
      if (pendingArgs != null) {
        fn(pendingArgs as T);
        pendingArgs = null;
      }
      timeoutId = null;
    });
  };
}

/// Advanced debounce with cancel, reset, and flush methods.
///
/// Provides full control over the debounced function lifecycle.
class AdvancedDebounce<T> {
  final Duration delay;
  final int immediateCount;
  final T Function(T previous, T current)? reducer;
  final void Function(T args) _fn;

  int _callCount = 0;
  Timer? _timeoutId;
  T? _pendingArgs;

  AdvancedDebounce(
    void Function(T args) fn,
    DebounceOptions<T> options,
  )   : _fn = fn,
        delay = options.delay,
        immediateCount = options.immediateCount,
        reducer = options.reducer;

  /// The debounced function
  void call(T args) {
    // First few calls execute immediately
    if (_callCount < immediateCount) {
      _callCount++;
      _fn(args);
      return;
    }

    // After immediate calls, apply debouncing
    if (_pendingArgs != null && reducer != null) {
      _pendingArgs = reducer!(_pendingArgs!, args);
    } else {
      _pendingArgs = args;
    }

    // Clear existing timeout
    if (_timeoutId != null) {
      _timeoutId!.cancel();
    }

    // Set new timeout
    _timeoutId = Timer(delay, () {
      if (_pendingArgs != null) {
        _fn(_pendingArgs!);
        _pendingArgs = null;
      }
      _timeoutId = null;
    });
  }

  /// Cancel the pending function call
  void cancel() {
    _timeoutId?.cancel();
    _timeoutId = null;
    _pendingArgs = null;
  }

  /// Reset the debounce state (clears pending calls and resets call count)
  void reset() {
    cancel();
    _callCount = 0;
  }

  /// Immediately execute the pending function call if one exists
  void flush() {
    if (_timeoutId != null) {
      _timeoutId!.cancel();
      _timeoutId = null;
    }
    if (_pendingArgs != null) {
      _fn(_pendingArgs!);
      _pendingArgs = null;
    }
  }

  /// Whether a debounced call is currently pending
  bool get isPending => _timeoutId != null;
}

/// Creates an advanced debounce with cancel, reset, and flush methods.
///
/// Returns an [AdvancedDebounce] instance with a `debounced` method.
({void Function(T args) debounced, void Function() cancel, void Function() reset, void Function() flush})
    createAdvancedDebounce<T>(
  void Function(T args) fn,
  DebounceOptions<T> options,
) {
  final debouncer = AdvancedDebounce(fn, options);

  return (
    debounced: (T args) => debouncer.call(args),
    cancel: debouncer.cancel,
    reset: debouncer.reset,
    flush: debouncer.flush,
  );
}
