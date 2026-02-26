// Native platform Sentry initialization
import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> initSentryForPlatform(Future<void> Function() appRunner) async {
  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://b4bcb97417717a4e933c1ccb8305d6ab@o4506225548853248.ingest.us.sentry.io/4510912147292160';
      options.sendDefaultPii = true;
      options.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
      options.release = 'happy_flutter@1.0.0+1';
      options.environment = kReleaseMode ? 'production' : 'debug';
      // Detect ANRs (Application Not Responding) so OS-level
      // UI-thread freezes are captured in Sentry.
      options.anrEnabled = true;
      options.anrTimeoutInterval =
          const Duration(seconds: 5);
      // Print Sentry diagnostics to console in debug builds so
      // we can verify events are actually being sent.
      options.debug = kDebugMode;
    },
    appRunner: appRunner,
  );
}
