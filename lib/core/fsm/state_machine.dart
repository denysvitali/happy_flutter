/// Explicit finite-state machines for lifecycle code that used to encode
/// its state in loose booleans, nullable timers and scattered `if` checks.
///
/// A [TransitionTable] declares every legal `from → to` edge up front, so the
/// lifecycle is readable in one place and an unexpected edge is a loud,
/// testable event instead of a silent corruption. A [StateMachine] owns the
/// current state and routes every change through the table.
///
/// Illegal transitions throw a [StateError] in debug builds and tests (when
/// assertions are enabled). Release builds log a warning and still apply the
/// change: these machines were extracted from working code, and an
/// unforeseen edge must never strand a user in production.
library;

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../services/logger_service.dart';

/// Immutable `from → {to}` adjacency for a machine over [S].
///
/// Self-transitions are always legal and are no-ops in [StateMachine]; they
/// do not need to be listed.
class TransitionTable<S extends Enum> {
  const TransitionTable(this._edges);

  final Map<S, Set<S>> _edges;

  /// Whether `from → to` is declared (or is a self-transition).
  bool allows(S from, S to) =>
      from == to || (_edges[from]?.contains(to) ?? false);

  /// The states reachable in one step from [from].
  Set<S> targetsOf(S from) => _edges[from] ?? const {};

  /// Whether [state] has no outgoing edges.
  bool isTerminal(S state) => targetsOf(state).isEmpty;
}

/// Thrown (debug/test builds only) for an undeclared transition.
class IllegalTransitionError extends StateError {
  IllegalTransitionError(this.machine, this.from, this.to, [this.reason])
    : super(
        'Illegal $machine transition ${from.name} -> ${to.name}'
        '${reason == null ? '' : ' ($reason)'}',
      );

  final String machine;
  final Enum from;
  final Enum to;
  final String? reason;
}

/// Callback for observing applied transitions (diagnostics, listeners).
typedef TransitionListener<S extends Enum> =
    void Function(S from, S to, String? reason);

/// Current state of a finite-state machine governed by a [TransitionTable].
class StateMachine<S extends Enum> {
  StateMachine({
    required this.name,
    required S initial,
    required TransitionTable<S> table,
    TransitionListener<S>? onTransition,
  }) : _state = initial,
       _table = table,
       _onTransition = onTransition;

  /// Bounded label used in errors and logs. Never include IDs or payloads.
  final String name;
  final TransitionTable<S> _table;
  final TransitionListener<S>? _onTransition;
  S _state;

  /// Overrides the debug-mode throw (tests asserting release behaviour).
  @visibleForTesting
  static bool? throwOnIllegalOverride;

  S get state => _state;

  /// Whether [to] is reachable from the current state in one step.
  bool canTransition(S to) => _table.allows(_state, to);

  /// Moves to [to]. Returns `false` (without notifying) for a
  /// self-transition, `true` when the state changed.
  bool transition(S to, {String? reason}) {
    final from = _state;
    if (from == to) return false;
    if (!_table.allows(from, to)) _reportIllegal(from, to, reason);
    _state = to;
    _onTransition?.call(from, to, reason);
    return true;
  }

  void _reportIllegal(S from, S to, String? reason) {
    var throwIllegal = false;
    assert(() {
      throwIllegal = true;
      return true;
    }());
    throwIllegal = throwOnIllegalOverride ?? throwIllegal;
    final error = IllegalTransitionError(name, from, to, reason);
    if (throwIllegal) throw error;
    logger.warning(error.message);
  }

  @override
  String toString() => 'StateMachine<$name>(${_state.name})';
}
