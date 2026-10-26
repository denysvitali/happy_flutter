import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/process_cpu_sampler.dart';

void main() {
  test(
    'CPU uses elapsed time, permits multiple cores, and resets on resume',
    () {
      var cpu = const Duration(seconds: 3);
      var elapsed = const Duration(seconds: 10);
      final sampler = ProcessCpuSampler(
        readCpuTime: () => cpu,
        readElapsed: () => elapsed,
      )..reset();

      cpu += const Duration(milliseconds: 375);
      elapsed += const Duration(seconds: 3);
      expect(sampler.sample(), (
        cpuTime: const Duration(milliseconds: 375),
        utilization: 12.5,
      ));

      cpu += const Duration(seconds: 5);
      elapsed += const Duration(seconds: 2);
      expect(sampler.sample()!.utilization, 250);

      // Work performed while suspended must not leak into foreground usage.
      cpu += const Duration(seconds: 30);
      elapsed += const Duration(minutes: 10);
      sampler.reset();
      elapsed += const Duration(seconds: 4);
      expect(sampler.sample(), (cpuTime: Duration.zero, utilization: 0.0));
    },
  );

  test('unsupported and reset counters are omitted, not reported as idle', () {
    Duration? cpu;
    var elapsed = Duration.zero;
    final sampler = ProcessCpuSampler(
      readCpuTime: () => cpu,
      readElapsed: () => elapsed,
    )..reset();
    elapsed += const Duration(seconds: 1);
    expect(sampler.sample(), isNull);
    cpu = const Duration(seconds: 10);
    elapsed += const Duration(seconds: 1);
    expect(sampler.sample(), isNull);
    cpu = Duration.zero;
    elapsed += const Duration(seconds: 1);
    expect(sampler.sample(), isNull);
    expect(sampler.sample(), isNull, reason: 'no elapsed time');
    cpu = const Duration(milliseconds: 100);
    elapsed += const Duration(seconds: 2);
    expect(sampler.sample()!.utilization, 5);
  });
}
