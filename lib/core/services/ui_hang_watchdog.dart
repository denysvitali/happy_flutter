import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

import 'logger_service.dart';

class UiHangWatchdog {
  UiHangWatchdog._();

  static const _tick = Duration(seconds: 1);
  static const _threshold = Duration(seconds: 5);
  static const _cooldown = Duration(minutes: 1);

  static Timer? _timer;
  static DateTime? _expectedNextTick;
  static DateTime? _lastReport;

  static void start() {
    if (_timer != null) return;

    final now = DateTime.now();
    _expectedNextTick = now.add(_tick);
    _timer = Timer.periodic(_tick, (_) => _check());
    logger.info('[UiHangWatchdog] started');
  }

  static void _check() {
    final now = DateTime.now();
    final expected = _expectedNextTick ?? now;
    _expectedNextTick = now.add(_tick);

    final delay = now.difference(expected);
    if (delay < _threshold) return;

    final lastReport = _lastReport;
    if (lastReport != null && now.difference(lastReport) < _cooldown) {
      return;
    }
    _lastReport = now;

    final delayMs = delay.inMilliseconds;
    logger.warning('[UiHangWatchdog] UI isolate delayed by ${delayMs}ms');
    unawaited(
      Sentry.captureMessage(
        'Flutter UI isolate hang detected',
        level: SentryLevel.warning,
        withScope: (scope) {
          scope
            ..setTag('watchdog.type', 'ui_isolate_hang')
            ..setTag('watchdog.source', 'dart_timer')
            ..setContexts('watchdog', {
              'delay_ms': delayMs,
              'threshold_ms': _threshold.inMilliseconds,
              'tick_ms': _tick.inMilliseconds,
            });
        },
      ),
    );
  }
}
