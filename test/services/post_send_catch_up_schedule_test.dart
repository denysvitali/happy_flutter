// Pins the post-send catch-up poll schedule.
//
// 34% of catch-up polls (37/108 in 24h) used to end on the old 30 s
// budget without ever seeing the agent's reply — an agent that thinks
// for more than half a minute is entirely ordinary. The budget now
// covers the realistic thinking window, and the interval widens so the
// longer budget does not multiply fetch load.
//
// This suite deliberately asserts the *shape* of the schedule (budget,
// escalation, probe count) rather than message ordering: the poller only
// invalidates the per-session message sync, so it can never reorder
// messages.

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('post-send catch-up schedule', () {
    late Sync instance;

    setUp(() {
      instance = createTestSync();
    });

    test('budget outlasts a typical agent think time', () {
      expect(
        instance.testPostSendCatchUpBudget,
        greaterThanOrEqualTo(const Duration(seconds: 60)),
        reason: 'a 30s budget expired before the reply in 34% of polls',
      );
    });

    test('interval starts tight then widens', () {
      expect(
        instance.testPostSendCatchUpInterval(1),
        const Duration(seconds: 10),
      );
      expect(
        instance.testPostSendCatchUpInterval(2),
        const Duration(seconds: 10),
      );
      expect(
        instance.testPostSendCatchUpInterval(3),
        const Duration(seconds: 15),
      );
      expect(
        instance.testPostSendCatchUpInterval(4),
        const Duration(seconds: 20),
      );
      expect(
        instance.testPostSendCatchUpInterval(9),
        const Duration(seconds: 20),
        reason: 'the cadence must plateau, not keep growing',
      );
    });

    test('interval never regresses as probes accumulate', () {
      var previous = Duration.zero;
      for (var i = 1; i <= 12; i++) {
        final interval = instance.testPostSendCatchUpInterval(i);
        expect(interval, greaterThanOrEqualTo(previous));
        previous = interval;
      }
    });

    test('the schedule fits a bounded number of probes in the budget', () {
      var elapsed = Duration.zero;
      var probes = 1; // the immediate probe that starts the cycle
      while (true) {
        final next = elapsed + instance.testPostSendCatchUpInterval(probes);
        if (next > instance.testPostSendCatchUpBudget) break;
        elapsed = next;
        probes++;
      }
      expect(
        probes,
        inInclusiveRange(5, 8),
        reason: 'a 90s budget at a widening cadence should cost roughly '
            'twice the probes of the old 30s/10s window, not six times',
      );
    });
  });
}
