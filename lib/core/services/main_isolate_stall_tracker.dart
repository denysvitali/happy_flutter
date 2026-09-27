import 'dart:collection';
import 'dart:developer' show Timeline;

import 'package:flutter/foundation.dart' show visibleForTesting;

/// One completed synchronous job that held the UI isolate.
typedef MainIsolateWork = ({String name, int startMicros, int endMicros});

/// Attributes frozen frames to known synchronous work on the UI isolate.
///
/// Production frozen frames on Android showed build and raster under 10 ms
/// while the frame took 100 ms-1 s: the frame waited for the UI isolate
/// before build started (`FrameTiming.vsyncOverhead`). Frame timings cannot
/// say what held the isolate, so hot synchronous paths register themselves
/// here and [FrameMetricsService] matches them against each frozen frame's
/// vsync-to-build window.
///
/// Timestamps use [Timeline.now], the same monotonic microsecond clock the
/// engine uses for `FrameTiming` phases.
class MainIsolateStallTracker {
  MainIsolateStallTracker._();
  static final MainIsolateStallTracker instance = MainIsolateStallTracker._();

  /// Work shorter than half a 60 Hz frame cannot explain a frozen frame.
  static const int minRecordedMicros = 8000;
  static const int _capacity = 32;

  final ListQueue<MainIsolateWork> _recent = ListQueue<MainIsolateWork>();

  @visibleForTesting
  int Function() clock = _monotonicMicros;

  static int _monotonicMicros() => Timeline.now;

  /// Run [body] synchronously and remember it when it was long enough to
  /// delay a frame. Must not wrap async work: only the synchronous part
  /// would be measured.
  T track<T>(String name, T Function() body) {
    final start = clock();
    try {
      return body();
    } finally {
      record(name, start, clock());
    }
  }

  void record(String name, int startMicros, int endMicros) {
    if (endMicros - startMicros < minRecordedMicros) return;
    _recent.addLast((
      name: name,
      startMicros: startMicros,
      endMicros: endMicros,
    ));
    while (_recent.length > _capacity) {
      _recent.removeFirst();
    }
  }

  /// Name of the tracked work overlapping [fromMicros]..[toMicros] the most,
  /// or null when no tracked work overlaps the interval.
  String? blockerBetween(int fromMicros, int toMicros) {
    if (toMicros <= fromMicros) return null;
    String? best;
    var bestOverlap = 0;
    for (final work in _recent) {
      final start = work.startMicros > fromMicros
          ? work.startMicros
          : fromMicros;
      final end = work.endMicros < toMicros ? work.endMicros : toMicros;
      final overlap = end - start;
      if (overlap > bestOverlap) {
        bestOverlap = overlap;
        best = work.name;
      }
    }
    return best;
  }

  @visibleForTesting
  void reset() {
    _recent.clear();
    clock = _monotonicMicros;
  }
}
