/// Optimistic mutation primitive for instant UI updates with rollback.
///
/// Applies an optimistic state patch immediately and executes the actual
/// async operation. On failure, the state is rolled back to the snapshot
/// taken before the mutation.
///
/// Usage:
/// ```dart
/// final mutation = OptimisticMutation<Map<String, Session>>(
///   getState: () => state,
///   setState: (s) => state = s,
/// );
///
/// await mutation.run(
///   optimisticUpdate: (current) => {...current}..remove(id),
///   action: () => api.deleteSession(id),
///   onError: (e) => logger.warning('Delete failed: $e'),
/// );
/// ```
library;

import '../services/logger_service.dart' show logger;

/// A callable that reads the current state.
typedef StateReader<T> = T Function();

/// A callable that writes new state.
typedef StateWriter<T> = void Function(T state);

/// Computes an optimistic update from the current state.
typedef OptimisticUpdater<T> = T Function(T current);

/// The actual async operation to perform.
typedef MutationAction = Future<void> Function();

/// Called when the action fails, receiving the error and stack trace.
typedef ErrorHandler = void Function(Object error, StackTrace stackTrace);

/// Manages a single optimistic mutation: apply → act → rollback-on-error.
///
/// [T] is the state type managed by the provider.  The class is intentionally
/// stateless between calls so that the same instance can be reused for
/// multiple independent mutations on the same notifier.
class OptimisticMutation<T> {
  /// Creates an [OptimisticMutation] backed by [getState] and [setState].
  ///
  /// [getState] should return the provider's current state.
  /// [setState] should update the provider's state.
  const OptimisticMutation({
    required StateReader<T> getState,
    required StateWriter<T> setState,
  }) : _getState = getState,
       _setState = setState;

  final StateReader<T> _getState;
  final StateWriter<T> _setState;

  /// Perform an optimistic mutation.
  ///
  /// 1. Captures a snapshot of the current state.
  /// 2. Applies [optimisticUpdate] immediately via [setState].
  /// 3. Awaits [action].
  /// 4. If [action] throws, rolls back to the snapshot and calls [onError].
  ///    The error is also logged at warning level.
  ///
  /// Returns `true` if the action succeeded, `false` if it failed and the
  /// state was rolled back.
  ///
  /// [rollbackWarning] overrides the default warning message while preserving
  /// the failed action's error and stack trace in the log entry.
  Future<bool> run({
    required OptimisticUpdater<T> optimisticUpdate,
    required MutationAction action,
    ErrorHandler? onError,
    String? rollbackWarning,
  }) async {
    final snapshot = _getState();

    // Apply the optimistic patch immediately so the UI responds at once.
    _setState(optimisticUpdate(snapshot));

    try {
      await action();
      return true;
    } catch (error, stackTrace) {
      // Roll back to the pre-mutation snapshot.
      _setState(snapshot);

      logger.warning(
        rollbackWarning ??
            'OptimisticMutation: action failed, rolling back. '
                'Error: $error',
        error,
        stackTrace,
      );

      onError?.call(error, stackTrace);
      return false;
    }
  }
}
