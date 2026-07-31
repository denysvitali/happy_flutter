import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/logger_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LogEntry', () {
    test('toFormattedString includes time, level, and message', () {
      final entry = LogEntry(
        timestamp: DateTime(2026, 3, 13, 10, 30, 45, 123),
        level: LogLevel.info,
        message: 'Hello world',
      );

      final formatted = entry.toFormattedString();
      expect(formatted, contains('[INFO   ]'));
      expect(formatted, contains('Hello world'));
      expect(formatted, contains('10:30:45.123'));
    });

    test('toFormattedString includes error when present', () {
      final entry = LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.error,
        message: 'Something failed',
        error: 'Network timeout',
      );

      final formatted = entry.toFormattedString();
      expect(formatted, contains('Error: Network timeout'));
    });

    test('toFormattedString includes stack trace when present', () {
      final stack = StackTrace.current;
      final entry = LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.error,
        message: 'Crash',
        stackTrace: stack,
      );

      final formatted = entry.toFormattedString();
      expect(formatted, contains('Stack trace:'));
    });

    test('toString delegates to toFormattedString', () {
      final entry = LogEntry(
        timestamp: DateTime(2026, 3, 13, 12, 0, 0, 0),
        level: LogLevel.debug,
        message: 'test',
      );

      expect(entry.toString(), equals(entry.toFormattedString()));
    });

    test('error is null by default', () {
      final entry = LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.info,
        message: 'msg',
      );

      expect(entry.error, isNull);
      expect(entry.stackTrace, isNull);
    });
  });

  group('LogLevel', () {
    test('values are in increasing severity order', () {
      expect(LogLevel.debug.index, lessThan(LogLevel.info.index));
      expect(LogLevel.info.index, lessThan(LogLevel.warning.index));
      expect(LogLevel.warning.index, lessThan(LogLevel.error.index));
    });

    test('has four levels', () {
      expect(LogLevel.values, hasLength(4));
    });
  });

  group('LoggerService', () {
    // Use the global logger singleton.
    // Sentry calls in _forwardToSentry are wrapped in try-catch
    // so they fail silently in test environments.
    final testLogger = logger;

    setUp(() {
      testLogger.clear();
      testLogger.setMinLevel(LogLevel.debug);
    });

    test('initial state can be empty after clear', () {
      expect(testLogger.count, equals(0));
      expect(testLogger.getLogs(), isEmpty);
    });

    test('log adds entry to buffer', () {
      testLogger.info('Test message');

      expect(testLogger.count, equals(1));
      expect(testLogger.getLogs().first.message, equals('Test message'));
      expect(testLogger.getLogs().first.level, equals(LogLevel.info));
    });

    test('log respects minimum level', () {
      testLogger.setMinLevel(LogLevel.warning);

      testLogger.debug('Debug msg');
      testLogger.info('Info msg');
      testLogger.warning('Warning msg');
      testLogger.error('Error msg');

      expect(testLogger.count, equals(2));
      expect(testLogger.getLogsByLevel(LogLevel.warning), hasLength(1));
      expect(testLogger.getLogsByLevel(LogLevel.error), hasLength(1));
    });

    test('debug convenience method logs at debug level', () {
      testLogger.debug('Debug message');

      expect(testLogger.getLogs().first.level, equals(LogLevel.debug));
    });

    test('info convenience method logs at info level', () {
      testLogger.info('Info message');

      expect(testLogger.getLogs().first.level, equals(LogLevel.info));
    });

    test('warning convenience method logs at warning level', () {
      testLogger.warning('Warning message');

      expect(testLogger.getLogs().first.level, equals(LogLevel.warning));
    });

    test('error convenience method logs at error level', () {
      testLogger.error('Error message');

      expect(testLogger.getLogs().first.level, equals(LogLevel.error));
    });

    test('error method includes error object', () {
      testLogger.error('Failed', 'socket exception');

      final entry = testLogger.getLogs().first;
      expect(entry.error, equals('socket exception'));
    });

    test('error method includes stack trace', () {
      final stack = StackTrace.current;
      testLogger.error('Failed', null, stack);

      final entry = testLogger.getLogs().first;
      expect(entry.stackTrace, equals(stack));
    });

    test('clear removes all logs', () {
      testLogger.info('Msg 1');
      testLogger.info('Msg 2');
      expect(testLogger.count, equals(2));

      testLogger.clear();

      expect(testLogger.count, equals(0));
      expect(testLogger.getLogs(), isEmpty);
    });

    test('getRecentLogs returns last N entries', () {
      for (var i = 0; i < 10; i++) {
        testLogger.info('Message $i');
      }

      final recent = testLogger.getRecentLogs(3);
      expect(recent, hasLength(3));
      expect(recent.last.message, equals('Message 9'));
      expect(recent.first.message, equals('Message 7'));
    });

    test('getRecentLogs returns all when N exceeds count', () {
      testLogger.info('Only one');

      final recent = testLogger.getRecentLogs(100);
      expect(recent, hasLength(1));
    });

    test('getLogsByLevel filters correctly', () {
      testLogger.debug('D1');
      testLogger.info('I1');
      testLogger.warning('W1');
      testLogger.error('E1');
      testLogger.info('I2');

      expect(testLogger.getLogsByLevel(LogLevel.debug), hasLength(1));
      expect(testLogger.getLogsByLevel(LogLevel.info), hasLength(2));
      expect(testLogger.getLogsByLevel(LogLevel.warning), hasLength(1));
      expect(testLogger.getLogsByLevel(LogLevel.error), hasLength(1));
    });

    test('circular buffer evicts oldest when exceeding 5000', () {
      for (var i = 0; i < 5001; i++) {
        testLogger.info('Message $i');
      }

      expect(testLogger.count, equals(5000));
      expect(
        testLogger.getLogs().first.message,
        equals('Message 1'),
      );
    });

    test('onChange listener is notified on new log', () {
      var callCount = 0;
      final unsubscribe = testLogger.onChange(() {
        callCount++;
      });

      testLogger.info('Test');
      expect(callCount, equals(1));

      testLogger.warning('Another');
      expect(callCount, equals(2));

      unsubscribe();
      testLogger.info('After unsub');
      expect(callCount, equals(2));
    });

    test('onChange listener is notified on clear', () {
      var clearNotified = false;
      testLogger.onChange(() {
        clearNotified = true;
      });

      testLogger.clear();
      expect(clearNotified, isTrue);
    });

    test('listener errors do not crash logger', () {
      testLogger.onChange(() {
        throw Exception('Listener error');
      });

      // Should not throw
      testLogger.info('Test');
      expect(testLogger.count, equals(1));
    });

    test('exportLogs returns formatted string', () {
      testLogger.info('First');
      testLogger.error('Second');

      final exported = testLogger.exportLogs();
      expect(exported, contains('First'));
      expect(exported, contains('Second'));
      expect(exported, contains('\n'));
    });

    test('exportLogsAsJson returns valid JSON array', () {
      testLogger.info('Test message');

      final jsonStr = testLogger.exportLogsAsJson();
      expect(jsonStr, startsWith('['));
      expect(jsonStr, endsWith(']'));
      expect(jsonStr, contains('"level":"info"'));
      expect(jsonStr, contains('"message":"Test message"'));
    });

    test('multiple listeners all get notified', () {
      var count1 = 0;
      var count2 = 0;
      testLogger.onChange(() => count1++);
      testLogger.onChange(() => count2++);

      testLogger.info('Test');

      expect(count1, equals(1));
      expect(count2, equals(1));
    });

    test('unsubscribe removes only the specific listener', () {
      var count1 = 0;
      var count2 = 0;
      final unsub1 = testLogger.onChange(() => count1++);
      testLogger.onChange(() => count2++);

      unsub1();
      testLogger.info('Test');

      expect(count1, equals(0));
      expect(count2, equals(1));
    });

    test('getLogs returns a copy', () {
      testLogger.info('Original');

      final logs = testLogger.getLogs();
      logs.clear();

      // Original should be unaffected
      expect(testLogger.count, equals(1));
    });
  });

  // Regression guard for the release-mode signal blackhole: `log()` used to
  // bail on `!shouldLog(level)` before reaching `_forwardToSentry` /
  // `_forwardToOtel`, so a shipped build with developer mode off exported
  // ONLY `LogLevel.error`. All ~400 `logger.warning` call sites produced
  // zero Sentry events and zero OTel log records.
  group('LoggerService release-mode telemetry export', () {
    final testLogger = logger;
    late List<LogEntry> forwarded;

    /// Entries the logger emits about its own Sentry transport are noise
    /// here — they are triggered asynchronously by the un-initialised
    /// Sentry hub in the test environment.
    List<String> exportedMessages() => forwarded
        .map((entry) => entry.message)
        .where((message) => !message.startsWith('[Sentry]'))
        .toList();

    setUp(() {
      forwarded = <LogEntry>[];
      testLogger
        ..clear()
        ..setMinLevel(LogLevel.debug)
        ..setDeveloperMode(false)
        ..installOtelSink(forwarded.add)
        ..debugReleaseModeOverride = true;
    });

    tearDown(() {
      testLogger
        ..removeOtelSink()
        ..debugReleaseModeOverride = null
        ..clear();
    });

    test('warning in a release build still reaches the forwarders', () {
      testLogger.warning('socket reconnect storm');

      expect(exportedMessages(), contains('socket reconnect storm'));
    });

    test('warning in a release build stays out of the ring buffer', () {
      testLogger.warning('socket reconnect storm');

      // Console/DevLogs noise suppression is preserved: only the export
      // path was ever supposed to be unconditional.
      expect(testLogger.getLogsByLevel(LogLevel.warning), isEmpty);
    });

    test('error in a release build is both buffered and forwarded', () {
      testLogger.error('decrypt failed');

      expect(exportedMessages(), contains('decrypt failed'));
      expect(testLogger.getLogsByLevel(LogLevel.error), hasLength(1));
    });

    test('debug and info in a release build are dropped entirely', () {
      testLogger
        ..debug('chatty')
        ..info('also chatty');

      expect(exportedMessages(), isEmpty);
      expect(testLogger.count, equals(0));
    });

    test('shouldLog admits warnings but not info in a release build', () {
      expect(testLogger.shouldLog(LogLevel.debug), isFalse);
      expect(testLogger.shouldLog(LogLevel.info), isFalse);
      expect(testLogger.shouldLog(LogLevel.warning), isTrue);
      expect(testLogger.shouldLog(LogLevel.error), isTrue);
    });

    test('minLevel still wins over the release export path', () {
      testLogger.setMinLevel(LogLevel.error);
      addTearDown(() => testLogger.setMinLevel(LogLevel.debug));

      testLogger.warning('suppressed by minLevel');

      expect(exportedMessages(), isEmpty);
      expect(testLogger.shouldLog(LogLevel.warning), isFalse);
    });

    test('developer mode restores full capture in a release build', () {
      testLogger.setDeveloperMode(true);
      addTearDown(() => testLogger.setDeveloperMode(false));

      testLogger.info('operational detail');

      expect(exportedMessages(), contains('operational detail'));
      expect(testLogger.getLogsByLevel(LogLevel.info), hasLength(1));
    });
  });

  // The release-mode forwarding fix (above) shipped with no bound on the
  // Sentry path: hot-loop warnings interpolate session ids, storage keys and
  // counts, so each occurrence became BOTH a billed event and a distinct
  // GlitchTip issue. `_forwardToSentry` now applies fingerprint dedup plus a
  // global token bucket.
  group('LoggerService Sentry emission policy', () {
    final testLogger = logger;
    late int fakeNowMs;

    setUp(() {
      fakeNowMs = 1000000;
      testLogger
        ..clear()
        ..setMinLevel(LogLevel.debug)
        ..setDeveloperMode(false)
        ..debugSentryClock = (() => fakeNowMs)
        ..debugResetSentryThrottle();
    });

    tearDown(() {
      testLogger
        ..debugSentryClock = null
        ..debugResetSentryThrottle()
        ..clear();
    });

    test('per-session warnings collapse to a single Sentry event', () {
      for (var i = 0; i < 40; i++) {
        testLogger.warning(
          '[fetchMessages] session-${i}aa11bb22cc33 dropped $i item(s)',
        );
      }

      expect(testLogger.debugSentryEmitCount, 1);
    });

    test('the same shape is re-sent after the cooldown', () {
      testLogger.warning('MMKV: Failed to save drafts[abc12345]: disk full');
      fakeNowMs += const Duration(minutes: 6).inMilliseconds;
      testLogger.warning('MMKV: Failed to save drafts[def67890]: disk full');

      expect(testLogger.debugSentryEmitCount, 2);
    });

    test('distinct shapes are capped by the token bucket', () {
      for (var i = 0; i < 100; i++) {
        testLogger.warning('unique warning shape ${_alphabet[i % 26]}$i x');
      }

      expect(testLogger.debugSentryEmitCount, lessThanOrEqualTo(20));
    });

    test('nanoid-style session ids collapse to a single Sentry event', () {
      // Real ids are mixed-case alphanumeric (neither hex nor digit-only).
      const ids = [
        'MtY7xKp2Qr9Zb3',
        'aB3kLm9Xz1Qw7T',
        'Zq8Vn2Ry6Hd4Lp',
        'Kf5Tg1Wb7Nc3Xs',
        'Pj9Dh4Yr2Mv8Qa',
      ];
      for (final id in ids) {
        testLogger.warning('[fetchMessages] $id dropped 3 item(s)');
      }

      expect(testLogger.debugSentryEmitCount, 1);
    });

    test('a backwards clock jump does not stall the token bucket', () {
      for (var i = 0; i < 100; i++) {
        testLogger.warning('drain shape ${_alphabet[i % 26]}$i x');
      }
      expect(testLogger.debugSentryEmitCount, 20);

      // NTP corrects a 30-minutes-fast device backwards.
      fakeNowMs -= const Duration(minutes: 30).inMilliseconds;
      testLogger.warning('post jump warning zzz');

      expect(testLogger.debugSentryEmitCount, 21);
    });

    test('errors are never throttled', () {
      for (var i = 0; i < 50; i++) {
        testLogger.error('identical failure');
      }

      expect(testLogger.debugSentryEmitCount, 50);
    });
  });

  // OTel export path: `[pipeline]` / `[messages]` debug traces fire per socket
  // frame, so two production launches shipped 21.4k and 19.3k debug records in
  // 24h (82% of all records) straight through the original 300/min ceiling.
  // Debug is bounded and then sampled; everything above it stays unthrottled.
  group('LoggerService OTel debug throttle', () {
    final testLogger = logger;
    late List<LogEntry> forwarded;
    late int fakeNowMs;

    List<LogEntry> exported() => forwarded
        .where((entry) => !entry.message.startsWith('[Sentry]'))
        .toList();

    setUp(() {
      forwarded = <LogEntry>[];
      fakeNowMs = 1000000;
      testLogger
        ..clear()
        ..setMinLevel(LogLevel.debug)
        ..setDeveloperMode(true)
        ..installOtelSink(forwarded.add)
        ..debugSentryClock = (() => fakeNowMs)
        ..debugResetOtelDebugThrottle()
        ..debugResetSentryThrottle();
    });

    tearDown(() {
      testLogger
        ..removeOtelSink()
        ..debugSentryClock = null
        ..debugResetOtelDebugThrottle()
        ..setDeveloperMode(false)
        ..clear();
    });

    test('debug export is capped once the bucket drains', () {
      for (var i = 0; i < 900; i++) {
        testLogger.debug('[pipeline] frame $i stage=notified outcome=ok');
      }

      final debugExports = exported()
          .where((entry) => entry.level == LogLevel.debug)
          .length;
      // 120 tokens of burst, then 1-in-25 of the remaining 780.
      expect(debugExports, 120 + 780 ~/ 25);
    });

    test('the overflow stream is sampled, not cut off', () {
      for (var i = 0; i < 900; i++) {
        testLogger.debug('[pipeline] frame $i');
      }

      // Records that made it out *after* the bucket drained: proof a long
      // burst still leaves a thread to pull on rather than a hole.
      final sampled = exported()
          .where((entry) => entry.level == LogLevel.debug)
          .skip(120)
          .toList();
      expect(sampled, isNotEmpty);
      expect(sampled.first.message, '[pipeline] frame 144');
    });

    test('the local ring buffer keeps full fidelity while export is capped', () {
      for (var i = 0; i < 900; i++) {
        testLogger.debug('[pipeline] frame $i');
      }

      // DevLogsScreen reads the ring buffer; only the OTel export is bounded.
      expect(testLogger.getLogsByLevel(LogLevel.debug).length, 900);
      expect(
        exported().where((entry) => entry.level == LogLevel.debug).length,
        lessThan(200),
      );
    });

    test('drops are reported, never silent', () {
      for (var i = 0; i < 900; i++) {
        testLogger.debug('[pipeline] frame $i');
      }

      expect(
        exported().map((entry) => entry.message),
        contains(startsWith('[logger] dropped ')),
      );
    });

    test('info, warning and error are never throttled by the debug bucket', () {
      for (var i = 0; i < 900; i++) {
        testLogger.debug('[pipeline] drain $i');
      }
      forwarded.clear();

      for (var i = 0; i < 50; i++) {
        testLogger
          ..info('info $i')
          ..warning('warning $i')
          ..error('error $i');
      }

      final byLevel = exported()
          .where((entry) => !entry.message.startsWith('[logger] dropped'))
          .toList();
      expect(byLevel.where((e) => e.level == LogLevel.info).length, 50);
      expect(byLevel.where((e) => e.level == LogLevel.warning).length, 50);
      expect(byLevel.where((e) => e.level == LogLevel.error).length, 50);
    });

    test('the bucket refills over time', () {
      for (var i = 0; i < 900; i++) {
        testLogger.debug('[pipeline] drain $i');
      }
      forwarded.clear();

      // One minute of refill at 60/min: 60 pass on tokens, the remaining 40
      // are overflow and contribute one sampled record (the 25th).
      fakeNowMs += const Duration(minutes: 1).inMilliseconds;
      for (var i = 0; i < 100; i++) {
        testLogger.debug('[pipeline] post-refill $i');
      }

      final debugExports = exported()
          .where((entry) => entry.level == LogLevel.debug)
          .length;
      expect(debugExports, 61);
    });

    test('a backwards clock jump does not wedge the debug bucket', () {
      for (var i = 0; i < 900; i++) {
        testLogger.debug('[pipeline] drain $i');
      }
      forwarded.clear();

      fakeNowMs -= const Duration(minutes: 30).inMilliseconds;
      testLogger.debug('[pipeline] post jump');

      expect(
        exported().where((entry) => entry.level == LogLevel.debug).length,
        1,
      );
    });
  });
}

const _alphabet = 'abcdefghijklmnopqrstuvwxyz';
