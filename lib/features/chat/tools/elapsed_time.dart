import 'dart:async';

import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

/// Default style for inline elapsed-time readouts: quiet monospace pill
/// with tabular figures so ticking digits don't jitter the row.
TextStyle _elapsedStyle(BuildContext context) {
  return TextStyle(
    fontSize: AppFontSize.xs,
    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(
      alpha: AppOpacity.high,
    ),
    fontFamily: 'monospace',
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Shared 1-second ticker that all [ElapsedTimeWidget] and [ElapsedTime]
/// instances subscribe to.  Without this, each tool card creates its own
/// [Timer.periodic], leading to 10+ timers (and 10+ setState calls)
/// firing every second during tool execution.
final _sharedTicker = _SharedTicker();

class _SharedTicker {
  Timer? _timer;
  int _subscriberCount = 0;
  final _notifier = ValueNotifier<int>(
    DateTime.now().millisecondsSinceEpoch,
  );

  ValueNotifier<int> get notifier => _notifier;

  void subscribe() {
    _subscriberCount++;
    if (_timer == null) {
      _notifier.value = DateTime.now().millisecondsSinceEpoch;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _notifier.value = DateTime.now().millisecondsSinceEpoch;
      });
    }
  }

  void unsubscribe() {
    _subscriberCount--;
    if (_subscriberCount <= 0) {
      _subscriberCount = 0;
      _timer?.cancel();
      _timer = null;
    }
  }
}

/// Timer widget that updates every second to show elapsed time.
class ElapsedTimeWidget extends StatefulWidget {

  const ElapsedTimeWidget({required this.startTime, super.key, this.style});
  /// The start timestamp in milliseconds since epoch.
  final int? startTime;

  /// Text style for the elapsed time display.
  final TextStyle? style;

  @override
  State<ElapsedTimeWidget> createState() => _ElapsedTimeWidgetState();
}

class _ElapsedTimeWidgetState extends State<ElapsedTimeWidget> {
  @override
  void initState() {
    super.initState();
    if (widget.startTime != null) _sharedTicker.subscribe();
  }

  @override
  void didUpdateWidget(ElapsedTimeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startTime == null && widget.startTime != null) {
      _sharedTicker.subscribe();
    } else if (oldWidget.startTime != null && widget.startTime == null) {
      _sharedTicker.unsubscribe();
    }
  }

  @override
  void dispose() {
    if (widget.startTime != null) _sharedTicker.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startTime = widget.startTime;
    if (startTime == null) {
      return Text('0s', style: widget.style ?? _elapsedStyle(context));
    }

    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: _sharedTicker.notifier,
        builder: (context, nowMs, _) {
          final elapsed = ((nowMs - startTime) / 1000).floor().clamp(
            0,
            999999,
          );
          return Text(
            '${elapsed}s',
            style: widget.style ?? _elapsedStyle(context),
          );
        },
      ),
    );
  }
}

/// Hook-style widget that updates every second.
class ElapsedTime extends StatelessWidget {

  const ElapsedTime({
    required this.startTime, required this.builder, super.key,
  });
  /// The start timestamp in milliseconds since epoch.
  final int? startTime;

  /// Callback to build the elapsed time widget.
  final Widget Function(BuildContext context, int elapsedSeconds) builder;

  @override
  Widget build(BuildContext context) {
    return _ElapsedTimeBuilder(
      startTime: startTime,
      builder: (context, elapsed) => builder(context, elapsed),
    );
  }
}

class _ElapsedTimeBuilder extends StatefulWidget {

  const _ElapsedTimeBuilder({
    required this.startTime,
    required this.builder,
  });
  final int? startTime;
  final Widget Function(BuildContext context, int elapsedSeconds) builder;

  @override
  State<_ElapsedTimeBuilder> createState() => _ElapsedTimeBuilderState();
}

class _ElapsedTimeBuilderState extends State<_ElapsedTimeBuilder> {
  @override
  void initState() {
    super.initState();
    if (widget.startTime != null) _sharedTicker.subscribe();
  }

  @override
  void didUpdateWidget(_ElapsedTimeBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startTime == null && widget.startTime != null) {
      _sharedTicker.subscribe();
    } else if (oldWidget.startTime != null && widget.startTime == null) {
      _sharedTicker.unsubscribe();
    }
  }

  @override
  void dispose() {
    if (widget.startTime != null) _sharedTicker.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startTime = widget.startTime;
    if (startTime == null) {
      return widget.builder(context, 0);
    }
    return ValueListenableBuilder<int>(
      valueListenable: _sharedTicker.notifier,
      builder: (context, nowMs, _) {
        final elapsed = ((nowMs - startTime) / 1000).floor().clamp(
          0,
          999999,
        );
        return widget.builder(context, elapsed);
      },
    );
  }
}
