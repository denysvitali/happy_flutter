// ChangelogScreen: loading → entries / empty, and the per-entry metadata a
// reader depends on (type, scope, breaking marker, date).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/services/changelog_service.dart';
import 'package:happy_flutter/features/changelog/changelog_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Returns a canned result and records the range it was asked for.
class FakeChangelogService extends ChangelogService {
  FakeChangelogService(this._entries, {this.gate})
    : super(client: MockClient((_) async => http.Response('{}', 404)));

  final List<ChangelogEntry> _entries;
  final Future<void>? gate;

  final requestedRanges = <(String?, String)>[];

  @override
  Future<ChangelogResult> getChangelog({
    required String? fromVersion,
    required String toVersion,
  }) async {
    requestedRanges.add((fromVersion, toVersion));
    if (gate != null) await gate;
    return ChangelogResult(
      entries: _entries,
      fromVersion: fromVersion,
      toVersion: toVersion,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  Future<void> pumpScreen(
    WidgetTester tester,
    FakeChangelogService service, {
    String? fromVersion = '1.0.0',
    bool settle = true,
  }) async {
    container = ProviderContainer(
      overrides: [changelogServiceProvider.overrideWithValue(service)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChangelogScreen(fromVersion: fromVersion, toVersion: '1.1.0'),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  ChangelogEntry entry({
    String type = 'feat',
    String message = 'add the loops screen',
    String? scope,
    bool isBreaking = false,
    String date = '2026-08-01T10:00:00Z',
  }) {
    return ChangelogEntry(
      date: date,
      message: message,
      type: type,
      scope: scope,
      isBreaking: isBreaking,
    );
  }

  tearDown(() {
    container.dispose();
  });

  testWidgets('shows the loading indicator until the fetch resolves', (
    tester,
  ) async {
    final gate = Completer<void>();
    final service = FakeChangelogService([entry()], gate: gate.future);
    await pumpScreen(tester, service, settle: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('add the loops screen'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('add the loops screen'), findsOneWidget);
  });

  testWidgets('requests exactly the installed → current version range', (
    tester,
  ) async {
    final service = FakeChangelogService([entry()]);
    await pumpScreen(tester, service);

    expect(service.requestedRanges, [('1.0.0', '1.1.0')]);
  });

  testWidgets('first install passes a null previous version', (tester) async {
    final service = FakeChangelogService([entry()]);
    await pumpScreen(tester, service, fromVersion: null);

    expect(service.requestedRanges, [(null, '1.1.0')]);
  });

  testWidgets('empty changelog renders the empty state, not a list', (
    tester,
  ) async {
    await pumpScreen(tester, FakeChangelogService(const []));

    expect(find.text('No changelog entries available.'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('renders one row per entry with its type and message', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      FakeChangelogService([
        entry(message: 'add the loops screen'),
        entry(type: 'fix', message: 'stop the double send'),
        entry(type: 'chore', message: 'bump deps'),
      ]),
    );

    expect(find.text('add the loops screen'), findsOneWidget);
    expect(find.text('stop the double send'), findsOneWidget);
    expect(find.text('bump deps'), findsOneWidget);
    expect(find.text('feat'), findsOneWidget);
    expect(find.text('fix'), findsOneWidget);
    expect(find.text('chore'), findsOneWidget);
  });

  testWidgets('scope and breaking marker are rendered when present', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      FakeChangelogService([
        entry(scope: 'settings', message: 'keep the MCP row visible'),
        entry(type: 'fix', message: 'plain fix'),
        entry(
          type: 'feat',
          scope: 'api',
          message: 'drop the v1 endpoint',
          isBreaking: true,
        ),
      ]),
    );

    expect(find.text('settings'), findsOneWidget);
    expect(find.text('api'), findsOneWidget);
    expect(find.text('BREAKING'), findsOneWidget);
  });

  testWidgets('dates render as YYYY-MM-DD and unparsable dates degrade', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      FakeChangelogService([
        entry(date: '2026-08-01T10:00:00Z'),
        entry(type: 'fix', message: 'second', date: 'garbage'),
        entry(type: 'docs', message: 'third', date: ''),
      ]),
    );

    expect(find.text('2026-08-01'), findsOneWidget);
    expect(find.text('garbage'), findsOneWidget);
  });
}
