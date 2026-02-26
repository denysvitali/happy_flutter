// Native platform Sentry initialization
import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> initSentryForPlatform(Future<void> Function() appRunner) async {
  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://34d0c1a2feec3a101164ba74383fc87e@o4506225548853248.ingest.us.sentry.io/4510613188378624';
      options.sendDefaultPii = true;
      options.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
      options.release = 'happy_flutter@1.0.0+1';
      options.environment = kReleaseMode ? 'production' : 'debug';
      // Print Sentry diagnostics to console in debug builds so
      // we can verify events are actually being sent.
      options.debug = kDebugMode;
    },
    appRunner: appRunner,
  );
}
