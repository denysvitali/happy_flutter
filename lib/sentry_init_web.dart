// Web platform Sentry initialization
import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:sentry_flutter/sentry_flutter.dart';

const _sentryRelease = String.fromEnvironment('SENTRY_RELEASE');

Future<void> initSentryForPlatform(Future<void> Function() appRunner) async {
  await SentryFlutter.init((options) {
    options
      ..dsn =
          'https://f5678b69ba186b302ab87c88707fe0c1'
          '@sentry.k2.k8s.best'
          '/2'
      ..sendDefaultPii = true
      ..tracesSampleRate = kReleaseMode ? 0.2 : 1.0
      ..release = _sentryRelease.isNotEmpty ? _sentryRelease : null
      ..environment = kReleaseMode ? 'production' : 'debug'
      // ── Breadcrumb limits ──
      ..maxBreadcrumbs = 250
      // Print Sentry diagnostics to console in debug builds.
      ..debug = kDebugMode;
  }, appRunner: appRunner);
}
