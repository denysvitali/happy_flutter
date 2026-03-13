import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/services/http_request_logger.dart';
import 'package:happy_flutter/features/dev/network_inspector_screen.dart';

Widget _buildApp() {
  return const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: NetworkInspectorScreen(),
  );
}

HttpRequestEntry _makeEntry({
  int? id,
  String method = 'GET',
  String path = '/api/test',
  int? statusCode = 200,
  int? requestBytes = 128,
  int? responseBytes = 512,
  int? durationMs = 42,
}) {
  return HttpRequestEntry(
    id: id ?? httpRequestLogger.takeNextId(),
    timestamp: DateTime(2026, 3, 13, 10, 30),
    method: method,
    path: path,
    statusCode: statusCode,
    requestBytes: requestBytes,
    responseBytes: responseBytes,
    durationMs: durationMs,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    httpRequestLogger.clear();
  });

  group('NetworkInspectorScreen', () {
    testWidgets('shows empty state when no entries', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('No requests yet'), findsOneWidget);
      expect(find.byIcon(Icons.network_check), findsOneWidget);
    });

    testWidgets('displays request count in app bar', (tester) async {
      httpRequestLogger.record(_makeEntry(id: 1));
      httpRequestLogger.record(_makeEntry(id: 2, path: '/api/other'));

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(
        find.text('Network Inspector (2)'),
        findsOneWidget,
      );
    });

    testWidgets('shows summary bar with request stats', (tester) async {
      httpRequestLogger.record(_makeEntry(
        id: 1,
        requestBytes: 100,
        responseBytes: 200,
      ));

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Summary chips are present
      expect(find.text('Requests: '), findsOneWidget);
      expect(find.text('Sent: '), findsOneWidget);
      expect(find.text('Received: '), findsOneWidget);
    });

    testWidgets('renders request rows with method badge', (
      tester,
    ) async {
      httpRequestLogger.record(_makeEntry(
        id: 1,
        method: 'POST',
        path: '/api/create',
      ));

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('POST'), findsOneWidget);
      expect(find.text('/api/create'), findsOneWidget);
    });

    testWidgets('renders status code badge', (tester) async {
      httpRequestLogger.record(_makeEntry(
        id: 1,
        statusCode: 201,
      ));

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('201'), findsOneWidget);
    });

    testWidgets('renders null status as ???', (tester) async {
      httpRequestLogger.record(_makeEntry(
        id: 1,
        statusCode: null,
      ));

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('???'), findsOneWidget);
    });

    testWidgets('renders duration in ms', (tester) async {
      httpRequestLogger.record(_makeEntry(
        id: 1,
        durationMs: 150,
      ));

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('150ms'), findsOneWidget);
    });

    testWidgets('handles null duration gracefully', (tester) async {
      httpRequestLogger.record(_makeEntry(
        id: 1,
        durationMs: null,
      ));

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Should still render without crash
      expect(find.text('GET'), findsOneWidget);
    });

    testWidgets('shows copy button in app bar', (tester) async {
      httpRequestLogger.record(_makeEntry(id: 1));

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.copy), findsWidgets);
    });

    testWidgets('shows clear button in app bar', (tester) async {
      httpRequestLogger.record(_makeEntry(id: 1));

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_sweep), findsOneWidget);
    });

    testWidgets('copy and clear buttons disabled when empty', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      final copyBtn = tester.widget<IconButton>(
        find.byIcon(Icons.copy),
      );
      expect(copyBtn.onPressed, isNull);

      final clearBtn = tester.widget<IconButton>(
        find.byIcon(Icons.delete_sweep),
      );
      expect(clearBtn.onPressed, isNull);
    });

    testWidgets('shows copy box when entries exist', (tester) async {
      httpRequestLogger.record(_makeEntry(id: 1));

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('hides copy box when no entries', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // No copy box when empty
      expect(find.text('Copy'), findsNothing);
    });

    testWidgets('renders multiple entries with alternating colors', (
      tester,
    ) async {
      httpRequestLogger.record(_makeEntry(id: 1, path: '/a'));
      httpRequestLogger.record(_makeEntry(id: 2, path: '/b'));
      httpRequestLogger.record(_makeEntry(id: 3, path: '/c'));

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // All paths visible
      expect(find.text('/a'), findsOneWidget);
      expect(find.text('/b'), findsOneWidget);
      expect(find.text('/c'), findsOneWidget);
    });

    testWidgets('shows formatted byte sizes', (tester) async {
      httpRequestLogger.record(_makeEntry(
        id: 1,
        responseBytes: 2048,
      ));

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // 2048 bytes = 2.0KB
      expect(find.text('2.0KB'), findsOneWidget);
    });

    testWidgets('shows dashes for null byte values', (tester) async {
      httpRequestLogger.record(_makeEntry(
        id: 1,
        requestBytes: null,
        responseBytes: null,
      ));

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Should show '-' for null bytes
      expect(find.text('-'), findsWidgets);
    });

    testWidgets('tapping entry shows detail bottom sheet', (
      tester,
    ) async {
      httpRequestLogger.record(_makeEntry(
        id: 1,
        method: 'DELETE',
        path: '/api/item/5',
        statusCode: 204,
        durationMs: 99,
      ));

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('/api/item/5'));
      await tester.pumpAndSettle();

      // Detail sheet shows method badge
      expect(find.text('DELETE'), findsWidgets);
      // Duration detail
      expect(find.text('99 ms'), findsOneWidget);
      // Copy Entry button
      expect(find.text('Copy Entry'), findsOneWidget);
    });

    testWidgets('renders different HTTP methods with distinct colors', (
      tester,
    ) async {
      httpRequestLogger.record(_makeEntry(id: 1, method: 'GET'));
      httpRequestLogger.record(_makeEntry(id: 2, method: 'POST'));
      httpRequestLogger.record(_makeEntry(id: 3, method: 'PUT'));
      httpRequestLogger.record(_makeEntry(id: 4, method: 'PATCH'));
      httpRequestLogger.record(_makeEntry(id: 5, method: 'DELETE'));

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('GET'), findsOneWidget);
      expect(find.text('POST'), findsOneWidget);
      expect(find.text('PUT'), findsOneWidget);
      expect(find.text('PATCH'), findsOneWidget);
      expect(find.text('DELETE'), findsOneWidget);
    });
  });

  group('HttpRequestEntry.formatBytes', () {
    test('returns dash for null', () {
      expect(HttpRequestEntry.formatBytes(null), '-');
    });

    test('formats bytes under 1KB', () {
      expect(HttpRequestEntry.formatBytes(512), '512B');
    });

    test('formats kilobytes', () {
      expect(HttpRequestEntry.formatBytes(2048), '2.0KB');
    });

    test('formats megabytes', () {
      expect(
        HttpRequestEntry.formatBytes(1024 * 1024 * 3),
        '3.0MB',
      );
    });
  });

  group('HttpRequestEntry.toFormattedString', () {
    test('formats entry with all fields', () {
      final entry = HttpRequestEntry(
        id: 1,
        timestamp: DateTime(2026, 3, 13, 10, 30, 0),
        method: 'GET',
        path: '/api/test',
        statusCode: 200,
        requestBytes: 100,
        responseBytes: 500,
        durationMs: 50,
      );

      final str = entry.toFormattedString();
      expect(str, contains('GET'));
      expect(str, contains('200'));
      expect(str, contains('/api/test'));
    });

    test('formats entry with null fields', () {
      final entry = HttpRequestEntry(
        id: 1,
        timestamp: DateTime(2026, 3, 13, 10, 30, 0),
        method: 'POST',
        path: '/api/test',
      );

      final str = entry.toFormattedString();
      expect(str, contains('POST'));
      expect(str, contains('???'));
      expect(str, contains('/api/test'));
    });
  });
}
