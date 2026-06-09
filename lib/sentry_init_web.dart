// Web platform Sentry initialization
import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/services/logger_service.dart';
import 'sentry_config.dart';

const _sentryRelease = String.fromEnvironment('SENTRY_RELEASE');

// Must match SENTRY_DIST used by sentry_dart_plugin when uploading source
// maps, otherwise GlitchTip cannot associate them with incoming events.
const _sentryDist = String.fromEnvironment('SENTRY_DIST');

Future<void> initSentryForPlatform([Future<void> Function()? appRunner]) async {
  if (!sentryEnabled) {
    logger.warning('[Sentry] Web SDK disabled by sentryEnabled=false');
    if (appRunner != null) {
      await appRunner();
    }
    return;
  }

  await SentryFlutter.init((options) {
    options
      ..dsn = sentryDsn
      ..sendDefaultPii = sentrySendDefaultPii
      ..tracesSampleRate = sentryTracesSampleRate
      // ignore: experimental_member_use
      ..profilesSampleRate = sentryProfilesSampleRate
      ..release = _sentryRelease.isNotEmpty ? _sentryRelease : null
      ..dist = _sentryDist.isNotEmpty ? _sentryDist : null
      ..environment = kReleaseMode ? 'production' : 'debug'
      // ── Breadcrumb limits ──
      ..maxBreadcrumbs = sentryMaxBreadcrumbs
      ..attachStacktrace = true
      // ── Session replay ──
      ..replay.sessionSampleRate = sentryReplaySessionSampleRate
      ..replay.onErrorSampleRate = sentryReplayOnErrorSampleRate
      // Print Sentry diagnostics to console in debug builds.
      ..debug = kDebugMode;
  }, appRunner: appRunner != null ? () => appRunner() : null);

  logger.info(
    '[Sentry] Web SDK initialized '
    'sendDefaultPii=$sentrySendDefaultPii '
    'maxBreadcrumbs=$sentryMaxBreadcrumbs',
  );
}
