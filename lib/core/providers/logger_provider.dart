import 'package:riverpod/riverpod.dart';
import '../services/logger_service.dart';

/// Log state for Riverpod
class LoggerState {
  LoggerState({
    this.logs = const [],
    this.filterLevel,
  });

  final List<LogEntry> logs;
  final int? filterLevel;

  LoggerState copyWith({
    List<LogEntry>? logs,
    int? filterLevel,
  }) {
    return LoggerState(
      logs: logs ?? this.logs,
      filterLevel: filterLevel ?? this.filterLevel,
    );
  }

  List<LogEntry> get filteredLogs {
    if (filterLevel == null) {
      return logs;
    }
    return logs.where((entry) => entry.level.index >= filterLevel!).toList();
  }
}

/// Logger notifier for Riverpod integration
class LoggerNotifier extends Notifier<LoggerState> {
  final _logger = LoggerService();

  @override
  LoggerState build() {
    // Subscribe to logger changes
    final unsubscribe = _logger.onChange(_onLogChanged);
    ref.onDispose(unsubscribe);

    return LoggerState(logs: _logger.getLogs());
  }

  void _onLogChanged() {
    state = state.copyWith(logs: _logger.getLogs());
  }

  /// Add a log entry
  void log(
    String message, {
    LogLevel level = LogLevel.info,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logger.log(
      message,
      level: level,
      error: error,
      stackTrace: stackTrace,
    );
    // Trigger rebuild
    state = state.copyWith(logs: _logger.getLogs());
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

  /// Clear all logs
  void clear() {
    _logger.clear();
    state = state.copyWith(logs: _logger.getLogs());
  }

  /// Set minimum log level filter
  void setFilterLevel(int? levelIndex) {
    state = state.copyWith(filterLevel: levelIndex);
  }

  /// Export logs as formatted string
  String exportLogs() {
    return _logger.exportLogs();
  }
}

/// Riverpod provider for the logger
final loggerNotifierProvider =
    NotifierProvider<LoggerNotifier, LoggerState>(() {
  return LoggerNotifier();
});

/// Convenience accessor for the logger service
final loggerServiceProvider = Provider<LoggerService>((ref) {
  return LoggerService();
});
