import 'dart:async';

import 'package:riverpod/riverpod.dart';
import '../services/logger_service.dart';
import '_shared.dart';

/// Log state for Riverpod
class LoggerState {
  LoggerState({
    required this.service,
    required this.version,
    this.filterLevel,
    this.searchQuery = '',
  });

  final LoggerService service;
  final int version;
  final int? filterLevel;
  final String searchQuery;

  // Cached computed list — populated lazily on first access.
  List<LogEntry>? _filteredLogsCache;

  LoggerState copyWith({
    int? version,
    Object? filterLevel = unset,
    String? searchQuery,
  }) {
    return LoggerState(
      service: service,
      version: version ?? this.version,
      filterLevel: identical(filterLevel, unset)
          ? this.filterLevel
          : filterLevel as int?,
      searchQuery: searchQuery ?? this.searchQuery,
    ).._filteredLogsCache = null;
  }

  List<LogEntry> get filteredLogs {
    return _filteredLogsCache ??= _computeFilteredLogs();
  }

  List<LogEntry> _computeFilteredLogs() {
    // Compose filters as a lazy Iterable chain so we only allocate a
    // backing list once, at the consumer boundary. The previous
    // implementation copied the entire 5000-entry buffer up front and
    // again after each filter pass.
    Iterable<LogEntry> view = service.allLogs;

    final minIndex = filterLevel;
    if (minIndex != null) {
      view = view.where((entry) => entry.level.index >= minIndex);
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      view = view.where(
        (entry) =>
            entry.message.toLowerCase().contains(query) ||
            (entry.error?.toString().toLowerCase().contains(query) ?? false),
      );
    }

    // Single materialisation at the end.
    return view.toList(growable: false);
  }
}

/// Logger notifier for Riverpod integration
class LoggerNotifier extends Notifier<LoggerState> {
  final _logger = LoggerService();
  Timer? _logDebounceTimer;

  @override
  LoggerState build() {
    // Subscribe to logger changes
    final unsubscribe = _logger.onChange(_onLogChanged);
    ref.onDispose(() {
      _logDebounceTimer?.cancel();
      unsubscribe();
    });

    return LoggerState(
      service: _logger,
      version: _logger.version,
    );
  }

  void _onLogChanged() {
    _logDebounceTimer?.cancel();
    _logDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      // Bump version to signal change — no list copy at write time.
      state = state.copyWith(version: state.version + 1);
    });
  }

  /// Add a log entry
  void log(
    String message, {
    LogLevel level = LogLevel.info,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logDebounceTimer?.cancel();
    _logger.log(
      message,
      level: level,
      error: error,
      stackTrace: stackTrace,
    );
    // Trigger rebuild — bump version
    state = state.copyWith(version: state.version + 1);
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
    _logDebounceTimer?.cancel();
    _logger.clear();
    state = state.copyWith(version: _logger.version);
  }

  /// Set minimum log level filter
  void setFilterLevel(int? levelIndex) {
    state = state.copyWith(filterLevel: levelIndex);
  }

  /// Set search query for filtering logs
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
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
