/// Tiny self-contained property-runner used by the messaging contract
/// tests.  Avoids pulling in `dart:test`-incompatible packages so we
/// can run inside the existing `flutter test` infrastructure.
///
/// Why hand-rolled?
///
/// Two reasons:
///
/// 1. Existing Dart property-testing libraries (`glados`, `dart_check`)
///    have not been added to `pubspec.yaml`, and the architecture
///    branch is also touching the same files — keeping the dep graph
///    untouched avoids merge pain.
/// 2. The property under test is a small command grammar.  A 60-line
///    runner is enough to find scheduling counterexamples; we don't
///    need quickcheck-grade machinery.
///
/// The runner generates `n` random programs with a fixed seed, applies
/// them to the [MessagingModel], and runs a list of invariant checks
/// after every command.  When any invariant fails it shrinks the
/// failing program by binary-searching prefixes until the smallest
/// failing trace is found, then reports it.
import 'dart:math';

import 'messaging_commands.dart';

typedef InvariantCheck = void Function(MessagingModel model, List<MessagingCommand> trace);

class PropertyResult {
  PropertyResult({
    required this.passed,
    this.failingTrace,
    this.failureMessage,
  });
  final bool passed;
  final List<MessagingCommand>? failingTrace;
  final String? failureMessage;
}

class PropertyRunner {
  PropertyRunner({
    required this.checks,
    required this.generate,
    this.runs = 100,
    this.maxLength = 30,
    this.seed = 0xC0FFEE,
  });

  final List<InvariantCheck> checks;
  final List<MessagingCommand> Function(Random rng, int length) generate;
  final int runs;
  final int maxLength;
  final int seed;

  /// Run the property.  Returns a passing result, or a shrunk failing
  /// counterexample.
  PropertyResult run() {
    final rng = Random(seed);
    for (var i = 0; i < runs; i++) {
      final length = 1 + rng.nextInt(maxLength);
      final program = generate(rng, length);
      final result = _evaluate(program);
      if (!result.passed) {
        // Shrink: find the shortest prefix that still fails.
        final shrunk = _shrink(program);
        return PropertyResult(
          passed: false,
          failingTrace: shrunk,
          failureMessage: _evaluate(shrunk).failureMessage,
        );
      }
    }
    return PropertyResult(passed: true);
  }

  PropertyResult _evaluate(List<MessagingCommand> program) {
    final model = MessagingModel(seed: seed);
    for (final cmd in program) {
      model.apply(cmd);
      for (final check in checks) {
        try {
          check(model, program);
        } catch (e) {
          return PropertyResult(
            passed: false,
            failingTrace: program,
            failureMessage: '$e (after ${program.indexOf(cmd) + 1} cmds)',
          );
        }
      }
    }
    return PropertyResult(passed: true);
  }

  /// Greedy shrinker: removes one command at a time as long as the
  /// trace still fails.  Cheap and sufficient for the small command
  /// grammar.
  List<MessagingCommand> _shrink(List<MessagingCommand> program) {
    var current = List<MessagingCommand>.of(program);
    var changed = true;
    while (changed) {
      changed = false;
      for (var i = 0; i < current.length; i++) {
        final candidate = List<MessagingCommand>.of(current)..removeAt(i);
        if (candidate.isEmpty) continue;
        if (!_evaluate(candidate).passed) {
          current = candidate;
          changed = true;
          break;
        }
      }
    }
    return current;
  }
}
