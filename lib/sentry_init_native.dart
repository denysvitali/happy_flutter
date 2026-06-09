// Native platform Sentry initialization
import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/services/logger_service.dart';
import 'sentry_config.dart';

// Baked in at build time via --dart-define=SENTRY_RELEASE=...
// Must match the release string used by sentry_dart_plugin when
// uploading debug symbols (set via SENTRY_RELEASE env var in CI).
// Falls back to null so Sentry auto-detects from PackageInfo in
// local builds where --dart-define is not passed.
const _sentryRelease = String.fromEnvironment('SENTRY_RELEASE');

// Baked in at build time via --dart-define=SENTRY_DIST=<build-number>.
// Must match SENTRY_DIST used by sentry_dart_plugin when uploading debug
// symbols, otherwise GlitchTip cannot associate the uploaded symbols with
// incoming events and obfuscated stack traces never symbolicate.
const _sentryDist = String.fromEnvironment('SENTRY_DIST');

Future<void> initSentryForPlatform([Future<void> Function()? appRunner]) async {
  if (!sentryEnabled) {
    logger.warning('[Sentry] SDK disabled by sentryEnabled=false');
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
      // ANR detection: capture foreground "Application Not Responding" events.
      ..anrEnabled = sentryAnrEnabled
      ..anrTimeoutInterval = Duration(seconds: sentryAnrTimeoutSeconds)
      // ── Breadcrumb limits ──
      ..maxBreadcrumbs = sentryMaxBreadcrumbs
      ..enableAutoNativeBreadcrumbs = sentryEnableAutoNativeBreadcrumbs
      ..attachStacktrace = true
      // ── Attach screenshots on errors/ANRs ──
      ..attachScreenshot = sentryAttachScreenshot
      // ── Session replay ──
      ..replay.sessionSampleRate = sentryReplaySessionSampleRate
      ..replay.onErrorSampleRate = sentryReplayOnErrorSampleRate
      // Print Sentry diagnostics to console in debug builds.
      ..debug = kDebugMode;
  }, appRunner: appRunner != null ? () => appRunner() : null);

  // Fire-and-forget: verify Sentry connectivity.
  unawaited(_pingSentry());

  logger.info(
    '[Sentry] anrEnabled=$sentryAnrEnabled '
    'anrTimeout=${sentryAnrTimeoutSeconds}s '
    'sendDefaultPii=$sentrySendDefaultPii '
    'maxBreadcrumbs=$sentryMaxBreadcrumbs '
    'nativeBreadcrumbs=$sentryEnableAutoNativeBreadcrumbs',
  );
}

Future<void> _pingSentry() async {
  // ── Step 1: raw HTTP check (bypasses Sentry SDK) ──
  // Verifies platform trust-store configuration + server reachability before
  // we trust the SDK to deliver events.
  final client = HttpClient();
  int? statusCode;
  try {
    final uri = Uri.https(sentryHost, '/api/0/');
    final request = await client.getUrl(uri);
    final response = await request.close();
    await response.drain<void>();
    statusCode = response.statusCode;
  } on HandshakeException catch (e) {
    logger.warning(
      '[Sentry] TLS handshake failed — check the user trust store: $e',
    );
    return;
  } on SocketException catch (e) {
    logger.warning('[Sentry] Server unreachable: $e');
    return;
  } catch (e) {
    logger.warning('[Sentry] Connectivity check failed: $e');
    return;
  } finally {
    client.close();
  }

  if (statusCode >= 500) {
    logger.warning(
      '[Sentry] Server returned HTTP $statusCode — '
      'the Sentry instance appears unhealthy. '
      'Events will likely be lost.',
    );
    return;
  }

  logger.info('[Sentry] Server healthy (HTTP $statusCode)');
}
