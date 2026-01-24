import 'package:flutter/material.dart';

/// Timer widget that updates every second to show elapsed time.
class ElapsedTimeWidget extends StatefulWidget {
  /// The start timestamp in milliseconds since epoch.
  final int? startTime;

  /// Text style for the elapsed time display.
  final TextStyle? style;

  const ElapsedTimeWidget({super.key, required this.startTime, this.style});

  @override
  State<ElapsedTimeWidget> createState() => _ElapsedTimeWidgetState();
}

class _ElapsedTimeWidgetState extends State<ElapsedTimeWidget> {
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _updateElapsed();
  }

  @override
  void didUpdateWidget(ElapsedTimeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startTime != widget.startTime) {
      _updateElapsed();
    }
  }

  void _updateElapsed() {
    if (widget.startTime == null) {
      setState(() => _elapsedSeconds = 0);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = ((now - widget.startTime!) / 1000).floor();
    setState(
      () => _elapsedSeconds = elapsed.clamp(0, double.maxFinite).toInt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle =
        widget.style ??
        TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontFamily: 'monospace',
        );

    return Text(
      '${_elapsedSeconds.toStringAsFixed(1)}s',
      style: effectiveStyle,
    );
  }
}

/// Hook-style widget that updates every second.
class ElapsedTime extends StatelessWidget {
  /// The start timestamp in milliseconds since epoch.
  final int? startTime;

  /// Callback to build the elapsed time widget.
  final Widget Function(BuildContext context, int elapsedSeconds) builder;

  const ElapsedTime({
    super.key,
    required this.startTime,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return _ElapsedTimeBuilder(
      startTime: startTime,
      builder: (context, elapsed) => builder(context, elapsed),
    );
  }
}

class _ElapsedTimeBuilder extends StatefulWidget {
  final int? startTime;
  final Widget Function(BuildContext context, int elapsedSeconds) builder;

  const _ElapsedTimeBuilder({required this.startTime, required this.builder});

  @override
  State<_ElapsedTimeBuilder> createState() => _ElapsedTimeBuilderState();
}

class _ElapsedTimeBuilderState extends State<_ElapsedTimeBuilder> {
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _updateElapsed();
  }

  @override
  void didUpdateWidget(_ElapsedTimeBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startTime != widget.startTime) {
      _updateElapsed();
    }
  }

  void _updateElapsed() {
    if (widget.startTime == null) {
      setState(() => _elapsedSeconds = 0);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = ((now - widget.startTime!) / 1000).floor();
    setState(
      () => _elapsedSeconds = elapsed.clamp(0, double.maxFinite).toInt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _elapsedSeconds);
  }
}
