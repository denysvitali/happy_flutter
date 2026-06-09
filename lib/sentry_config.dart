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
  defaultValue: 100,
);
const sentryEnableAutoNativeBreadcrumbs = bool.fromEnvironment(
  'SENTRY_ENABLE_AUTO_NATIVE_BREADCRUMBS',
  defaultValue: true,
);
bool get sentryEnableDioInterceptor => sentryTracesSampleRate > 0;
