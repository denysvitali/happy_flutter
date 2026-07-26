import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show kDebugMode, kReleaseMode, debugPrint, visibleForTesting;
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../sentry_config.dart';

/// Log levels in increasing order of severity
enum LogLevel { debug, info, warning, error }

/// A single log entry
class LogEntry {
  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });

  /// Timestamp when the log was created
  final DateTime timestamp;

  /// Log level (debug, info, warning, error)
  final LogLevel level;

  /// The log message
  final String message;

  /// Optional error object
  final dynamic error;

  /// Optional stack trace
  final StackTrace? stackTrace;

  /// Convert to a formatted string for display/export
  String toFormattedString() {
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${timestamp.millisecond.toString().padLeft(3, '0')}';
    final levelStr = level.name.toUpperCase().padRight(7);
    final buffer = StringBuffer('[$time] [$levelStr] $message');
    if (error != null) {
      buffer.write('\nError: $error');
    }
    if (stackTrace != null) {
      buffer.write('\nStack trace:\n$stackTrace');
    }
    return buffer.toString();
  }

  @override
  String toString() => toFormattedString();
}

/// Logger service with circular buffer (5000 entry limit),
///
/// Maintains an in-memory buffer of log entries and notifies listeners when new
/// entries are added. All logs are also written to the console in debug builds.
///
/// When developer mode is enabled, all log levels are captured even in
/// release builds, allowing developers to see operational logs in
/// the DevLogsScreen.
///
/// **Console/buffer visibility and telemetry export are independent.** A
/// release build without developer mode buffers and prints nothing below
/// `error`, but still exports every `warning` and `error` to Sentry and OTel.
class LoggerService {
  factory LoggerService() => _instance;
  LoggerService._();
  static final LoggerService _instance = LoggerService._();

  static const int _maxLogs = 5000;

  /// `Queue()` returns a [ListQueue] under the hood, which gives us
  /// O(1) `add` (push tail) and O(1) `removeFirst` (pop head) — exactly
  /// what a ring buffer needs. We intentionally do not use `List<E>`
  /// here because `List.removeAt(0)` is O(n) and would degrade hot
  /// logging paths under the 5000-entry cap.
  final ListQueue<LogEntry> _logs = ListQueue<LogEntry>(_maxLogs);
  final List<void Function()> _listeners = [];

  /// Current minimum log level (logs below this level are discarded)
  LogLevel _minLevel = LogLevel.debug;

  /// When true, capture all log levels even in release mode.
  /// This is set when developer mode is enabled in settings.
  bool _developerModeEnabled = false;

  /// Optional OTel log sink installed by [OpenTelemetryService].
  /// All logs that pass the level/mode gate are forwarded here.
  void Function(LogEntry)? _otelLogSink;

  /// Re-entrancy guard so an OTel forwarding failure cannot recurse.
  bool _forwardingToOtel = false;

  /// Test-only override for [kReleaseMode]. `kReleaseMode` is a compile-time
  /// constant, so the release gating below is otherwise unreachable from the
  /// test suite — which is exactly how it silently dropped every warning in
  /// shipped builds.
  bool? _releaseModeOverride;

  bool get _isReleaseMode => _releaseModeOverride ?? kReleaseMode;

  @visibleForTesting
  // ignore: avoid_setters_without_getters
  set debugReleaseModeOverride(bool? value) {
    _releaseModeOverride = value;
  }

  /// Get the current minimum log level
  LogLevel get minLevel => _minLevel;

  /// Set the minimum log level
  void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  /// Enable or disable developer mode.
  /// When enabled, all log levels are captured even in release builds.
  void setDeveloperMode(bool enabled) {
    _developerModeEnabled = enabled;
  }

  /// Install a sink that receives every log entry that is exported — which
  /// includes warnings and errors in release builds even when they are not
  /// buffered or printed. Used by [OpenTelemetryService] to forward logs to
  /// the OTel collector. The sink is wrapped in a re-entrancy guard and never
  /// throws.
  void installOtelSink(void Function(LogEntry) sink) {
    _otelLogSink = sink;
  }

  /// Remove a previously installed OTel sink. Test-only: production installs
  /// the sink exactly once, from [OpenTelemetryService.initialize].
  @visibleForTesting
  void removeOtelSink() {
    _otelLogSink = null;
  }

