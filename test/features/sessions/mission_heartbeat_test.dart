import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_heartbeat.dart';

/// Freshness is the heartbeat of the focus queue: one decaying glow per
/// stream, quantized so no row needs its own animation controller.
void main() {
  final now = DateTime.now().millisecondsSinceEpoch;
  const minute = 60 * 1000;

  group('streamFreshness', () {
    test('burst within the first 45 seconds', () {
      expect(
        streamFreshness(nowMs: now, lastActivityAt: now - 44 * 1000, live: true),
        StreamFreshness.burst,
      );
      expect(
        streamFreshness(nowMs: now, lastActivityAt: now - 45 * 1000, live: true),
        StreamFreshness.burst,
      );
    });

    test('fresh until three minutes', () {
      expect(
        streamFreshness(nowMs: now, lastActivityAt: now - 46 * 1000, live: true),
        StreamFreshness.fresh,
      );
      expect(
        streamFreshness(nowMs: now, lastActivityAt: now - 3 * minute, live: true),
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
          lastActivityAt:
              now - missionSilentThreshold.inMilliseconds + 1,
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
