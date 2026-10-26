import 'dart:async';

import 'package:flutter/material.dart';

/// How alive a stream is, derived from the age of its last update.
///
/// Mission Control's focus queue answers "what needs me"; freshness
/// answers "which agents are actually making progress". The levels map
/// onto one decaying glow per row instead of a per-row animation
/// controller, so the screen stays idle-render free:
///
/// - [burst]   updated within the last few seconds — bright tile + dot.
/// - [fresh]   progressing normally — mild tint, dot visible.
/// - [aging]   no update in a while — dimmed, dot hidden.
/// - [silent]  no update for [silentThreshold] while still marked live —
///             amber "N m silent" hint. Matches `StuckAgentSentinel`'s
///             10-minute stall threshold so both surfaces agree on what
///             "stalled" means.
enum StreamFreshness { burst, fresh, aging, silent }

/// A stream counts as stalled after this long without any update.
const Duration missionSilentThreshold = Duration(minutes: 10);

class _FreshnessBounds {
  const _FreshnessBounds(this.burstMs, this.freshMs);

  final int burstMs;
  final int freshMs;
}

const _freshnessBounds = _FreshnessBounds(45 * 1000, 3 * 60 * 1000);

/// Classifies the age of a stream's last update.
///
/// [live] gates the [StreamFreshness.silent] level: only a session that
/// still claims to be working can be "silent" — an offline or finished
/// session is simply old, not stalled. Pass `lastActivityAt: null` when
/// nothing is known; the result is the neutral [StreamFreshness.aging].
StreamFreshness streamFreshness({
  required int nowMs,
  required int? lastActivityAt,
  required bool live,
}) {
  if (lastActivityAt == null) return StreamFreshness.aging;
  final age = nowMs - lastActivityAt;
  if (age <= _freshnessBounds.burstMs) return StreamFreshness.burst;
  if (age <= _freshnessBounds.freshMs) return StreamFreshness.fresh;
  if (live && age >= missionSilentThreshold.inMilliseconds) {
    return StreamFreshness.silent;
  }
  return StreamFreshness.aging;
}

/// Coarse silence age for stall hints: `12m`, `1h 05m`.
///
/// Unlike [formatElapsedShort] this never shows seconds — silence is
/// meaningful at minute scale, and the pill width stays stable between
/// clock ticks.
String formatSilenceShort(int millis) {
  final seconds = (millis < 0 ? 0 : millis) ~/ 1000;
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m';
  return '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';
}

/// One coarse wall clock for the whole Mission Control tree.
///
/// Rows that display time-relative state ("4m silent", freshness glow)
/// previously each ran their own 1-second `Timer.periodic`. With many
/// concurrent streams that multiplied into dozens of wakeups per minute.
/// Live rows share a 15-second tick. Static rows instead wake at the next
/// displayed relative-age boundary (minutes, hours, then days). Owners pass
/// only displayed rows, excluding filtered and folded content.
class MissionClock extends StatefulWidget {
  const MissionClock({
    required this.child,
    this.active = true,
    this.live = true,
    this.relativeTimestamps = const [],
    this.now = DateTime.now,
    super.key,
  });

  final Widget child;

  /// False cancels the ticker (no hot rows to keep fresh).
  final bool active;

  /// Only the live lane needs freshness and silence updates every 15s.
  final bool live;

  /// Activity timestamps used by the displayed rows' compact age labels.
  final List<int> relativeTimestamps;

  /// Wall clock, overridable for deterministic time-boundary tests.
  final DateTime Function() now;

  @override
  State<MissionClock> createState() => _MissionClockState();
}

class _MissionClockState extends State<MissionClock> {
  Timer? _timer;
  int _nowMs = DateTime.now().millisecondsSinceEpoch;
  bool _tickerActive = true;

  static const _tick = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerActive = TickerMode.valuesOf(context).enabled;
    if (_tickerActive == tickerActive) return;
    _tickerActive = tickerActive;
    _arm();
  }

  @override
  void didUpdateWidget(MissionClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh immediately when rows change or a dormant clock wakes up.
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = null;
    _nowMs = widget.now().millisecondsSinceEpoch;
    if (!widget.active || !_tickerActive) return;
    Duration? delay = widget.live ? _tick : null;
    for (final timestamp in widget.relativeTimestamps) {
      final age = _nowMs - timestamp;
      const minute = Duration.millisecondsPerMinute;
      // Match MissionActionRow's formatRelativeTime(compact: true),
      // including clock skew and its relative-days override past a week.
      final int remaining;
      if (age <= -minute) {
        remaining = -minute - age + 1;
      } else if (age < 0) {
        remaining = minute - age;
      } else {
        final unit = age < Duration.millisecondsPerHour
            ? minute
            : age < Duration.millisecondsPerDay
            ? Duration.millisecondsPerHour
            : Duration.millisecondsPerDay;
        remaining = unit - age % unit;
      }
      final boundary = Duration(milliseconds: remaining);
      if (delay == null || boundary < delay) delay = boundary;
    }
    if (delay == null) return;
    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(_arm);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ClockData(nowMs: _nowMs, child: widget.child);
  }
}

class _ClockData extends InheritedWidget {
  const _ClockData({required this.nowMs, required super.child});

  final int nowMs;

  @override
  bool updateShouldNotify(_ClockData oldWidget) => nowMs != oldWidget.nowMs;
}

/// Current shared time for [context], subscribing to future ticks.
///
/// Falls back to wall-clock time when no [MissionClock] ancestor exists,
/// so widgets stay correct (just not auto-refreshing) outside the
/// Mission Control tree — e.g. in tests or the folder detail view.
int missionNowOf(BuildContext context) {
  final data = context.dependOnInheritedWidgetOfExactType<_ClockData>();
  return data?.nowMs ?? DateTime.now().millisecondsSinceEpoch;
}
