// Central Sentry / GlitchTip configuration.
//
// Imported by both `sentry_init_native.dart` and `sentry_init_web.dart`
// so the DSN is defined in exactly one place.

import 'package:flutter/foundation.dart' show kReleaseMode;

/// Keep GlitchTip enabled for crash capture, but disable the expensive
/// runtime hooks that were hurting responsiveness.
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
const sentryCaptureWarnings = false;
bool get sentryEnableDioInterceptor => sentryTracesSampleRate > 0;
bool get sentryEnableNavigationObserver => sentryTracesSampleRate > 0;

/// Kill switch for local validation: set
/// `--dart-define=SENTRY_FILTER_NON_ACTIONABLE=false`
/// to bypass all non-actionable/transient beforeSend filtering.
const sentryFilterNonActionable = bool.fromEnvironment(
  'SENTRY_FILTER_NON_ACTIONABLE',
  defaultValue: true,
);
