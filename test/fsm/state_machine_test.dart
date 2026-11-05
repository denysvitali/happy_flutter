import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/fsm/state_machine.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

enum _S { a, b, c }

const _table = TransitionTable<_S>({
  _S.a: {_S.b},
  _S.b: {_S.c},
  _S.c: {},
});

void main() {
  tearDown(() => StateMachine.throwOnIllegalOverride = null);

  test('legal transitions notify; self-transitions are silent no-ops', () {
    final seen = <String>[];
    final m = StateMachine<_S>(
      name: 'test',
      initial: _S.a,
      table: _table,
      onTransition: (from, to, reason) =>
          seen.add('${from.name}>${to.name}:$reason'),
    );

    expect(m.transition(_S.a), isFalse);
    expect(m.transition(_S.b, reason: 'go'), isTrue);
    expect(m.state, _S.b);
    expect(seen, ['a>b:go']);
    expect(_table.isTerminal(_S.c), isTrue);
  });

  test('illegal transitions throw in debug/test builds', () {
    final m = StateMachine<_S>(name: 'test', initial: _S.a, table: _table);

    expect(() => m.transition(_S.c), throwsA(isA<IllegalTransitionError>()));
  });

  test('illegal transitions still apply when throwing is disabled', () {
    StateMachine.throwOnIllegalOverride = false;
    final m = StateMachine<_S>(name: 'test', initial: _S.a, table: _table);

    expect(m.transition(_S.c), isTrue);
    expect(m.state, _S.c);
  });

  test('InvalidateSync phase table: disposed is terminal', () {
    expect(
      invalidateSyncTransitions.isTerminal(InvalidateSyncPhase.disposed),
      isTrue,
    );
    for (final phase in InvalidateSyncPhase.values) {
      expect(
        invalidateSyncTransitions.allows(phase, InvalidateSyncPhase.disposed),
        isTrue,
        reason: '${phase.name} must be disposable',
      );
    }
  });
}
