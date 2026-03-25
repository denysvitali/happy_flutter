/// Central Sentry / GlitchTip configuration.
///
/// Imported by both `sentry_init_native.dart` and `sentry_init_web.dart`
/// so the DSN is defined in exactly one place.

/// Hostname of the self-hosted GlitchTip instance (private CA).
const sentryHost = 'glitchtip.k2.k8s.best';

/// Full DSN for the GlitchTip project.
const sentryDsn =
    'https://fa6df69a31f94f648a2facd2d074cd22'
    '@$sentryHost'
    '/1';
