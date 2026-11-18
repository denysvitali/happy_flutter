import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// Drives an indeterminate progress indicator's [AnimationController].
///
/// A spinner on a running tool or a long agent turn can stay mounted for an
/// hour. Running it from a Ticker keeps the frame scheduler at the display
/// refresh rate (60–120 Hz) for that whole time — the app's dominant
/// foreground battery cost. The driver animates smoothly for [smoothPhase],
/// so short loads look normal, then advances the controller from a timer at
/// [steppedInterval] (~10 fps): still visibly alive, an order of magnitude
/// fewer frames.
///
/// Callers stop the driver whenever their ticker is muted (`TickerMode`
/// disabled): unlike a Ticker, the stepping timer would otherwise keep
/// scheduling frames for a covered route.
class IndeterminateProgressDriver {
  IndeterminateProgressDriver(this.controller);

  final AnimationController controller;

  @visibleForTesting
  static Duration smoothPhase = const Duration(seconds: 3);

  @visibleForTesting
  static Duration steppedInterval = const Duration(milliseconds: 100);

  Timer? _settleTimer;
  Timer? _stepTimer;
  bool _running = false;

  bool get isRunning => _running;

  /// Whether the indicator has left the smooth phase.
  @visibleForTesting
  bool get isStepped => _stepTimer != null;

  void start() {
    if (_running) return;
    _running = true;
    controller.repeat();
    _settleTimer = Timer(smoothPhase, _enterSteppedPhase);
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _settleTimer?.cancel();
    _settleTimer = null;
    _stepTimer?.cancel();
    _stepTimer = null;
    controller.stop();
  }

  void _enterSteppedPhase() {
    _settleTimer = null;
    if (!_running) return;
    controller.stop();
    final period = controller.duration;
    if (period == null || period <= Duration.zero) return;
    final step = steppedInterval.inMicroseconds / period.inMicroseconds;
    _stepTimer = Timer.periodic(steppedInterval, (_) {
      controller.value = (controller.value + step) % 1.0;
    });
  }
}
