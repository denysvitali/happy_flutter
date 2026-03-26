// Web platform Sentry initialization
import 'dart:async' show FutureOr;

import 'package:flutter/foundation.dart'
    show kDebugMode, kReleaseMode;
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/services/logger_service.dart';
import 'sentry_config.dart';

const _sentryRelease = String.fromEnvironment('SENTRY_RELEASE');

Future<void> initSentryForPlatform(
  Future<void> Function() appRunner,
) async {
  await SentryFlutter.init((options) {
    options
      ..dsn = sentryDsn
      ..sendDefaultPii = true
      ..tracesSampleRate = 0.2
      ..profilesSampleRate = 0.2
      ..release =
          _sentryRelease.isNotEmpty ? _sentryRelease : null
      ..environment = kReleaseMode ? 'production' : 'debug'
      // ── Breadcrumb limits ──
      ..maxBreadcrumbs = 100
      // ── Session replay ──
      ..replay.sessionSampleRate = 0.1
      ..replay.onErrorSampleRate = 1.0
      // Print Sentry diagnostics to console in debug builds.
      ..debug = kDebugMode
      // ── Filter noisy events ──
      ..beforeSend = _beforeSend;
  }, appRunner: appRunner);

  logger.info('[Sentry] Web SDK initialized');
}

/// Patterns that indicate a transient network error.
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
  // Drop transient network errors (DNS, timeout, etc.) — these
  // are expected when the device briefly loses connectivity.
  if (_isTransientNetworkEvent(event)) {
    return null;
  }

  return event;
}
