import 'dart:io';
import 'dart:math' as math;

/// Dependency-free micro/macro benchmark harness for happy_flutter.
///
/// Runs scenarios inside `flutter test` (JIT VM), records per-iteration
/// wall-clock samples, and emits machine-parseable result lines:
///
/// ```
/// BENCH|<group>|<name>|<ops_per_iter>|<iterations>|
///      <mean_ms>|<p50_ms>|<p90_ms>|<p99_ms>|<ops_per_s>
/// ```
///
/// The CI job (`.github/workflows/ci.yml` → `benchmarks`) parses those
/// lines into a step-summary table and uploads them as an artifact.
/// Numbers are JIT-mode relative indicators for spotting hot spots and
/// regressions between commits, not absolute production (AOT) latencies.
class BenchReporter {
  BenchReporter({required this.group});

  /// Group label shared by every scenario in one reporter (e.g. 'pipeline').
  final String group;

  final List<_BenchResult> _results = <_BenchResult>[];

  /// Times [body] over [iterations] runs after [warmup] untimed runs.
  /// When one iteration performs [opsPerIteration] logical operations,
  /// per-op throughput is derived from it.
  Future<void> measure(
    String name,
    Future<void> Function() body, {
    required int iterations,
    int warmup = 2,
    int opsPerIteration = 1,
  }) {
    return measureTimed(
      name,
      () async {
        final watch = Stopwatch()..start();
        await body();
        watch.stop();
        return watch.elapsedMicroseconds / 1000.0;
      },
      iterations: iterations,
      warmup: warmup,
      opsPerIteration: opsPerIteration,
    );
  }

  /// Like [measure], but [body] performs its own timing and returns the
  /// elapsed milliseconds — use when only part of the iteration should be
  /// counted (e.g. setup and settle-waits excluded).
  Future<void> measureTimed(
    String name,
    Future<double> Function() body, {
    required int iterations,
    int warmup = 2,
    int opsPerIteration = 1,
  }) async {
    for (var i = 0; i < warmup; i++) {
      await body();
    }
    final samples = List<double>.filled(iterations, 0);
    for (var i = 0; i < iterations; i++) {
      samples[i] = await body();
    }
    _results.add(_BenchResult(
      name: name,
      samplesMs: samples,
      opsPerIteration: opsPerIteration,
    ));
  }

  /// Synchronous variant of [measure] for CPU-bound bodies.
  void measureSync(
    String name,
    void Function() body, {
    required int iterations,
    int warmup = 2,
    int opsPerIteration = 1,
  }) {
    for (var i = 0; i < warmup; i++) {
      body();
    }
    final samples = List<double>.filled(iterations, 0);
    final watch = Stopwatch();
    for (var i = 0; i < iterations; i++) {
      watch
        ..reset()
        ..start();
      body();
      watch.stop();
      samples[i] = watch.elapsedMicroseconds / 1000.0;
    }
    _results.add(_BenchResult(
      name: name,
      samplesMs: samples,
      opsPerIteration: opsPerIteration,
    ));
  }

  /// Emits one machine line per result plus a human-readable table.
  /// Call exactly once at the end of the benchmark test file.
  void finish() {
    final out = stdout.writeln;
    out('');
    out('== $group ==');
    const nameWidth = 44;
    out(
      _pad('scenario', nameWidth) +
          _padLeft('mean', 9) +
          _padLeft('p50', 9) +
          _padLeft('p90', 9) +
          _padLeft('p99', 9),
    );
    for (final r in _results) {
      out(
        _pad(r.name, nameWidth) +
            _padLeft(r.meanMs().toStringAsFixed(3), 9) +
            _padLeft(r.percentile(0.5).toStringAsFixed(3), 9) +
            _padLeft(r.percentile(0.9).toStringAsFixed(3), 9) +
            _padLeft(r.percentile(0.99).toStringAsFixed(3), 9),
      );
    }
    out('');
    for (final r in _results) {
      out(r.machineLine(group));
    }
    _results.clear();
  }
}

class _BenchResult {
  _BenchResult({
    required this.name,
    required this.samplesMs,
    required this.opsPerIteration,
  });

  final String name;
  final List<double> samplesMs;
  final int opsPerIteration;

  double meanMs() {
    var sum = 0.0;
    for (final s in samplesMs) {
      sum += s;
    }
    return sum / samplesMs.length;
  }

  double percentile(double p) {
    final sorted = List<double>.of(samplesMs)..sort();
    final idx = math.min(
      sorted.length - 1,
      (p * (sorted.length - 1)).round(),
    );
    return sorted[idx];
  }

  String machineLine(String group) {
    final mean = meanMs();
    final opsPerSec = opsPerIteration * 1000.0 / mean;
    return [
      'BENCH',
      group,
      name,
      '$opsPerIteration',
      '${samplesMs.length}',
      mean.toStringAsFixed(3),
      percentile(0.5).toStringAsFixed(3),
      percentile(0.9).toStringAsFixed(3),
      percentile(0.99).toStringAsFixed(3),
      opsPerSec.toStringAsFixed(1),
    ].join('|');
  }
}

String _pad(String s, int width) {
  if (s.length >= width) return s;
  return s + ' ' * (width - s.length);
}

String _padLeft(String s, int width) {
  if (s.length >= width) return s;
  return ' ' * (width - s.length) + s;
}
