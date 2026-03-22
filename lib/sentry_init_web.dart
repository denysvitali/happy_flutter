// Web platform Sentry initialization
import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart'
    show kDebugMode, kReleaseMode;
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/services/logger_service.dart';

const _sentryRelease = String.fromEnvironment('SENTRY_RELEASE');

Future<void> initSentryForPlatform(
  Future<void> Function() appRunner,
) async {
  await SentryFlutter.init((options) {
    options
      ..dsn =
          'https://f5678b69ba186b302ab87c88707fe0c1'
          '@sentry.k2.k8s.best'
          '/2'
      ..sendDefaultPii = true
      ..tracesSampleRate = kReleaseMode ? 0.2 : 1.0
      ..release =
          _sentryRelease.isNotEmpty ? _sentryRelease : null
      ..environment = kReleaseMode ? 'production' : 'debug'
      // ── Breadcrumb limits ──
      ..maxBreadcrumbs = 250
      // Print Sentry diagnostics to console in debug builds.
      ..debug = kDebugMode;
  }, appRunner: appRunner);

  // Fire-and-forget: verify Sentry connectivity.
  unawaited(_pingSentry());
}

Future<void> _pingSentry() async {
  try {
    final eventId = await Sentry.captureMessage(
      'App started — Sentry connectivity test',
      level: SentryLevel.info,
    );
    if (eventId == SentryId.empty()) {
      logger.info(
        '[Sentry] Ping dropped '
        '(event filtered or DSN invalid)',
      );
    } else {
      logger.info('[Sentry] Ping sent (event $eventId)');
    }
  } catch (e) {
    logger.info('[Sentry] Ping failed: $e');
  }
}
