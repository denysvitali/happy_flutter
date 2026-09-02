// Native platform Sentry initialization
import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/services/logger_service.dart';
import 'core/utils/package_info_cache.dart';
import 'sentry_config.dart';

// Optional overrides for non-Android packaging (e.g. web still uses
// --dart-define). Prefer PackageInfo on mobile so CI can change
// versionCode without invalidating Flutter AOT inputs.
const _sentryReleaseOverride = String.fromEnvironment('SENTRY_RELEASE');
const _sentryDistOverride = String.fromEnvironment('SENTRY_DIST');

Future<void> initSentryForPlatform([Future<void> Function()? appRunner]) async {
  if (!sentryEnabled) {
    logger.warning('[Sentry] SDK disabled by sentryEnabled=false');
    if (appRunner != null) {
      await appRunner();
    }
    return;
  }

  // Runtime identity from the APK/IPA, not a compile-time dart-define.
  // CI must set SENTRY_RELEASE for sentry_dart_plugin to the same string:
  // happy_flutter@${version}+${buildNumber}.
  //
  // Release Linux bundles already provide both values at build time. Do not
  // make startup depend on the package-info platform plugin in that case:
  // package-info is a Dart-only plugin on Linux and older Flutter runtimes
  // can fail its registration before the first frame. A telemetry identity
  // must never prevent the application window from opening.
  PackageInfo? packageInfo;
  if (_sentryReleaseOverride.isEmpty || _sentryDistOverride.isEmpty) {
    try {
      packageInfo = await PackageInfoCache.get();
    } catch (error, stack) {
      logger.warning(
        '[Sentry] package metadata unavailable; using unset release',
        error,
        stack,
      );
    }
  }
  final release = _sentryReleaseOverride.isNotEmpty
      ? _sentryReleaseOverride
      : packageInfo == null
      ? null
      : 'happy_flutter@${packageInfo.version}+${packageInfo.buildNumber}';
  final dist = _sentryDistOverride.isNotEmpty
      ? _sentryDistOverride
      : packageInfo?.buildNumber;

  await SentryFlutter.init((options) {
    options
      ..dsn = sentryDsn
      ..sendDefaultPii = sentrySendDefaultPii
      ..tracesSampleRate = sentryTracesSampleRate
      // ignore: experimental_member_use
      ..profilesSampleRate = sentryProfilesSampleRate
      ..release = release
      ..dist = dist
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
