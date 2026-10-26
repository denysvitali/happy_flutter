import 'dart:async';

import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/app_inline_row.dart';

/// Shared row typography with tabular figures so ticking digits stay aligned.
TextStyle _elapsedStyle(BuildContext context) {
  return AppInlineText.secondary(
    context,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

/// Shared 1-second ticker that all [ElapsedTimeWidget] and [ElapsedTime]
/// instances subscribe to.  Without this, each tool card creates its own
/// [Timer.periodic], leading to 10+ timers (and 10+ setState calls)
/// firing every second during tool execution.
final _sharedTicker = _SharedTicker();

class _SharedTicker extends ChangeNotifier {
  Timer? _timer;
  int _subscriberCount = 0;

  void subscribe() {
    _subscriberCount++;
    if (_timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        notifyListeners();
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
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _ElapsedTimeBuilder(
        startTime: widget.startTime,
        builder: (context, elapsed) {
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
    required this.startTime,
    required this.builder,
    super.key,
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
  const _ElapsedTimeBuilder({required this.startTime, required this.builder});
  final int? startTime;
  final Widget Function(BuildContext context, int elapsedSeconds) builder;

  @override
  State<_ElapsedTimeBuilder> createState() => _ElapsedTimeBuilderState();
}

class _ElapsedTimeBuilderState extends State<_ElapsedTimeBuilder> {
  bool _subscribed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSubscription();
  }

  @override
  void didUpdateWidget(_ElapsedTimeBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateSubscription();
  }

  void _updateSubscription() {
    final active =
        widget.startTime != null && TickerMode.valuesOf(context).enabled;
    if (active == _subscribed) return;
    _subscribed = active;
    if (active) {
      _sharedTicker.subscribe();
      _sharedTicker.addListener(_tick);
    } else {
      _sharedTicker.removeListener(_tick);
      _sharedTicker.unsubscribe();
    }
  }

  void _tick() {
    setState(() {});
  }

  @override
  void dispose() {
    if (_subscribed) {
      _sharedTicker.removeListener(_tick);
      _sharedTicker.unsubscribe();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startTime = widget.startTime;
    if (startTime == null) {
      return widget.builder(context, 0);
    }
    // Read wall time on every build, including the first visible frame after
    // resuming. Hidden widgets have no listener or timer subscription.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsed = ((nowMs - startTime) / 1000).floor().clamp(0, 999999);
    return widget.builder(context, elapsed);
  }
}
