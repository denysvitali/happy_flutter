// Native platform Sentry initialization
import 'dart:async' show FutureOr, unawaited;
import 'dart:io';

import 'package:flutter/foundation.dart'
    show kDebugMode, kReleaseMode;
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/services/logger_service.dart';
import 'sentry_config.dart';

// Baked in at build time via --dart-define=SENTRY_RELEASE=...
// Must match the release string used by sentry_dart_plugin when
// uploading debug symbols (set via SENTRY_RELEASE env var in CI).
// Falls back to null so Sentry auto-detects from PackageInfo in
// local builds where --dart-define is not passed.
const _sentryRelease = String.fromEnvironment('SENTRY_RELEASE');

/// Trusts the self-hosted Sentry server certificate.
///
/// The server presents a leaf cert signed by "K2 Cluster Root CA",
/// a private CA absent from platform trust stores. This override
/// lets dart:io [HttpClient] — used by the Sentry SDK transport —
/// accept that certificate for [sentryHost] only.
class _SentryHttpOverrides extends HttpOverrides {
  _SentryHttpOverrides(this._previous);
  final HttpOverrides? _previous;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final prev = _previous;
    final client = prev != null
        ? prev.createHttpClient(context)
        : super.createHttpClient(context);
    return client
      ..badCertificateCallback =
          (cert, host, port) => host == sentryHost;
  }
}

Future<void> initSentryForPlatform([
  Future<void> Function()? appRunner,
]) async {
  // Trust the self-hosted Sentry certificate before the SDK
  // creates its internal HTTP transport.
  HttpOverrides.global =
      _SentryHttpOverrides(HttpOverrides.current);

  await SentryFlutter.init((options) {
    options
      ..dsn = sentryDsn
      ..sendDefaultPii = true
      ..tracesSampleRate = sentryTracesSampleRate
      // ignore: experimental_member_use
      ..profilesSampleRate = sentryProfilesSampleRate
      ..release =
          _sentryRelease.isNotEmpty ? _sentryRelease : null
      ..environment = kReleaseMode ? 'production' : 'debug'
      // ANR detection disabled — background ANRs on Android are
      // almost always false positives and native-layer ANR events
      // bypass Dart's beforeSend filter.
      ..anrEnabled = false
      // ── Breadcrumb limits ──
      ..maxBreadcrumbs = 200
      ..attachStacktrace = true
      // ── Attach screenshots on errors/ANRs ──
      ..attachScreenshot = true
      // ── Session replay ──
      ..replay.sessionSampleRate = sentryReplaySessionSampleRate
      ..replay.onErrorSampleRate = sentryReplayOnErrorSampleRate
      // Print Sentry diagnostics to console in debug builds.
      ..debug = kDebugMode
      // ── Filter noisy events ──
      ..beforeBreadcrumb = _beforeBreadcrumb
      ..beforeSend = _beforeSend;
  }, appRunner: appRunner != null ? () => appRunner() : null);

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
    final uri = Uri.https(sentryHost, '/api/0/');
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

  if (statusCode >= 500) {
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
}

/// Patterns that indicate a transient network error (DNS failure,
/// connection timeout, etc.) — not actionable and expected on mobile.
const _transientNetworkPatterns = [
  'ERR_NAME_NOT_RESOLVED',
  'ERR_CONNECTION_TIMED_OUT',
  'ERR_CONNECTION_ABORTED',
  'ERR_CONNECTION_RESET',
  'ERR_NETWORK_CHANGED',
  'ERR_INTERNET_DISCONNECTED',
  'ERR_ADDRESS_UNREACHABLE',
  'Failed host lookup',
  'No address associated',
  'Connection closed',
  'Software caused connection abort',
];

bool _isTransientNetworkEvent(SentryEvent event) {
  for (final exception in event.exceptions ?? <SentryException>[]) {
    final value = exception.value ?? '';
    for (final pattern in _transientNetworkPatterns) {
      if (value.contains(pattern)) return true;
    }
  }
  final message = event.message?.formatted ?? '';
  for (final pattern in _transientNetworkPatterns) {
    if (message.contains(pattern)) return true;
  }
  return false;
}

FutureOr<SentryEvent?> _beforeSend(
  SentryEvent event,
  Hint hint,
) {
  // Drop background ANRs — on Android these are almost always
  // false positives caused by the OS deprioritising the app.
  for (final exception in event.exceptions ?? <SentryException>[]) {
    if (exception.type == 'ApplicationNotResponding' &&
        (exception.value?.contains('Background') ?? false)) {
      return null;
    }
  }

  // Drop transient network errors (DNS, timeout, etc.) — these
  // are expected when the device briefly loses connectivity.
  if (_isTransientNetworkEvent(event)) {
    return null;
  }

  // Drop expected permission-expiry events (session restarted while user
  // was approving/denying — the agent re-requests automatically).
  for (final exception in event.exceptions ?? <SentryException>[]) {
    if (exception.value?.contains('Session was restarted') ?? false) {
      return null;
    }
  }

  return event;
}

Breadcrumb? _beforeBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
  if (breadcrumb == null) return null;
  final message = breadcrumb.message ?? '';
  if (breadcrumb.category == 'websocket' &&
      (message == 'ws event: ephemeral' || message == 'ws event: update')) {
    return null;
  }

  if (breadcrumb.category == 'console' &&
      message.contains('[machine-activity]')) {
    return null;
  }

  return breadcrumb;
}
