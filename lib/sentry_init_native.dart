// Native platform Sentry initialization
import 'package:flutter/foundation.dart'
    show kDebugMode, kReleaseMode;
import 'package:sentry_flutter/sentry_flutter.dart';

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
      // Do NOT set options.release — let Sentry auto-detect it
      // from PackageInfo (e.g. happy_flutter@1.0.0+37301).
      // Manually overriding it caused a mismatch with the release
      // string used by sentry_dart_plugin when uploading debug
      // symbols, so ANR stacktraces were never symbolicated.
      options.environment =
          kReleaseMode ? 'production' : 'debug';

      // ── ANR detection ──
      options.anrEnabled = true;
      options.anrTimeoutInterval =
          const Duration(seconds: 5);

      // ── Breadcrumb limits ──
      options.maxBreadcrumbs = 250;

      // ── Attach screenshots on errors/ANRs ──
      options.attachScreenshot = true;

      // Print Sentry diagnostics to console in debug builds.
      options.debug = kDebugMode;
    },
    appRunner: appRunner,
  );
}