  /// Add a log entry
  void log(
    String message, {
    LogLevel level = LogLevel.info,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    // Level / mode gate — bail before doing any allocation work.
    if (!shouldLog(level)) {
      return;
    }

    // "Should this be shown to a human on this device?" and "should this be
    // exported to Sentry/OTel?" are DIFFERENT questions. Conflating them is
    // what silently deleted 82% of the app's deliberate error signal: in a
    // release build with developer mode off, only `LogLevel.error` reached
    // the forwarders, so the ~400 `logger.warning` call sites produced no
    // Sentry event and no OTel log record at all. Console/buffer noise stays
    // suppressed; EXPORT never does.
    final release = _isReleaseMode;
    final shouldBufferAndNotify =
        !release || _developerModeEnabled || level == LogLevel.error;
    final shouldWriteConsole = kDebugMode || (release && _developerModeEnabled);
    final shouldForward =
        shouldBufferAndNotify || level.index >= LogLevel.warning.index;

    // If nothing downstream will consume this entry, skip allocation entirely.
    if (!shouldBufferAndNotify && !shouldWriteConsole && !shouldForward) {
      return;
    }

    // Now that we know the entry will be used somewhere, allocate it.
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    // Add to circular buffer (in release mode without dev mode, only errors).
    if (shouldBufferAndNotify) {
      _version++;
      _logs.add(entry);

      // Maintain circular buffer limit. `ListQueue.removeFirst` is O(1).
      if (_logs.length > _maxLogs) {
        _logs.removeFirst();
      }
    }

    // Forwarding is deliberately outside the buffer guard — see above.
    if (shouldForward) {
      _forwardToSentry(entry);
      _forwardToOtel(entry);
    }

    // Write to console in debug mode (or release with dev mode). ANSI
    // formatting only happens inside this guard so release builds pay
    // nothing for escape-code interpolation.
    if (shouldWriteConsole) {
      _writeToConsole(entry);
    }

    // Notify listeners.
    if (shouldBufferAndNotify) {
      for (final listener in _listeners) {
        try {
          listener();
        } catch (e) {
          // Prevent listener errors from crashing the logger
        }
      }
    }
  }

  /// Whether [level] will be processed at all — buffered, printed, *or*
  /// forwarded to Sentry/OTel. Call sites use this as a cheap guard before
  /// building expensive log messages.
  ///
  /// Note this is deliberately broader than "will appear in DevLogsScreen":
  /// in a release build without developer mode, warnings return `true` even
  /// though they are neither printed nor buffered, because they still have
  /// to reach the telemetry exporters.
  bool shouldLog(LogLevel level) {
    if (level.index < _minLevel.index) {
      return false;
    }

    // In release mode without developer mode, drop debug/info entirely —
    // nothing downstream consumes them. Warnings and errors always survive
    // because both are exported.
    if (_isReleaseMode && !_developerModeEnabled) {
      return level.index >= LogLevel.warning.index;
    }

    return true;
  }

  /// Forward warnings and errors to Sentry.
  ///
  /// Messages prefixed with `[Sentry]` are never forwarded to
  /// prevent circular loops (Sentry failure → warning → forward
  /// → Sentry failure → …). Transport failures are surfaced as
  /// warning-level entries so they appear in DevLogsScreen.
  void _forwardToSentry(LogEntry entry) {
    if (!sentryEnabled) return;

    if (entry.level != LogLevel.error && entry.level != LogLevel.warning) {
      return;
    }
    // Break circular forwarding for our own diagnostics.
    if (entry.message.startsWith('[Sentry]')) return;

    if (!_admitToSentry(entry)) return;
    _sentryEmitCount++;

    try {
      final Future<SentryId> future;
      if (entry.level == LogLevel.error) {
        future = Sentry.captureException(
          entry.error ?? entry.message,
          stackTrace: entry.stackTrace,
          hint: Hint.withMap({'logger': 'LoggerService'}),
        );
      } else {
        future = Sentry.captureMessage(
          entry.message,
          level: SentryLevel.warning,
          hint: Hint.withMap({
            'logger': 'LoggerService',
            if (entry.error != null) 'error': entry.error.toString(),
          }),
        );
      }
      future
          .then((eventId) {
            if (eventId == SentryId.empty()) {
              warning(
                '[Sentry] Event dropped '
                '(filtered or DSN invalid)',
              );
            }
          })
          .catchError((Object e) {
            warning('[Sentry] Transport failed: $e');
          });
    } catch (e) {
      warning('[Sentry] Forward failed: $e');
    }
  }

  /// Bounded emission policy for the Sentry path.
  ///
  /// Warnings are emitted from hot loops (per session per sync round, per
  /// socket event, per storage write) and their messages interpolate ids and
  /// counts, so an unguarded `Sentry.captureMessage` per warning is unbounded
  /// in BOTH volume and issue cardinality. Two independent guards:
  ///
  /// 1. Fingerprint dedup — the message is normalised (digits, hex ids and
  ///    UUIDs collapsed to `#`) and a fingerprint may only be sent once per
  ///    [_sentryDedupWindow]. This is what makes a per-session or per-id
  ///    message shape cost one event instead of N.
  /// 2. Token bucket — a global ceiling of [_sentryBucketCapacity] warnings,
  ///    refilled at [_sentryRefillPerMinute]/min, so even a stream of
  ///    genuinely distinct shapes cannot exhaust the project quota.
  ///
  /// Errors bypass both: they are rare, carry stack traces, and are the
  /// signal the quota exists to protect. The OTel path is left unthrottled —
  /// it is aggregated and not billed per event.
  bool _admitToSentry(LogEntry entry) {
    if (entry.level == LogLevel.error) return true;

    final nowMs = _nowMs();
    final key = _sentryFingerprint(entry.message);
    final lastMs = _sentrySeen.remove(key);
    if (lastMs != null && nowMs - lastMs < _sentryDedupWindow.inMilliseconds) {
      // Re-insert without refreshing the timestamp: a hot repeat must not be
      // able to keep itself alive at the head of the LRU forever, but it also
      // must not extend its own cooldown.
      _sentrySeen[key] = lastMs;
      return false;
    }

    if (!_takeSentryToken(nowMs)) return false;

    _sentrySeen[key] = nowMs;
    if (_sentrySeen.length > _sentrySeenCapacity) {
      _sentrySeen.remove(_sentrySeen.keys.first);
    }
    return true;
  }

  /// Refill and consume one token. Returns false when the bucket is empty.
  bool _takeSentryToken(int nowMs) {
    final elapsedMs = nowMs - _sentryBucketRefilledAtMs;
    if (elapsedMs > 0) {
      final refill = elapsedMs * _sentryRefillPerMinute / 60000;
      if (refill >= 1) {
        _sentryTokens = (_sentryTokens + refill)
            .clamp(0, _sentryBucketCapacity)
            .toDouble();
        _sentryBucketRefilledAtMs = nowMs;
      }
    }
    if (_sentryTokens < 1) return false;
    _sentryTokens -= 1;
    return true;
  }

  /// Collapse variable parts of a message so `dropped 3 item(s)` for session A
  /// and `dropped 17 item(s)` for session B share one fingerprint.
  static String _sentryFingerprint(String message) {
    final normalised = message
        .replaceAll(_hexIdPattern, '#')
        .replaceAll(_digitsPattern, '#');
    return normalised.length > _sentryFingerprintMaxLength
        ? normalised.substring(0, _sentryFingerprintMaxLength)
        : normalised;
  }

  static final RegExp _hexIdPattern = RegExp(
    r'\b[0-9a-fA-F-]{8,}\b',
  );
  static final RegExp _digitsPattern = RegExp(r'\d+');

  static const Duration _sentryDedupWindow = Duration(minutes: 5);
  static const int _sentrySeenCapacity = 256;
  static const int _sentryBucketCapacity = 20;
  static const int _sentryRefillPerMinute = 10;
  static const int _sentryFingerprintMaxLength = 160;

  /// Fingerprint → epoch-ms of the last emitted event. Insertion-ordered, so
  /// `keys.first` is the oldest entry and eviction is O(1)-ish.
  final LinkedHashMap<String, int> _sentrySeen = LinkedHashMap<String, int>();

  double _sentryTokens = _sentryBucketCapacity.toDouble();
  int _sentryBucketRefilledAtMs = 0;
  int _sentryEmitCount = 0;

  /// Test-only clock override so throttle windows can be advanced without
  /// real time passing.
  int Function()? _nowMsOverride;

  int _nowMs() =>
      _nowMsOverride?.call() ?? DateTime.now().millisecondsSinceEpoch;

  /// Number of entries actually handed to Sentry (post-throttle).
  @visibleForTesting
  int get debugSentryEmitCount => _sentryEmitCount;

  @visibleForTesting
  // ignore: avoid_setters_without_getters
  set debugSentryClock(int Function()? clock) {
    _nowMsOverride = clock;
  }

  /// Reset the Sentry emission policy — tests only.
  @visibleForTesting
  void debugResetSentryThrottle() {
    _sentrySeen.clear();
    _sentryTokens = _sentryBucketCapacity.toDouble();
    _sentryBucketRefilledAtMs = _nowMs();
    _sentryEmitCount = 0;
  }

  /// Forward a log entry to the installed OTel sink.
  ///
  /// This is a best-effort, fire-and-forget path: OTel transport failures are
  /// not allowed to crash the logger or to recurse.
  void _forwardToOtel(LogEntry entry) {
    final sink = _otelLogSink;
    if (sink == null || _forwardingToOtel) return;

    _forwardingToOtel = true;
    try {
      sink(entry);
    } catch (_) {
      // Swallow — the logger must never fail because its sink failed.
    } finally {
      _forwardingToOtel = false;
    }
  }

  /// Write log entry to console with appropriate styling.
  ///
  /// ANSI escape codes are only interpolated under [kDebugMode]; release
  /// builds (even with developer mode enabled) emit plain strings so
  /// device log viewers / Sentry breadcrumbs don't have to strip them.
  void _writeToConsole(LogEntry entry) {
    final formatted = entry.toFormattedString();
    if (kDebugMode) {
      switch (entry.level) {
        case LogLevel.debug:
          debugPrint(formatted);
        case LogLevel.info:
          debugPrint('\x1B[32m$formatted\x1B[0m'); // Green
        case LogLevel.warning:
          debugPrint('\x1B[33m$formatted\x1B[0m'); // Yellow
        case LogLevel.error:
          debugPrint('\x1B[31m$formatted\x1B[0m'); // Red
      }
      return;
    }
    // Release-with-dev-mode: plain output, no ANSI interp.
    debugPrint(formatted);
  }

  /// Log a debug message
  void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    log(message, level: LogLevel.debug, error: error, stackTrace: stackTrace);
  }

