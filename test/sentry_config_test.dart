// Regression guard for Sentry configuration that affects main-thread
// pressure.  These are intentionally compile-time assertions — the
// flags are `const` from `bool.fromEnvironment`, so we can pin the
// default values in source.

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/sentry_config.dart';

void main() {
  group('Sentry configuration', () {
    test(
      'auto native breadcrumbs default to OFF',
      () {
        // Pinned off because Sentry's
        // SystemEventsBreadcrumbsIntegration processes system
        // broadcasts (BATTERY_CHANGED, NETWORK) synchronously on the
        // main thread, which has been the source of recurring ANRs
        // (HAPPY_FLUTTER-3D8 __memmove_aarch64_nt, 3DN __vfprintf,
        // 3D7 nativePollOnce).  Tracking issue:
        // getsentry/sentry-java#4907 (JAVA-241, still open in 9.20.0).
        // If you intentionally want to flip this back on, also fix
        // the underlying broadcast-receiver thread-safety first.
        expect(sentryEnableAutoNativeBreadcrumbs, isFalse);
      },
    );

    test('traces sample rate defaults are unchanged and in range', () {
      // 0.02 in release drops 98% of performance transactions. That is a
      // deliberate cost tradeoff, so the default is pinned here — raise it
      // per build with --dart-define=SENTRY_TRACES_SAMPLE_RATE=<0..1>
      // rather than by editing this default.
      expect(sentryTracesSampleRate, inInclusiveRange(0, 1));
      expect(sentryTracesSampleRate, 0.10); // tests run in non-release mode
      expect(sentryEnableDioInterceptor, isTrue);
    });

    test('frame metrics transactions default to OFF but are switchable', () {
      // Was a plain `const false`, which made the Sentry branch in
      // FrameMetricsService._flush unreachable dead code. It is now a
      // dart-define so the branch is genuinely enable-able.
      expect(sentryEnableFrameMetrics, isFalse);
    });

    test('ANR capture default to ON', () {
      // Belt and suspenders: ANR detection should be enabled by
      // default so we keep getting signal in GlitchTip.
      expect(sentryAnrEnabled, isTrue);
    });
  });
}
