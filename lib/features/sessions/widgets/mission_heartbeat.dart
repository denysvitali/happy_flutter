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

const _freshnessBounds = _FreshnessBounds(
  45 * 1000,
  3 * 60 * 1000,
);

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
/// [MissionClock] replaces them with a single 15-second tick that only
/// runs while [active] — dependents rebuild through the inherited
/// dependency and render identical output when nothing changed.
class MissionClock extends StatefulWidget {
  const MissionClock({
    required this.child,
    this.active = true,
    super.key,
  });

  final Widget child;

  /// False cancels the ticker (no hot rows to keep fresh).
  final bool active;

  @override
  State<MissionClock> createState() => _MissionClockState();
}

class _MissionClockState extends State<MissionClock> {
  Timer? _timer;
  int _nowMs = DateTime.now().millisecondsSinceEpoch;

  static const _tick = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(MissionClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = widget.active
        ? Timer.periodic(_tick, (_) {
            if (!mounted) return;
            setState(() {
              _nowMs = DateTime.now().millisecondsSinceEpoch;
            });
          })
        : null;
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
  bool updateShouldNotify(_ClockData oldWidget) =>
      nowMs != oldWidget.nowMs;
}

/// Current shared time for [context], subscribing to future ticks.
///
/// Falls back to wall-clock time when no [MissionClock] ancestor exists,
/// so widgets stay correct (just not auto-refreshing) outside the
/// Mission Control tree — e.g. in tests or the folder detail view.
int missionNowOf(BuildContext context) {
  final data = context
      .dependOnInheritedWidgetOfExactType<_ClockData>();
  return data?.nowMs ?? DateTime.now().millisecondsSinceEpoch;
}
