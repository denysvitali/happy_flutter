// Web platform Sentry initialization
import 'dart:async' show FutureOr;

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
      ..sendDefaultPii = true
      ..tracesSampleRate = sentryTracesSampleRate
      // ignore: experimental_member_use
      ..profilesSampleRate = sentryProfilesSampleRate
      ..release = _sentryRelease.isNotEmpty ? _sentryRelease : null
      ..dist = _sentryDist.isNotEmpty ? _sentryDist : null
      ..environment = kReleaseMode ? 'production' : 'debug'
      // ── Breadcrumb limits ──
      ..maxBreadcrumbs = 200
      ..attachStacktrace = true
      // ── Session replay ──
      ..replay.sessionSampleRate = sentryReplaySessionSampleRate
      ..replay.onErrorSampleRate = sentryReplayOnErrorSampleRate
      // Print Sentry diagnostics to console in debug builds.
      ..debug = kDebugMode
      // ── Disable auto user-interaction tracing ──
      // Same as native: the idle-timeout creates false "error"
      // transactions when widgets unmount during navigation.
      ..enableUserInteractionTracing = false
      // ── Filter noisy events ──
      ..beforeBreadcrumb = _beforeBreadcrumb
      ..beforeSend = _beforeSend;
  }, appRunner: appRunner != null ? () => appRunner() : null);

  logger.info(
    '[Sentry] Web SDK initialized (filterNonActionable='
    '$sentryFilterNonActionable, dropReasons=${sentryDropReasonSet.join(',')})',
  );
}

/// Patterns that indicate a transient network error.
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

/// Patterns that indicate a non-actionable error on web.
/// These are expected framework quirks, storage limits, or transient
/// infra issues that do not represent app bugs.
const _nonActionableWebPatterns = [
  // Flutter web: accessing a RenderBox before layout completes.
  // Non-actionable — the framework recovers on the next frame.
  'renderbox was not laid out',
  // Web localStorage / IndexedDB quota exceeded. The app already
  // falls back to in-memory storage and logs a warning.
  'quotaexceedederror',
  // Platform._version is unavailable on web. Already guarded by
  // conditional exports, but some build configs may still hit it.
  'unsupported operation: platform',
  'platform._version',
  // Web crypto: corrupted or legacy ciphertext.
  'illegalblocksizeexception',
  // Riverpod lifecycle: widget unmounted while async work in flight.
  'using "ref" when a widget is about to or has been unmounted',
  // Server-side 503 / WebSocket not upgraded.
  'was not upgraded to websocket',
  'http status code: 503',
  // Socket.IO transport errors on web (expected during reconnect).
  'transporterror',
  // Server 500 errors — not actionable in the client.
  'sessionsapiexception: failed to fetch sessions: 500',
  'sessionsapiexception: failed to archive session: 500',
  'failed to send message: 500',
  '[sendmessage] failed: status=500',
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
  // Legacy NaCl decryption failures — expected on key rotation or
  // corrupt historical ciphertext; rate-limited in code but still
  // leaks through when many distinct keys are involved.
  'cryptosecretbox.decrypt failed',
];

const _transientNetworkPatternsLower = _transientNetworkPatterns;
const _nonActionableWebPatternsLower = _nonActionableWebPatterns;

bool _isTransientNetworkEvent(SentryEvent event) {
  final patterns = _transientNetworkPatternsLower;
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

bool _isNonActionableWebEvent(SentryEvent event) {
  final patterns = _nonActionableWebPatternsLower;
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

  // Drop transient network errors (DNS, timeout, etc.) — these
  // are expected when the device briefly loses connectivity.
  if (shouldDropSentryReason('transient_network') &&
      _isTransientNetworkEvent(event)) {
    _logDroppedSentryEvent('transient_network', event);
    return null;
  }

  // Drop non-actionable web errors (framework quirks, storage
  // limits, expected RPC failures, server 500s, etc.).
  if (shouldDropSentryReason('non_actionable') &&
      _isNonActionableWebEvent(event)) {
    _logDroppedSentryEvent('non_actionable', event);
    return null;
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