  /// Log an info message
  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    log(message, level: LogLevel.info, error: error, stackTrace: stackTrace);
  }

  /// Log a warning message
  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    log(message, level: LogLevel.warning, error: error, stackTrace: stackTrace);
  }

  /// Log an error message
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    log(message, level: LogLevel.error, error: error, stackTrace: stackTrace);
  }

  /// Get all logs as a copy of the list
  List<LogEntry> getLogs() {
    return List<LogEntry>.from(_logs);
  }

  /// Insert a pre-built [LogEntry] directly into the buffer without
  /// triggering Sentry forwarding, console output, or listener notifications.
  ///
  /// For use in tests only — bypasses all side effects of [log].
  @visibleForTesting
  void insertEntry(LogEntry entry) {
    _version++;
    _logs.add(entry);
    // `ListQueue.removeFirst` is O(1).
    if (_logs.length > _maxLogs) _logs.removeFirst();
  }

  /// Get an iterable view of all logs (zero-copy). Safe as long as
  /// callers only iterate during a single synchronous build pass.
  Iterable<LogEntry> get allLogs => _logs;

  /// Monotonically increasing counter; increments on every log write.
  /// Cheap signal that state changed without copying any log data.
  int get version => _version;
  int _version = 0;

  /// Get the current log count
  int get count => _logs.length;

  /// Get the last N logs
  List<LogEntry> getRecentLogs(int n) {
    final len = _logs.length;
    if (n >= len) return _logs.toList();
    // Skip the head without materializing the full buffer first.
    return _logs.skip(len - n).toList(growable: false);
  }

  /// Get logs filtered by level
  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((entry) => entry.level == level).toList();
  }

  /// Clear all logs
  void clear() {
    _version++;
    _logs.clear();
    for (final listener in _listeners) {
      try {
        listener();
      } catch (e) {
        // Prevent listener errors from crashing the logger
      }
    }
  }

  /// Subscribe to log changes - returns unsubscribe function
  void Function() onChange(void Function() listener) {
    _listeners.add(listener);
    return () {
      _listeners.remove(listener);
    };
  }

  /// Export all logs as formatted string
  String exportLogs() {
    return _logs.map((entry) => entry.toFormattedString()).join('\n');
  }

  /// Export logs in JSON format
  String exportLogsAsJson() {
    final jsonList = _logs
        .map(
          (entry) => {
            'timestamp': entry.timestamp.toIso8601String(),
            'level': entry.level.name,
            'message': entry.message,
            'error': entry.error?.toString(),
            'stackTrace': entry.stackTrace?.toString(),
          },
        )
        .toList();
    return jsonEncode(jsonList);
  }
}

/// Singleton instance for easy access
final logger = LoggerService();
