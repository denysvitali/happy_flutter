import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/providers/logger_provider.dart';
import 'package:happy_flutter/core/services/logger_service.dart';
import 'package:riverpod/riverpod.dart';

LoggerService get _svc => LoggerService();

/// Add a log entry to the singleton service without Sentry side-effects.
void _addEntry(String message, LogLevel level, {dynamic error}) {
  _svc.insertEntry(LogEntry(
    timestamp: DateTime(2026, 1, 1),
    level: level,
    message: message,
    error: error,
  ));
}

LoggerState _makeState({int? filterLevel, String searchQuery = ''}) =>
    LoggerState(
      service: _svc,
      version: _svc.version,
      filterLevel: filterLevel,
      searchQuery: searchQuery,
    );

void main() {
  group('LoggerState', () {
    setUp(() => _svc.clear());

    test('should have empty filteredLogs and default field values', () {
      final state = _makeState();
      expect(state.filteredLogs, isEmpty);
      expect(state.filterLevel, isNull);
      expect(state.searchQuery, '');
    });

    test('should create with provided filter values', () {
      _addEntry('test', LogLevel.info);
      final state = _makeState(filterLevel: 2, searchQuery: 'hello');
      // filterLevel=2 excludes info (index=1), so filteredLogs is empty
      expect(state.filteredLogs, isEmpty);
      expect(state.filterLevel, 2);
      expect(state.searchQuery, 'hello');
    });

    test('copyWith should override specified fields', () {
      final state = _makeState(searchQuery: 'old', filterLevel: 1);
      final copied = state.copyWith(searchQuery: 'new');
      expect(copied.searchQuery, 'new');
      expect(copied.filterLevel, 1);
    });

    test('copyWith should preserve unspecified fields', () {
      _addEntry('warn', LogLevel.warning);
      final state = _makeState(searchQuery: 'q');
      final copied = state.copyWith(filterLevel: 3);
      // Both states read from the same service — log counts match
      expect(copied.filteredLogs.length, state.filteredLogs.length);
      expect(copied.searchQuery, 'q');
      expect(copied.filterLevel, 3);
    });

    test('copyWith filterLevel null should clear filter', () {
      final state = _makeState(filterLevel: 2);
      final copied = state.copyWith(filterLevel: null);
      expect(copied.filterLevel, isNull);
    });

    test('filteredLogs should return all logs when no filter', () {
      _addEntry('debug msg', LogLevel.debug);
      _addEntry('info msg', LogLevel.info);
      final state = _makeState();
      expect(state.filteredLogs, hasLength(2));
    });

    test('filteredLogs should filter by level', () {
      _addEntry('debug', LogLevel.debug);
      _addEntry('info', LogLevel.info);
      _addEntry('warning', LogLevel.warning);
      _addEntry('error', LogLevel.error);
      // filterLevel = 2 means LogLevel.warning and above
      final state = _makeState(filterLevel: 2);
      expect(state.filteredLogs, hasLength(2));
      expect(state.filteredLogs[0].level, LogLevel.warning);
      expect(state.filteredLogs[1].level, LogLevel.error);
    });

    test('filteredLogs should filter by search query', () {
      _addEntry('hello world', LogLevel.info);
      _addEntry('goodbye world', LogLevel.info);
      _addEntry('HELLO there', LogLevel.info);
      final state = _makeState(searchQuery: 'hello');
      // Should match "hello world" and "HELLO there" (case-insensitive)
      expect(state.filteredLogs, hasLength(2));
    });

    test('filteredLogs should filter by search in error', () {
      _addEntry('something failed', LogLevel.error,
          error: 'Connection refused');
      _addEntry('another failure', LogLevel.error, error: 'Timeout');
      final state = _makeState(searchQuery: 'connection');
      expect(state.filteredLogs, hasLength(1));
      expect(state.filteredLogs[0].message, 'something failed');
    });

    test('filteredLogs should combine level and search filters', () {
      _addEntry('debug test', LogLevel.debug);
      _addEntry('info test', LogLevel.info);
      _addEntry('warning other', LogLevel.warning);
      // filterLevel = 1 (info+), searchQuery = 'test'
      final state = _makeState(filterLevel: 1, searchQuery: 'test');
      expect(state.filteredLogs, hasLength(1));
      expect(state.filteredLogs[0].level, LogLevel.info);
    });

    test('filteredLogs should return empty when no matches', () {
      _addEntry('hello', LogLevel.info);
      final state = _makeState(searchQuery: 'nonexistent');
      expect(state.filteredLogs, isEmpty);
    });
  });

  group('LoggerNotifier', () {
    late ProviderContainer container;

    setUp(() {
      // Clear the singleton logger to avoid test pollution
      LoggerService().clear();
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should initialize with current logs', () {
      final state = container.read(loggerNotifierProvider);
      expect(state.filteredLogs, isA<List<LogEntry>>());
      expect(state.filterLevel, isNull);
      expect(state.searchQuery, '');
    });

    test('should log info message', () {
      final notifier = container.read(loggerNotifierProvider.notifier);

      notifier.info('test info message');

      final state = container.read(loggerNotifierProvider);
      expect(state.filteredLogs, isNotEmpty);
      expect(
        state.filteredLogs.any((e) => e.message == 'test info message'),
        isTrue,
      );
    });

    test('should log debug message', () {
      final notifier = container.read(loggerNotifierProvider.notifier);

      notifier.debug('test debug');

      final state = container.read(loggerNotifierProvider);
      final entry = state.filteredLogs.firstWhere(
        (e) => e.message == 'test debug',
      );
      expect(entry.level, LogLevel.debug);
    });

    test('should log warning message', () {
      final notifier = container.read(loggerNotifierProvider.notifier);

      notifier.warning('test warning');

      final state = container.read(loggerNotifierProvider);
      final entry = state.filteredLogs.firstWhere(
        (e) => e.message == 'test warning',
      );
      expect(entry.level, LogLevel.warning);
    });

    test('should log error message', () {
      final notifier = container.read(loggerNotifierProvider.notifier);

      notifier.error('test error');

      final state = container.read(loggerNotifierProvider);
      final entry = state.filteredLogs.firstWhere(
        (e) => e.message == 'test error',
      );
      expect(entry.level, LogLevel.error);
    });

    test('should log message with error and stacktrace', () async {
      final notifier = container.read(loggerNotifierProvider.notifier);

      notifier.error('failed', 'SomeException', StackTrace.empty);
      // Await microtask to allow the synchronous state update to propagate
      // through the Riverpod notifier before reading.
      await Future<void>.delayed(Duration.zero);

      final state = container.read(loggerNotifierProvider);
      final entry = state.filteredLogs.firstWhere(
        (e) => e.message == 'failed',
      );
      expect(entry.error, 'SomeException');
      expect(entry.stackTrace, StackTrace.empty);
    });

    test('should set filter level', () {
      final notifier = container.read(loggerNotifierProvider.notifier);

      notifier.setFilterLevel(2);

      final state = container.read(loggerNotifierProvider);
      expect(state.filterLevel, 2);
    });

    test('should clear filter level', () {
      final notifier = container.read(loggerNotifierProvider.notifier);

      notifier.setFilterLevel(3);
      expect(
        container.read(loggerNotifierProvider).filterLevel,
        3,
      );

      notifier.setFilterLevel(null);

      final state = container.read(loggerNotifierProvider);
      expect(state.filterLevel, isNull);
    });

    test('should set search query', () {
      final notifier = container.read(loggerNotifierProvider.notifier);

      notifier.setSearchQuery('my search');

      final state = container.read(loggerNotifierProvider);
      expect(state.searchQuery, 'my search');
    });

    test('should clear logs', () {
      final notifier = container.read(loggerNotifierProvider.notifier);

      notifier.info('message 1');
      notifier.info('message 2');
      expect(
        container.read(loggerNotifierProvider).filteredLogs,
        isNotEmpty,
      );

      notifier.clear();

      final state = container.read(loggerNotifierProvider);
      expect(state.filteredLogs, isEmpty);
    });

    test('should export logs as string', () {
      final notifier = container.read(loggerNotifierProvider.notifier);

      notifier.info('export me');

      final exported = notifier.exportLogs();
      expect(exported, contains('export me'));
    });

    test('should accumulate multiple log entries', () {
      final notifier = container.read(loggerNotifierProvider.notifier);

      notifier.info('first');
      notifier.warning('second');
      notifier.error('third');

      final state = container.read(loggerNotifierProvider);
      final messages =
          state.filteredLogs.map((e) => e.message).toList();
      expect(messages, contains('first'));
      expect(messages, contains('second'));
      expect(messages, contains('third'));
    });

    test('should handle log method with all levels', () {
      final notifier = container.read(loggerNotifierProvider.notifier);

      notifier.log('debug msg', level: LogLevel.debug);
      notifier.log('info msg', level: LogLevel.info);
      notifier.log('warn msg', level: LogLevel.warning);
      notifier.log('error msg', level: LogLevel.error);

      final state = container.read(loggerNotifierProvider);
      expect(
        state.filteredLogs
            .where((e) => e.message == 'debug msg')
            .first
            .level,
        LogLevel.debug,
      );
      expect(
        state.filteredLogs
            .where((e) => e.message == 'info msg')
            .first
            .level,
        LogLevel.info,
      );
      expect(
        state.filteredLogs
            .where((e) => e.message == 'warn msg')
            .first
            .level,
        LogLevel.warning,
      );
      expect(
        state.filteredLogs
            .where((e) => e.message == 'error msg')
            .first
            .level,
        LogLevel.error,
      );
    });
  });

  group('LoggerServiceProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should provide LoggerService instance', () {
      final service = container.read(loggerServiceProvider);
      expect(service, isA<LoggerService>());
    });
  });
}
