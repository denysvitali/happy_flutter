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
  defaultValue: 20,
);
const sentryEnableAutoNativeBreadcrumbs = bool.fromEnvironment(
  'SENTRY_ENABLE_AUTO_NATIVE_BREADCRUMBS',
  defaultValue: false,
);
bool get sentryEnableDioInterceptor => sentryTracesSampleRate > 0;
bool get sentryEnableNavigationObserver => sentryTracesSampleRate > 0;

const _defaultSentryDropReasons =
    'background_anr,transient_network,non_actionable,session_restart';

const sentryDropReasons = String.fromEnvironment(
  'SENTRY_DROP_REASONS',
  defaultValue: _defaultSentryDropReasons,
);

final Set<String> sentryDropReasonSet = _parseSentryDropReasons(
  sentryDropReasons,
);

/// Kill switch for local validation: set
/// `--dart-define=SENTRY_FILTER_NON_ACTIONABLE=false`
/// to bypass all non-actionable/transient beforeSend filtering.
const sentryFilterNonActionable = bool.fromEnvironment(
  'SENTRY_FILTER_NON_ACTIONABLE',
  defaultValue: true,
);

bool shouldDropSentryReason(String reason) {
  return sentryDropReasonSet.contains(reason.toLowerCase().trim());
}

Set<String> _parseSentryDropReasons(String input) {
  final cleaned = input.trim().toLowerCase();
  if (cleaned.isEmpty || cleaned == 'none') {
    return <String>{};
  }

  if (cleaned == 'all') {
    return Set<String>.from(
      _defaultSentryDropReasons.split(',').map((value) => value.trim()),
    );
  }

  final parsed = input
      .split(',')
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .toSet();

  if (parsed.contains('all')) {
    return Set<String>.from(
      _defaultSentryDropReasons.split(',').map((value) => value.trim()),
    );
  }

  return parsed;
}
