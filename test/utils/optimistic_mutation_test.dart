import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/optimistic_mutation.dart';

void main() {
  group('OptimisticMutation', () {
    /// Helper that creates a mutation backed by a simple int variable.
    OptimisticMutation<int> _intMutation(
      int Function() getter,
      void Function(int) setter,
    ) {
      return OptimisticMutation<int>(
        getState: getter,
        setState: setter,
      );
    }

    test('applies optimistic update immediately', () async {
      var state = 0;

      final mutation = _intMutation(() => state, (s) => state = s);

      // Action never completes synchronously — just check state after patch.
      final future = mutation.run(
        optimisticUpdate: (current) => current + 10,
        action: () async {},
      );

      // After run() returns the state should be updated.
      await future;
      expect(state, 10);
    });

    test('returns true on success', () async {
      var state = 1;

      final mutation = _intMutation(() => state, (s) => state = s);
      final result = await mutation.run(
        optimisticUpdate: (current) => current * 2,
        action: () async {},
      );

      expect(result, isTrue);
      expect(state, 2);
    });

    test('rolls back state on failure', () async {
      var state = 42;

      final mutation = _intMutation(() => state, (s) => state = s);
      final result = await mutation.run(
        optimisticUpdate: (current) => 999,
        action: () async => throw Exception('server error'),
      );

      expect(result, isFalse);
      // State should be rolled back to the original value.
      expect(state, 42);
    });

    test('calls onError with the error on failure', () async {
      var state = 0;
      Object? capturedError;

      final mutation = _intMutation(() => state, (s) => state = s);
      await mutation.run(
        optimisticUpdate: (current) => current + 1,
        action: () async => throw Exception('boom'),
        onError: (e, _) => capturedError = e,
      );

      expect(capturedError, isA<Exception>());
      expect(capturedError.toString(), contains('boom'));
    });

    test('does not call onError on success', () async {
      var state = 5;
      var errorCalled = false;

      final mutation = _intMutation(() => state, (s) => state = s);
      await mutation.run(
        optimisticUpdate: (current) => current + 1,
        action: () async {},
        onError: (_, __) => errorCalled = true,
      );

      expect(errorCalled, isFalse);
      expect(state, 6);
    });

    test('works with Map state type', () async {
      var mapState = <String, int>{'a': 1, 'b': 2};

      final mutation = OptimisticMutation<Map<String, int>>(
        getState: () => mapState,
        setState: (s) => mapState = s,
      );

      final result = await mutation.run(
        optimisticUpdate: (current) {
          final updated = Map<String, int>.from(current);
          updated.remove('a');
          return updated;
        },
        action: () async {},
      );

      expect(result, isTrue);
      expect(mapState, {'b': 2});
    });

    test('restores Map state on failure', () async {
      final original = <String, int>{'x': 10, 'y': 20};
      var mapState = Map<String, int>.from(original);

      final mutation = OptimisticMutation<Map<String, int>>(
        getState: () => mapState,
        setState: (s) => mapState = s,
      );

      await mutation.run(
        optimisticUpdate: (current) {
          final updated = Map<String, int>.from(current);
          updated.remove('x');
          return updated;
        },
        action: () async => throw Exception('network error'),
      );

      expect(mapState, original);
    });

    test('can be reused for multiple independent mutations', () async {
      var state = 100;

      final mutation = _intMutation(() => state, (s) => state = s);

      // First mutation succeeds.
      await mutation.run(
        optimisticUpdate: (c) => c + 5,
        action: () async {},
      );
      expect(state, 105);

      // Second mutation fails — rolls back to 105.
      await mutation.run(
        optimisticUpdate: (c) => c * 2,
        action: () async => throw Exception('fail'),
      );
      expect(state, 105);

      // Third mutation succeeds again.
      await mutation.run(
        optimisticUpdate: (c) => c - 5,
        action: () async {},
      );
      expect(state, 100);
    });

    test('snapshot is taken before optimistic update', () async {
      var state = 7;
      int? snapshotAtRollback;

      final mutation = _intMutation(() => state, (s) => state = s);
      await mutation.run(
        optimisticUpdate: (c) => c + 1,
        action: () async => throw Exception('oops'),
        onError: (_, __) {
          // At the time onError fires, rollback has already happened.
          snapshotAtRollback = state;
        },
      );

      // Rollback should restore the original 7.
      expect(snapshotAtRollback, 7);
      expect(state, 7);
    });
  });
}
