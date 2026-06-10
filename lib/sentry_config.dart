// Central Sentry / GlitchTip configuration.
//
// Imported by both `sentry_init_native.dart` and `sentry_init_web.dart`
// so the DSN is defined in exactly one place.

import 'package:flutter/foundation.dart' show kReleaseMode;

/// Keep GlitchTip enabled for crash capture.
const sentryEnabled = true;

/// Hostname of the self-hosted GlitchTip instance (private CA).
const sentryHost = 'glitchtip.k2.k8s.best';

/// Full DSN for the GlitchTip project.
const sentryDsn =
    'https://fa6df69a31f94f648a2facd2d074cd22'
    '@$sentryHost'
    '/1';

/// Performance sampling:
/// - release: very low rate to limit runtime overhead
/// - non-release: higher rate to make local/preview diagnosis practical
double get sentryTracesSampleRate => kReleaseMode ? 0.02 : 0.10;
const sentryProfilesSampleRate = 0.0;
const sentryReplaySessionSampleRate = 0.0;
const sentryReplayOnErrorSampleRate = 0.0;
const sentryAttachScreenshot = false;
const sentryEnableFrameMetrics = false;
const sentrySendDefaultPii = bool.fromEnvironment(
  'SENTRY_SEND_DEFAULT_PII',
  defaultValue: false,
);
const sentryAnrEnabled = bool.fromEnvironment(
  'SENTRY_ANR_ENABLED',
  defaultValue: true,
);

const sentryAnrTimeoutSeconds = int.fromEnvironment(
  'SENTRY_ANR_TIMEOUT_SECONDS',
  defaultValue: 5,
);
const sentryMaxBreadcrumbs = int.fromEnvironment(
  'SENTRY_MAX_BREADCRUMBS',
  // Keep small.  Sentry serializes every breadcrumb on the calling
  // thread when an event is captured, and the ANR watchdog (default
  // 5 s) often fires from the main thread where our 39
  // `Sentry.addBreadcrumb` call sites live.  Lower cap = smaller
  // serialization cost in the ANR capture path itself.
  defaultValue: 50,
);
const sentryEnableAutoNativeBreadcrumbs = bool.fromEnvironment(
  'SENTRY_ENABLE_AUTO_NATIVE_BREADCRUMBS',
  // Default off: Sentry's `SystemEventsBreadcrumbsIntegration` runs its
  // `BroadcastReceiver.onReceive()` synchronously on the main thread for
  // every BATTERY_CHANGED / NETWORK broadcast (getsentry/sentry-java#4907,
  // JAVA-241). The leaf functions in those receivers — `__vfprintf`
  // and `__memmove_aarch64_nt` — show up as ANR group-by keys in
  // GlitchTip (HAPPY_FLUTTER-3D8, -3DN, -3D7). Disabling auto native
  // breadcrumbs trades that main-thread pressure for a slightly thinner
  // event trail; the lifecycle / navigation integrations we add
  // explicitly still capture state transitions, and Dart-side
  // `logger.info/warning/error` calls go through our own breadcrumb
  // queue (see LoggerService).
  defaultValue: false,
);
bool get sentryEnableDioInterceptor => sentryTracesSampleRate > 0;
