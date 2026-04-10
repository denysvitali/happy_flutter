// Central Sentry / GlitchTip configuration.
//
// Imported by both `sentry_init_native.dart` and `sentry_init_web.dart`
// so the DSN is defined in exactly one place.

/// Hard kill-switch for GlitchTip/Sentry runtime integration.
///
/// The current priority is restoring app stability and responsiveness.
/// Keep the code paths available, but do not initialize the SDK until
/// the regression is understood with real device profiling.
const sentryEnabled = false;

/// Hostname of the self-hosted GlitchTip instance (private CA).
const sentryHost = 'glitchtip.k2.k8s.best';

/// Full DSN for the GlitchTip project.
const sentryDsn =
    'https://fa6df69a31f94f648a2facd2d074cd22'
    '@$sentryHost'
    '/1';

/// Performance sampling. Kept high because GlitchTip volume is small and
/// the app currently under-samples user-visible failures and slow paths.
///
/// GlitchTip/Sentry runtime overhead became a user-visible regression.
/// Keep crash reporting on, but sample performance data conservatively
/// and disable the heaviest capture features by default.
const sentryTracesSampleRate = 0.05;
const sentryProfilesSampleRate = 0.0;
const sentryReplaySessionSampleRate = 0.0;
const sentryReplayOnErrorSampleRate = 0.0;
const sentryAttachScreenshot = false;
const sentryEnableFrameMetrics = false;
const sentryCaptureWarnings = false;
