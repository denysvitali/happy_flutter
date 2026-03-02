// Native platform Sentry initialization
import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:sentry_flutter/sentry_flutter.dart';

// Baked in at build time via --dart-define=SENTRY_RELEASE=...
// Must match the release string used by sentry_dart_plugin when
// uploading debug symbols (set via SENTRY_RELEASE env var in CI).
// Falls back to null so Sentry auto-detects from PackageInfo in
// local builds where --dart-define is not passed.
const _sentryRelease = String.fromEnvironment('SENTRY_RELEASE');

Future<void> initSentryForPlatform(Future<void> Function() appRunner) async {
  await SentryFlutter.init((options) {
    options
      ..dsn =
          'https://b4bcb97417717a4e933c1ccb8305d6ab'
          '@o4506225548853248.ingest.us.sentry.io'
          '/4510912147292160'
      ..sendDefaultPii = true
      ..tracesSampleRate = kReleaseMode ? 0.2 : 1.0
      ..release = _sentryRelease.isNotEmpty ? _sentryRelease : null
      ..environment = kReleaseMode ? 'production' : 'debug'
      // ── ANR detection ──
      ..anrEnabled = true
      ..anrTimeoutInterval = const Duration(seconds: 5)
      // ── Breadcrumb limits ──
      ..maxBreadcrumbs = 250
      // ── Attach screenshots on errors/ANRs ──
      ..attachScreenshot = true
      // Print Sentry diagnostics to console in debug builds.
      ..debug = kDebugMode;
  }, appRunner: appRunner);
}
