import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

/// Log levels in increasing order of severity
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// A single log entry
class LogEntry {
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

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });

  /// Convert to a formatted string for display/export
  String toFormattedString() {
    final time = '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${timestamp.millisecond.toString().padLeft(3, '0')}';
    final levelStr = level.name.toUpperCase().padRight(7);
    var result = '[$time] [$levelStr] $message';
    if (error != null) {
      result += '\nError: $error';
    }
    if (stackTrace != null) {
      result += '\nStack trace:\n$stackTrace';
    }
    return result;
  }

  @override
  String toString() => toFormattedString();
}

/// Logger service with circular buffer (5000 entry limit), listeners, and log levels.
///
/// Maintains an in-memory buffer of log entries and notifies listeners when new
/// entries are added. All logs are also written to the console in debug builds.
class LoggerService {
  static final LoggerService _instance = LoggerService._();
  factory LoggerService() => _instance;
  LoggerService._();

  static const int _maxLogs = 5000;

  final List<LogEntry> _logs = [];
  final List<void Function()> _listeners = [];

  /// Current minimum log level (logs below this level are discarded)
  LogLevel _minLevel = LogLevel.debug;

  /// Get the current minimum log level
  LogLevel get minLevel => _minLevel;

  /// Set the minimum log level
  void setMinLevel(LogLevel level) {
    _minLevel = level;
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

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    _logs.add(entry);

    // Maintain circular buffer limit
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }

    // Write to console in debug mode
    if (kDebugMode) {
      _writeToConsole(entry);
    }

    // Notify listeners
    for (final listener in _listeners) {
      try {
        listener();
      } catch (e) {
        // Prevent listener errors from crashing the logger
      }
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

  /// Get the current log count
  int get count => _logs.length;

  /// Get the last N logs
  List<LogEntry> getRecentLogs(int n) {
    final start = _logs.length > n ? _logs.length - n : 0;
    return _logs.sublist(start);
  }

  /// Get logs filtered by level
  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((entry) => entry.level == level).toList();
  }

  /// Clear all logs
  void clear() {
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
    final json = _logs.map((entry) => {
          'timestamp': entry.timestamp.toIso8601String(),
          'level': entry.level.name,
          'message': entry.message,
          'error': entry.error?.toString(),
          'stackTrace': entry.stackTrace?.toString(),
        }).toList();
    return '[${json.map((j) => j.toString()).join(', ')}]';
  }
}

/// Singleton instance for easy access
final logger = LoggerService();
