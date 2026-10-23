import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/utils.dart' show formatRelativeTime;
import 'package:happy_flutter/features/sessions/widgets/mission_heartbeat.dart';

/// Freshness is the heartbeat of the focus queue: one decaying glow per
/// stream, quantized so no row needs its own animation controller.
void main() {
  final now = DateTime.now().millisecondsSinceEpoch;
  const minute = 60 * 1000;

  for (final age in [
    const Duration(minutes: 5),
    const Duration(hours: 2),
    const Duration(days: 2),
  ]) {
    testWidgets('static age $age wakes only at its label boundary', (
      tester,
    ) async {
      final start = tester.binding.clock.now();
      final timestamp = start.subtract(age);
      var builds = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MissionClock(
            live: false,
            relativeTimestamps: [timestamp.millisecondsSinceEpoch],
            now: tester.binding.clock.now,
            child: Builder(
              builder: (context) {
                builds++;
                return Text(
                  formatRelativeTime(
                    timestamp,
                    now: DateTime.fromMillisecondsSinceEpoch(
                      missionNowOf(context),
                    ),
                    compact: true,
                  ),
                );
              },
            ),
          ),
        ),
      );
      final cadence = age.inDays > 0
          ? const Duration(days: 1)
          : age.inHours > 0
          ? const Duration(hours: 1)
          : const Duration(minutes: 1);
      final initial = formatRelativeTime(timestamp, now: start, compact: true);
      expect(find.text(initial), findsOneWidget);
      await tester.pump(cadence - const Duration(milliseconds: 1));
      expect(builds, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(builds, 2);
      expect(
        find.text(
          formatRelativeTime(timestamp, now: start.add(cadence), compact: true),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('new timestamps replace the static clock deadline', (
    tester,
  ) async {
    var builds = 0;
    final probe = Builder(
      builder: (context) {
        builds++;
        return Text('${missionNowOf(context)}');
      },
    );
    Future<void> pump(int timestamp) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MissionClock(
          live: false,
          relativeTimestamps: [timestamp],
          now: tester.binding.clock.now,
          child: probe,
        ),
      ),
    );
    await pump(tester.binding.clock.now().millisecondsSinceEpoch - 300000);
    await tester.pump(const Duration(seconds: 15));
    expect(builds, 1);
    final now = tester.binding.clock.now().millisecondsSinceEpoch;
    await pump(now - 59000);
    expect(find.text('$now'), findsOneWidget);
    final updated = builds;
    await tester.pump(const Duration(milliseconds: 999));
    expect(builds, updated);
    await tester.pump(const Duration(milliseconds: 1));
    expect(builds, updated + 1);
    expect(find.text('${now + 1000}'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'future clock skew wakes when the absolute label becomes relative',
    (tester) async {
      final future = tester.binding.clock.now().add(
        const Duration(seconds: 61),
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MissionClock(
            live: false,
            relativeTimestamps: [future.millisecondsSinceEpoch],
            now: tester.binding.clock.now,
            child: Builder(
              builder: (context) => Text(
                formatRelativeTime(
                  future,
                  now: DateTime.fromMillisecondsSinceEpoch(
                    missionNowOf(context),
                  ),
                  compact: true,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Just now'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Just now'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Just now'), findsOneWidget);
      await tester.pump(const Duration(seconds: 120));
      expect(find.text('1m'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('clock respects visibility and refreshes on reactivation', (
    tester,
  ) async {
    final start = tester.binding.clock.now();
    var builds = 0;
    final probe = Builder(
      builder: (context) {
        builds++;
        return Text('${missionNowOf(context)}');
      },
    );
    Future<void> pump({bool active = true, bool visible = true}) =>
        tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: TickerMode(
              enabled: visible,
              child: MissionClock(
                active: active,
                now: tester.binding.clock.now,
                child: probe,
              ),
            ),
          ),
        );
    await pump();
    await tester.pump(const Duration(seconds: 15));
    expect(builds, 2);
    await pump(visible: false);
    final paused = builds;
    await tester.pump(const Duration(minutes: 3));
    expect(builds, paused);
    await pump();
    expect(
      find.text(
        '${start.add(const Duration(seconds: 195)).millisecondsSinceEpoch}',
      ),
      findsOneWidget,
    );
    await pump(active: false);
    final inactive = builds;
    await tester.pump(const Duration(minutes: 2));
    expect(builds, inactive);
    await pump();
    expect(
      find.text(
        '${start.add(const Duration(seconds: 315)).millisecondsSinceEpoch}',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  group('streamFreshness', () {
    test('burst within the first 45 seconds', () {
      expect(
        streamFreshness(
          nowMs: now,
          lastActivityAt: now - 44 * 1000,
          live: true,
        ),
        StreamFreshness.burst,
      );
      expect(
        streamFreshness(
          nowMs: now,
          lastActivityAt: now - 45 * 1000,
          live: true,
        ),
        StreamFreshness.burst,
      );
    });

    test('fresh until three minutes', () {
      expect(
        streamFreshness(
          nowMs: now,
          lastActivityAt: now - 46 * 1000,
          live: true,
        ),
        StreamFreshness.fresh,
      );
      expect(
        streamFreshness(
          nowMs: now,
          lastActivityAt: now - 3 * minute,
          live: true,
        ),
        StreamFreshness.fresh,
      );
    });

    test('aging past the fresh window', () {
      expect(
        streamFreshness(
          nowMs: now,
          lastActivityAt: now - 3 * minute - 1,
          live: false,
        ),
        StreamFreshness.aging,
      );
    });

    test('silent only when still live and stalled ten minutes', () {
      // Live + 10 min without an update = the StuckAgentSentinel threshold.
      expect(
        streamFreshness(
          nowMs: now,
          lastActivityAt: now - missionSilentThreshold.inMilliseconds,
          live: true,
        ),
        StreamFreshness.silent,
      );
      // One tick before the threshold the stream is merely aging.
      expect(
        streamFreshness(
          nowMs: now,
          lastActivityAt: now - missionSilentThreshold.inMilliseconds + 1,
          live: true,
        ),
        StreamFreshness.aging,
      );
      // A finished session that went quiet long ago is old, not stalled.
      expect(
        streamFreshness(
          nowMs: now,
          lastActivityAt: now - 2 * missionSilentThreshold.inMilliseconds,
          live: false,
        ),
        StreamFreshness.aging,
      );
    });

    test('unknown activity is neutral aging, never silent', () {
      expect(
        streamFreshness(nowMs: now, lastActivityAt: null, live: true),
        StreamFreshness.aging,
      );
    });
  });

  group('formatSilenceShort', () {
    test('coarse minutes below an hour — never seconds', () {
      expect(formatSilenceShort(10 * minute), '10m');
      expect(formatSilenceShort(59 * minute), '59m');
      expect(formatSilenceShort(90 * 1000), '1m');
    });

    test('hours with zero-padded minutes', () {
      expect(formatSilenceShort(65 * minute), '1h 05m');
      expect(formatSilenceShort(120 * minute), '2h 00m');
    });

    test('negative input clamps to zero', () {
      expect(formatSilenceShort(-5), '0m');
    });
  });
}
