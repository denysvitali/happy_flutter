import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/providers/logger_provider.dart';
import 'package:happy_flutter/core/services/logger_service.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('LoggerState', () {
    test('should create with default values', () {
      final state = LoggerState();
      expect(state.logs, isEmpty);
      expect(state.filterLevel, isNull);
      expect(state.searchQuery, '');
    });

    test('should create with provided values', () {
      final entry = LogEntry(
        timestamp: DateTime(2026, 1, 1),
        level: LogLevel.info,
        message: 'test',
      );
      final state = LoggerState(
        logs: [entry],
        filterLevel: 2,
        searchQuery: 'hello',
      );
      expect(state.logs, hasLength(1));
      expect(state.filterLevel, 2);
      expect(state.searchQuery, 'hello');
    });

    test('copyWith should override specified fields', () {
      final state = LoggerState(
        searchQuery: 'old',
        filterLevel: 1,
      );
      final copied = state.copyWith(searchQuery: 'new');
      expect(copied.searchQuery, 'new');
      expect(copied.filterLevel, 1);
    });

    test('copyWith should preserve unspecified fields', () {
      final entry = LogEntry(
        timestamp: DateTime(2026, 1, 1),
        level: LogLevel.warning,
        message: 'warn',
      );
      final state = LoggerState(logs: [entry], searchQuery: 'q');
      final copied = state.copyWith(filterLevel: 3);
      expect(copied.logs, state.logs);
      expect(copied.searchQuery, 'q');
      expect(copied.filterLevel, 3);
    });

    test('copyWith clearFilterLevel should set filter to null', () {
      final state = LoggerState(filterLevel: 2);
      final copied = state.copyWith(clearFilterLevel: true);
      expect(copied.filterLevel, isNull);
    });

    test('filteredLogs should return all logs when no filter', () {
      final logs = [
        LogEntry(
          timestamp: DateTime(2026, 1, 1),
          level: LogLevel.debug,
          message: 'debug msg',
        ),
        LogEntry(
          timestamp: DateTime(2026, 1, 1),
          level: LogLevel.info,
          message: 'info msg',
        ),
      ];
      final state = LoggerState(logs: logs);
      expect(state.filteredLogs, hasLength(2));
    });

    test('filteredLogs should filter by level', () {
      final logs = [
        LogEntry(
          timestamp: DateTime(2026, 1, 1),
          level: LogLevel.debug,
          message: 'debug',
        ),
        LogEntry(
          timestamp: DateTime(2026, 1, 1),
          level: LogLevel.info,
          message: 'info',
        ),
        LogEntry(
          timestamp: DateTime(2026, 1, 1),
          level: LogLevel.warning,
          message: 'warning',
        ),
        LogEntry(
          timestamp: DateTime(2026, 1, 1),
          level: LogLevel.error,
          message: 'error',
        ),
      ];
      // filterLevel = 2 means LogLevel.warning and above
      final state = LoggerState(logs: logs, filterLevel: 2);
      expect(state.filteredLogs, hasLength(2));
      expect(state.filteredLogs[0].level, LogLevel.warning);
      expect(state.filteredLogs[1].level, LogLevel.error);
    });

    test('filteredLogs should filter by search query', () {
      final logs = [
        LogEntry(
          timestamp: DateTime(2026, 1, 1),
          level: LogLevel.info,
          message: 'hello world',
        ),
        LogEntry(
          timestamp: DateTime(2026, 1, 1),
          level: LogLevel.info,
          message: 'goodbye world',
        ),
        LogEntry(
          timestamp: DateTime(2026, 1, 1),
          level: LogLevel.info,
          message: 'HELLO there',
        ),
      ];
      final state = LoggerState(logs: logs, searchQuery: 'hello');
      // Should match "hello world" and "HELLO there" (case-insensitive)
      expect(state.filteredLogs, hasLength(2));
    });

    test('filteredLogs should filter by search in error', () {
      final logs = [
        LogEntry(
          timestamp: DateTime(2026, 1, 1),
          level: LogLevel.error,
          message: 'something failed',
          error: 'Connection refused',
        ),
        LogEntry(
          timestamp: DateTime(2026, 1, 1),
          level: LogLevel.error,
          message: 'another failure',
          error: 'Timeout',
        ),
      ];
      final state = LoggerState(logs: logs, searchQuery: 'connection');
      expect(state.filteredLogs, hasLength(1));
      expect(state.filteredLogs[0].message, 'something failed');
    });

    test('filteredLogs should combine level and search filters', () {
      final logs = [
        LogEntry(
          timestamp: DateTime(2026, 1, 1),
          level: LogLevel.debug,
          message: 'debug test',
        ),
        LogEntry(
          timestamp: DateTime(2026, 1, 1),
          level: LogLevel.info,
          message: 'info test',
        ),
        LogEntry(
          timestamp: DateTime(2026, 1, 1),
          level: LogLevel.warning,
          message: 'warning other',
        ),
      ];
      // filterLevel = 1 (info+), searchQuery = 'test'
      final state = LoggerState(
        logs: logs,
        filterLevel: 1,
        searchQuery: 'test',
      );
      expect(state.filteredLogs, hasLength(1));
      expect(state.filteredLogs[0].level, LogLevel.info);
    });

    test('filteredLogs should return empty when no matches', () {
      final logs = [
        LogEntry(
          timestamp: DateTime(2026, 1, 1),
          level: LogLevel.info,
          message: 'hello',
        ),
      ];
      final state = LoggerState(logs: logs, searchQuery: 'nonexistent');
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
      expect(state.logs, isA<List<LogEntry>>());
      expect(state.filterLevel, isNull);
      expect(state.searchQuery, '');
    });

    test('should log info message', () {
      final notifier = container.read(loggerNotifierProvider.notifier);

      notifier.info('test info message');

      final state = container.read(loggerNotifierProvider);
      expect(state.logs, isNotEmpty);
      expect(
        state.logs.any((e) => e.message == 'test info message'),
        isTrue,
      );
    });

    test('should log debug message', () {
      final notifier = container.read(loggerNotifierProvider.notifier);

      notifier.debug('test debug');

      final state = container.read(loggerNotifierProvider);
      final entry = state.logs.firstWhere(
        (e) => e.message == 'test debug',
      );
      expect(entry.level, LogLevel.debug);
    });

    test('should log warning message', () {
      final notifier = container.read(loggerNotifierProvider.notifier);

      notifier.warning('test warning');

      final state = container.read(loggerNotifierProvider);
      final entry = state.logs.firstWhere(
        (e) => e.message == 'test warning',
      );
      expect(entry.level, LogLevel.warning);
    });

    test('should log error message', () {
      final notifier = container.read(loggerNotifierProvider.notifier);

      notifier.error('test error');

      final state = container.read(loggerNotifierProvider);
      final entry = state.logs.firstWhere(
        (e) => e.message == 'test error',
      );
      expect(entry.level, LogLevel.error);
    });

    test('should log message with error and stacktrace', () {
      final notifier = container.read(loggerNotifierProvider.notifier);

      notifier.error('failed', 'SomeException', StackTrace.empty);

      final state = container.read(loggerNotifierProvider);
      final entry = state.logs.firstWhere(
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
        container.read(loggerNotifierProvider).logs,
        isNotEmpty,
      );

      notifier.clear();

      final state = container.read(loggerNotifierProvider);
      expect(state.logs, isEmpty);
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
      final messages = state.logs.map((e) => e.message).toList();
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
        state.logs.where((e) => e.message == 'debug msg').first.level,
        LogLevel.debug,
      );
      expect(
        state.logs.where((e) => e.message == 'info msg').first.level,
        LogLevel.info,
      );
      expect(
        state.logs.where((e) => e.message == 'warn msg').first.level,
        LogLevel.warning,
      );
      expect(
        state.logs.where((e) => e.message == 'error msg').first.level,
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
