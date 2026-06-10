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

    test('ANR capture default to ON', () {
      // Belt and suspenders: ANR detection should be enabled by
      // default so we keep getting signal in GlitchTip.
      expect(sentryAnrEnabled, isTrue);
    });
  });
}
