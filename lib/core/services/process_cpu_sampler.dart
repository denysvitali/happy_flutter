import '../../platform_io.dart'
    if (dart.library.js_interop) '../../platform_stub.dart';

/// Process CPU accounting independent of frame rendering or wall-clock changes.
/// 100% means one fully occupied core; parallel native work can exceed 100%.
class ProcessCpuSampler {
  ProcessCpuSampler({
    Duration? Function()? readCpuTime,
    Duration Function()? readElapsed,
  }) : _readCpuTime = readCpuTime ?? (() => currentProcessCpuTime),
       _readElapsed = readElapsed;

  final Duration? Function() _readCpuTime;
  final Duration Function()? _readElapsed;
  final Stopwatch _clock = Stopwatch()..start();
  Duration? _previousCpu;
  Duration? _previousElapsed;

  /// Begin a foreground interval without including time spent suspended.
  void reset() {
    _previousCpu = _readCpuTime();
    _previousElapsed = _readElapsed?.call() ?? _clock.elapsed;
  }

  ({Duration cpuTime, double utilization})? sample() {
    final previousCpu = _previousCpu;
    final previousElapsed = _previousElapsed;
    reset();
    final cpu = _previousCpu;
    if (cpu == null || previousCpu == null || previousElapsed == null) {
      return null;
    }
    final elapsed = _previousElapsed! - previousElapsed;
    final consumed = cpu - previousCpu;
    // Unavailable counters, overflow/reset and zero-length windows are not
    // measurements of zero usage. Rebaseline rather than invent a sample.
    if (elapsed.inMicroseconds <= 0 || consumed.isNegative) return null;
    return (
      cpuTime: consumed,
      utilization: consumed.inMicroseconds / elapsed.inMicroseconds * 100,
    );
  }
}
