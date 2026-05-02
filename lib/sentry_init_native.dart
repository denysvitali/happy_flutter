// Native platform Sentry initialization
import 'dart:async' show FutureOr, unawaited;
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
      ..badCertificateCallback = (cert, host, port) => host == sentryHost;
  }
}

Future<void> initSentryForPlatform([Future<void> Function()? appRunner]) async {
  if (!sentryEnabled) {
    logger.warning('[Sentry] SDK disabled by sentryEnabled=false');
    if (appRunner != null) {
      await appRunner();
    }
    return;
  }

  // Trust the self-hosted Sentry certificate before the SDK
  // creates its internal HTTP transport.
  HttpOverrides.global = _SentryHttpOverrides(HttpOverrides.current);

  await SentryFlutter.init((options) {
    options
      ..dsn = sentryDsn
      ..sendDefaultPii = true
      ..tracesSampleRate = sentryTracesSampleRate
      // ignore: experimental_member_use
      ..profilesSampleRate = sentryProfilesSampleRate
      ..release = _sentryRelease.isNotEmpty ? _sentryRelease : null
      ..environment = kReleaseMode ? 'production' : 'debug'
      // Keep Android ANR reporting enabled. Background ANRs are filtered below
      // when the SDK routes them through beforeSend, but disabling this option
      // prevents foreground "Application Not Responding" events from reaching
      // GlitchTip at all.
      ..anrEnabled = true
      // Automatic user interaction tracing creates a transaction for
      // every tap (back button, list items, etc.) with a 3-second idle
      // timeout. This produces false "error" transactions when widgets
      // unmount during navigation and generates noise in GlitchTip.
      ..enableUserInteractionTracing = false
      // ── Breadcrumb limits ──
      ..maxBreadcrumbs = 200
      ..attachStacktrace = true
      // ── Attach screenshots on errors/ANRs ──
      ..attachScreenshot = sentryAttachScreenshot
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

/// Patterns that indicate a transient network error (DNS failure,
/// connection timeout, etc.) — not actionable and expected on mobile.
const _transientNetworkPatterns = [
  'err_name_not_resolved',
  'err_connection_timed_out',
  'err_connection_aborted',
  'err_connection_reset',
  'err_network_changed',
  'err_internet_disconnected',
  'err_address_unreachable',
  'failed host lookup',
  'no address associated',
  'connection closed',
  'software caused connection abort',
];

/// Patterns that indicate a non-actionable error on native.
/// These are expected transient infra issues or framework quirks
/// that do not represent app bugs.
const _nonActionableNativePatterns = [
  // Android clipboard overflow when copying large text.
  'transactiontoolargeexception',
  'data parcel size',
  // Expected RPC failures when machine/session is transiently
  // unavailable (daemon reconnecting, handler not yet registered).
  'machine encryption not found',
  'session encryption not found',
  'rpc handler',
  'is not registered',
  'operation has timed out',
  'rpc call',
  'forwarded via redis',
  'no replica responded',
  'machine rpc',
  'session rpc',
  // Session was restarted while user was acting on a permission.
  'session was restarted',
  // Machine offline warnings (already logged at warning level).
  'machine is offline',
  'machine appears offline',
  // Server-side errors not actionable in the client.
  'sessionsapiexception: failed to fetch sessions: 500',
  'sessionsapiexception: failed to archive session: 500',
  'failed to send message: 500',
  '[sendmessage] failed: status=500',
  // Riverpod lifecycle: widget unmounted while async work in flight.
  'using "ref" when a widget is about to or has been unmounted',
  // Legacy NaCl decryption failures — expected on key rotation or
  // corrupt historical ciphertext; rate-limited in code but still
  // leaks through when many distinct keys are involved.
  'cryptosecretbox.decrypt failed',
];

const _transientNetworkPatternsLower = _transientNetworkPatterns;
const _nonActionableNativePatternsLower = _nonActionableNativePatterns;

bool _isTransientNetworkEvent(SentryEvent event) {
  final patterns = _transientNetworkPatterns;
  for (final exception in event.exceptions ?? <SentryException>[]) {
    final value = (exception.value ?? '').toLowerCase();
    for (final pattern in patterns) {
      if (value.contains(pattern)) return true;
    }
  }
  final message = (event.message?.formatted ?? '').toLowerCase();
  for (final pattern in patterns) {
    if (message.contains(pattern)) return true;
  }
  return false;
}

bool _isNonActionableNativeEvent(SentryEvent event) {
  const patterns = _nonActionableNativePatternsLower;
  for (final exception in event.exceptions ?? <SentryException>[]) {
    final value = (exception.value ?? '').toLowerCase();
    for (final pattern in patterns) {
      if (value.contains(pattern)) return true;
    }
  }
  final message = (event.message?.formatted ?? '').toLowerCase();
  for (final pattern in patterns) {
    if (message.contains(pattern)) return true;
  }
  return false;
}

FutureOr<SentryEvent?> _beforeSend(SentryEvent event, Hint hint) {
  if (!sentryFilterNonActionable) return event;

  if (event.level == SentryLevel.fatal) return event;

  // Drop background ANRs — on Android these are almost always
  // false positives caused by the OS deprioritising the app.
  for (final exception in event.exceptions ?? <SentryException>[]) {
    if (exception.type == 'ApplicationNotResponding' &&
        (exception.value?.toLowerCase().contains('background') ?? false)) {
      _logDroppedSentryEvent('background_anr', event);
      return null;
    }
  }

  // Drop transient network errors (DNS, timeout, etc.) — these
  // are expected when the device briefly loses connectivity.
  if (_isTransientNetworkEvent(event)) {
    _logDroppedSentryEvent('transient_network', event);
    return null;
  }

  // Drop non-actionable native errors (clipboard overflow, expected
  // RPC failures, server 500s, machine offline, etc.).
  if (_isNonActionableNativeEvent(event)) {
    _logDroppedSentryEvent('non_actionable', event);
    return null;
  }

  // Drop expected permission-expiry events (session restarted while user
  // was approving/denying — the agent re-requests automatically).
  for (final exception in event.exceptions ?? <SentryException>[]) {
    if ((exception.value?.toLowerCase().contains('session was restarted')) ??
        false) {
      _logDroppedSentryEvent('session_restart', event);
      return null;
    }
  }

  return event;
}

final _droppedSentryEventReasonCounts = <String, int>{};

void _logDroppedSentryEvent(String reason, SentryEvent event) {
  final count = (_droppedSentryEventReasonCounts[reason] ?? 0) + 1;
  _droppedSentryEventReasonCounts[reason] = count;
  if (count == 1 || count == 5 || count % 25 == 0) {
    final eventId = event.eventId.toString();
    logger.warning(
      '[Sentry] beforeSend dropped event as "$reason" (#$count) id=$eventId',
    );
  }
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
