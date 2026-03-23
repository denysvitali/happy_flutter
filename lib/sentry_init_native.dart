// Native platform Sentry initialization
import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/foundation.dart'
    show kDebugMode, kReleaseMode;
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/services/logger_service.dart';

// Baked in at build time via --dart-define=SENTRY_RELEASE=...
// Must match the release string used by sentry_dart_plugin when
// uploading debug symbols (set via SENTRY_RELEASE env var in CI).
// Falls back to null so Sentry auto-detects from PackageInfo in
// local builds where --dart-define is not passed.
const _sentryRelease = String.fromEnvironment('SENTRY_RELEASE');

/// Hostname of the self-hosted Sentry instance (private CA).
const _sentryHost = 'sentry.k2.k8s.best';

/// Trusts the self-hosted Sentry server certificate.
///
/// The server presents a leaf cert signed by "K2 Cluster Root CA",
/// a private CA absent from platform trust stores. This override
/// lets dart:io [HttpClient] — used by the Sentry SDK transport —
/// accept that certificate for [_sentryHost] only.
class _SentryHttpOverrides extends HttpOverrides {
  _SentryHttpOverrides(this._previous);
  final HttpOverrides? _previous;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final prev = _previous;
    final client = prev != null
        ? prev.createHttpClient(context)
        : super.createHttpClient(context);
    client.badCertificateCallback =
        (cert, host, port) => host == _sentryHost;
    return client;
  }
}

Future<void> initSentryForPlatform(
  Future<void> Function() appRunner,
) async {
  // Trust the self-hosted Sentry certificate before the SDK
  // creates its internal HTTP transport.
  HttpOverrides.global =
      _SentryHttpOverrides(HttpOverrides.current);

  await SentryFlutter.init((options) {
    options
      ..dsn =
          'https://f5678b69ba186b302ab87c88707fe0c1'
          '@$_sentryHost'
          '/2'
      ..sendDefaultPii = true
      ..tracesSampleRate = 1.0
      ..profilesSampleRate = 1.0
      ..enableLogs = true
      ..release =
          _sentryRelease.isNotEmpty ? _sentryRelease : null
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

  // Fire-and-forget: verify Sentry connectivity.
  unawaited(_pingSentry());
}

Future<void> _pingSentry() async {
  // ── Step 1: raw HTTP check (bypasses Sentry SDK) ──
  // Verifies TLS override + server reachability before we
  // trust the SDK to deliver events.
  final client = HttpClient();
  int? statusCode;
  try {
    final uri = Uri.https(_sentryHost, '/api/0/');
    final request = await client.getUrl(uri);
    final response = await request.close();
    await response.drain<void>();
    statusCode = response.statusCode;
  } on HandshakeException catch (e) {
    logger.warning(
      '[Sentry] TLS handshake failed — '
      'HttpOverrides may not be active: $e',
    );
    return;
  } on SocketException catch (e) {
    logger.warning(
      '[Sentry] Server unreachable: $e',
    );
    return;
  } catch (e) {
    logger.warning(
      '[Sentry] Connectivity check failed: $e',
    );
    return;
  } finally {
    client.close();
  }

  if (statusCode != null && statusCode >= 500) {
    logger.warning(
      '[Sentry] Server returned HTTP $statusCode — '
      'the Sentry instance appears unhealthy. '
      'Events will likely be lost.',
    );
    return;
  }

  logger.info(
    '[Sentry] Server healthy (HTTP $statusCode)',
  );

  // ── Step 2: SDK-level test event ──
  try {
    final eventId = await Sentry.captureMessage(
      'App started — Sentry connectivity test',
      level: SentryLevel.info,
    );
    if (eventId == SentryId.empty()) {
      logger.warning(
        '[Sentry] Ping dropped '
        '(event filtered or DSN invalid)',
      );
    } else {
      logger.info('[Sentry] Ping sent (event $eventId)');
    }
  } catch (e) {
    logger.warning('[Sentry] Ping failed: $e');
  }
}
