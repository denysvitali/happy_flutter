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
/// When [developerModeEnabled] is true, all log levels are captured even in
/// release builds, allowing developers to see operational logs in
/// the DevLogsScreen.
class LoggerService {
  factory LoggerService() => _instance;
  LoggerService._();
  static final LoggerService _instance = LoggerService._();

  static const int _maxLogs = 5000;

  final Queue<LogEntry> _logs = Queue<LogEntry>();
  final List<void Function()> _listeners = [];

  /// Current minimum log level (logs below this level are discarded)
  LogLevel _minLevel = LogLevel.debug;

  /// When true, capture all log levels even in release mode.
  /// This is set when developer mode is enabled in settings.
  bool _developerModeEnabled = false;

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

  /// Add a log entry
  void log(
    String message, {
    LogLevel level = LogLevel.info,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    // Skip if below minimum level
    if (level.index < _minLevel.index) {
      return;
    }

    // In release mode, only process errors unless developer mode is enabled
    // (developer mode allows seeing all logs in DevLogsScreen for debugging)
    if (kReleaseMode && !_developerModeEnabled && level != LogLevel.error) {
      return;
    }

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    // Add to circular buffer (in release mode without dev mode, only errors)
    final shouldBuffer =
        !kReleaseMode || _developerModeEnabled || level == LogLevel.error;
    if (shouldBuffer) {
      _version++;
      _logs.add(entry);

      // Maintain circular buffer limit
      if (_logs.length > _maxLogs) {
        _logs.removeFirst();
      }
    }

    // Forward to Sentry (errors only in release mode without dev mode)
    final shouldForwardToSentry =
        !kReleaseMode || _developerModeEnabled || level == LogLevel.error;
    if (shouldForwardToSentry) {
      _forwardToSentry(entry);
    }

    // Write to console in debug mode (or release with dev mode)
    if (kDebugMode || (kReleaseMode && _developerModeEnabled)) {
      _writeToConsole(entry);
    }

    // Notify listeners
    final shouldNotify =
        !kReleaseMode || _developerModeEnabled || level == LogLevel.error;
    if (shouldNotify) {
      for (final listener in _listeners) {
        try {
          listener();
        } catch (e) {
          // Prevent listener errors from crashing the logger
        }
      }
    }
  }

  /// Forward warnings and errors to Sentry.
  ///
  /// Messages prefixed with `[Sentry]` are never forwarded to
  /// prevent circular loops (Sentry failure → warning → forward
  /// → Sentry failure → …). Transport failures are surfaced as
  /// warning-level entries so they appear in DevLogsScreen.
  void _forwardToSentry(LogEntry entry) {
    if (!sentryEnabled) return;

    // Only forward error levels by default. Warning forwarding can create
    // large event volume and noticeable overhead during reconnect/failure
    // storms, which is exactly when the app is already under stress.
    if (entry.level != LogLevel.error &&
        !(sentryCaptureWarnings && entry.level == LogLevel.warning)) {
      return;
    }
    // Break circular forwarding for our own diagnostics.
    if (entry.message.startsWith('[Sentry]')) return;

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

  /// Write log entry to console with appropriate styling
  void _writeToConsole(LogEntry entry) {
    final formatted = entry.toFormattedString();
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
    final list = _logs.toList();
    final start = list.length > n ? list.length - n : 0;
    return list.sublist(start);
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
