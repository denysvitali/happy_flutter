import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/logger_provider.dart';
import 'package:happy_flutter/core/services/logger_service.dart';
import 'package:happy_flutter/features/dev/dev_logs_screen.dart';

class _StorageFreeSettingsNotifier extends SettingsNotifier {
  _StorageFreeSettingsNotifier([this._initial]);

  final Settings? _initial;

  @override
  Settings build() => _initial ?? Settings();

  @override
  Future<void> updateSetting<T>(String key, T value) async {
    final json = state.toJson();
    json[key] = value;
    state = Settings.fromJson(json);
  }
}

/// Stub logger notifier that avoids touching the LoggerService singleton.
class _StubLoggerNotifier extends LoggerNotifier {
  _StubLoggerNotifier(this._seed);

  final LoggerState _seed;

  @override
  LoggerState build() => _seed;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

LoggerService get _svc => LoggerService();

/// Clears the singleton service, inserts [logs] entries directly (bypassing
/// Sentry forwarding), and returns a [LoggerState] backed by the singleton.
LoggerState _stateWith(
  List<LogEntry> logs, {
  int? filterLevel,
  String searchQuery = '',
}) {
  _svc.clear();
  for (final e in logs) {
    _svc.insertEntry(e);
  }
  return LoggerState(
    service: _svc,
    version: _svc.version,
    filterLevel: filterLevel,
    searchQuery: searchQuery,
  );
}

LoggerState _emptyState() {
  _svc.clear();
  return LoggerState(service: _svc, version: _svc.version);
}

// ---------------------------------------------------------------------------

Widget _buildApp({
  required Settings settings,
  LoggerState? loggerState,
  bool requireDeveloperMode = true,
}) {
  return ProviderScope(
    overrides: [
      settingsNotifierProvider.overrideWith(
        () => _StorageFreeSettingsNotifier(settings),
      ),
      if (loggerState != null)
        loggerNotifierProvider.overrideWith(
          () => _StubLoggerNotifier(loggerState),
        ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DevLogsScreen(requireDeveloperMode: requireDeveloperMode),
    ),
  );
}

Settings _makeSettings({bool developerModeEnabled = false}) {
  final s = Settings();
  s.developerModeEnabled = developerModeEnabled;
  return s;
}

LogEntry _makeLogEntry({
  LogLevel level = LogLevel.info,
  String message = 'Test log message',
  DateTime? timestamp,
}) {
  return LogEntry(
    timestamp: timestamp ?? DateTime(2026, 3, 13, 10, 30),
    level: level,
    message: message,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DevLogsScreen', () {
    setUp(() => _svc.clear());

    testWidgets('shows disabled message when developer mode is off', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          settings: _makeSettings(developerModeEnabled: false),
          loggerState: _emptyState(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Logs'), findsOneWidget);
      expect(
        find.textContaining('Logs are only available'),
        findsOneWidget,
      );
    });

    testWidgets('can show logs without developer mode when explicitly allowed',
        (tester) async {
      final logs = [_makeLogEntry(message: 'Startup failed')];

      await tester.pumpWidget(
        _buildApp(
          settings: _makeSettings(developerModeEnabled: false),
          loggerState: _stateWith(logs),
          requireDeveloperMode: false,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Startup failed'), findsOneWidget);
      expect(find.textContaining('Logs are only available'), findsNothing);
    });

    testWidgets('shows log list when developer mode is on', (tester) async {
      final logs = [
        _makeLogEntry(message: 'First log'),
        _makeLogEntry(
          level: LogLevel.error,
          message: 'Error log',
        ),
      ];

      await tester.pumpWidget(
        _buildApp(
          settings: _makeSettings(developerModeEnabled: true),
          loggerState: _stateWith(logs),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('First log'), findsOneWidget);
      expect(find.text('Error log'), findsOneWidget);
    });

    testWidgets('shows empty state when no logs', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          settings: _makeSettings(developerModeEnabled: true),
          loggerState: _emptyState(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('No logs yet'), findsOneWidget);
      expect(find.byIcon(Icons.note_alt_outlined), findsOneWidget);
    });

    testWidgets('displays log count in app bar', (tester) async {
      final logs = [
        _makeLogEntry(message: 'Log 1'),
        _makeLogEntry(message: 'Log 2'),
        _makeLogEntry(message: 'Log 3'),
      ];

      await tester.pumpWidget(
        _buildApp(
          settings: _makeSettings(developerModeEnabled: true),
          loggerState: _stateWith(logs),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Logs (3)'), findsWidgets);
    });

    testWidgets('shows filter bar with count', (tester) async {
      final logs = [_makeLogEntry(message: 'Some log')];

      await tester.pumpWidget(
        _buildApp(
          settings: _makeSettings(developerModeEnabled: true),
          loggerState: _stateWith(logs),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Filter bar shows count
      expect(find.text('Logs (1)'), findsWidgets);
    });

    testWidgets('shows filtered count when filter is active', (
      tester,
    ) async {
      final logs = [
        _makeLogEntry(level: LogLevel.info, message: 'Info log'),
        _makeLogEntry(level: LogLevel.error, message: 'Error log'),
      ];

      await tester.pumpWidget(
        _buildApp(
          settings: _makeSettings(developerModeEnabled: true),
          loggerState: _stateWith(
            logs,
            filterLevel: LogLevel.error.index,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Logs (1 filtered)'), findsOneWidget);
      expect(find.text('Clear Filter'), findsOneWidget);
    });

    testWidgets('shows action buttons in app bar', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          settings: _makeSettings(developerModeEnabled: true),
          loggerState: _emptyState(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Add test log button
      expect(find.byIcon(Icons.add), findsOneWidget);
      // Copy button
      expect(find.byIcon(Icons.copy), findsOneWidget);
      // Clear button
      expect(find.byIcon(Icons.delete_sweep), findsOneWidget);
      // Filter button
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
      // Search button
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('LogEntryWidget shows level indicator', (tester) async {
      final entry = _makeLogEntry(
        level: LogLevel.warning,
        message: 'Warning message',
      );

      await tester.pumpWidget(
        _buildApp(
          settings: _makeSettings(developerModeEnabled: true),
          loggerState: _stateWith([entry]),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Level indicator text
      expect(find.text('WARNING'), findsOneWidget);
      // Message
      expect(find.text('Warning message'), findsOneWidget);
    });

    testWidgets('LogEntryWidget shows error icon for error entries', (
      tester,
    ) async {
      final entry = LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.error,
        message: 'Something failed',
        error: Exception('test error'),
      );

      await tester.pumpWidget(
        _buildApp(
          settings: _makeSettings(developerModeEnabled: true),
          loggerState: _stateWith([entry]),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Error icon shown for entries with error
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('LogListView shows entries in reverse order', (
      tester,
    ) async {
      final logs = [
        _makeLogEntry(message: 'First'),
        _makeLogEntry(message: 'Second'),
        _makeLogEntry(message: 'Third'),
      ];

      await tester.pumpWidget(
        _buildApp(
          settings: _makeSettings(developerModeEnabled: true),
          loggerState: _stateWith(logs),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Most recent at bottom, so last entry appears first
      // in the ListView.builder (reversed index)
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('Third'), findsOneWidget);
    });

    testWidgets('tapping log entry shows detail bottom sheet', (
      tester,
    ) async {
      final entry = _makeLogEntry(
        level: LogLevel.info,
        message: 'Detail test log',
      );

      await tester.pumpWidget(
        _buildApp(
          settings: _makeSettings(developerModeEnabled: true),
          loggerState: _stateWith([entry]),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Detail test log'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Bottom sheet should show level name
      expect(find.text('INFO'), findsWidgets);
      // Copy Entry button in bottom sheet
      expect(find.text('Copy Entry'), findsOneWidget);
    });

    testWidgets('displays all log levels correctly', (tester) async {
      final logs = [
        _makeLogEntry(level: LogLevel.debug, message: 'Debug msg'),
        _makeLogEntry(level: LogLevel.info, message: 'Info msg'),
        _makeLogEntry(level: LogLevel.warning, message: 'Warn msg'),
        _makeLogEntry(level: LogLevel.error, message: 'Error msg'),
      ];

      await tester.pumpWidget(
        _buildApp(
          settings: _makeSettings(developerModeEnabled: true),
          loggerState: _stateWith(logs),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('DEBUG'), findsOneWidget);
      expect(find.text('INFO'), findsOneWidget);
      expect(find.text('WARNING'), findsOneWidget);
      expect(find.text('ERROR'), findsOneWidget);
    });
  });
}
