// Web platform Sentry initialization
import 'package:flutter/foundation.dart'
    show kDebugMode, kReleaseMode;
import 'package:sentry_flutter/sentry_flutter.dart';

const _sentryRelease = String.fromEnvironment('SENTRY_RELEASE');

Future<void> initSentryForPlatform(
  Future<void> Function() appRunner,
) async {
  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://b4bcb97417717a4e933c1ccb8305d6ab'
          '@o4506225548853248.ingest.us.sentry.io'
          '/4510912147292160';
      options.sendDefaultPii = true;
      options.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
      options.release =
          _sentryRelease.isNotEmpty ? _sentryRelease : null;
      options.environment =
          kReleaseMode ? 'production' : 'debug';

      // ── Breadcrumb limits ──
      options.maxBreadcrumbs = 250;

      // Print Sentry diagnostics to console in debug builds.
      options.debug = kDebugMode;
    },
    appRunner: appRunner,
  );
}
