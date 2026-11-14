part of 'sessions_screen_tablet_split_test.dart';

Map<String, Session> _batchSessions() {
  // Quiet fixtures do not need the six-second fresh-activity pulse.
  final now = DateTime.now()
      .subtract(const Duration(minutes: 1))
      .millisecondsSinceEpoch;
  return {
    for (final name in ['Alpha one', 'Alpha two'])
      name: _session(name, activeAt: now).copyWith(
        metadata: Metadata(
          path: '/home/dev/app',
          summary: Summary(text: name, updatedAt: now),
        ),
      ),
  };
}

/// Records background session operations without touching the network.
class _RecordingSessionOperations extends SessionOperationsNotifier {
  final archived = <String>[];
  final deleted = <String>[];

  @override
  bool archive(Session session) {
    archived.add(session.id);
    return true;
  }

  @override
  bool delete(String sessionId) {
    deleted.add(sessionId);
    return true;
  }
}

Future<void> _openSelectionOnBoth(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
  await tester.longPress(find.text('Alpha one'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Select All'));
  await tester.pumpAndSettle();
  expect(find.text('2 selected'), findsOneWidget);
}

void _registerBatchActionTests() {
  _registerArchiveBatchTests();
  _registerDeleteBatchTests();
  _registerSelectionBackTests();
}

void _registerDeleteBatchTests() {
  testWidgets('batch delete leaves at once and never blocks the list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessions = _batchSessions();
    final recorder = _RecordingSessionOperations();
    await tester.pumpWidget(
      _app(
        sessions: sessions,
        viewStyle: 'status',
        sessionOperations: recorder,
      ),
    );
    await _openSelectionOnBoth(tester);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Delete'),
      ),
    );
    // One frame after confirmation: selection is gone and nothing is busy.
    await tester.pump();

    expect(recorder.deleted, unorderedEquals(sessions.keys));
    expect(find.byType(SessionSelectionAppBar), findsNothing);
    // A second action is immediately available: the list never gates input.
    await tester.longPress(find.text('Alpha one'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _registerArchiveBatchTests() {
  testWidgets('batch archive dispatches every row without waiting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessions = _batchSessions();
    final recorder = _RecordingSessionOperations();
    await tester.pumpWidget(
      _app(
        sessions: sessions,
        viewStyle: 'status',
        sessionOperations: recorder,
      ),
    );
    await _openSelectionOnBoth(tester);
    await tester.tap(find.byTooltip('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Archive'),
      ),
    );
    await tester.pump();

    // The first row is not awaited: both are handed over immediately.
    expect(recorder.archived, unorderedEquals(sessions.keys));
    expect(find.byType(SessionSelectionAppBar), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

void _registerSelectionBackTests() {
  for (final width in [390.0, 680.0]) {
    testWidgets('Back exits selection before its folder at width=$width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(sessions: _batchSessions(), viewStyle: 'folder'),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('app').first);
      await tester.pumpAndSettle();
      expect(find.byType(SessionFolderAppBar), findsOneWidget);
      await tester.longPress(find.text('Alpha one'));
      await tester.pumpAndSettle();
      expect(find.byType(SessionSelectionAppBar), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SessionSelectionAppBar), findsNothing);
      expect(find.byType(SessionFolderAppBar), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SessionFolderAppBar), findsNothing);
      expect(find.byType(SessionCollectionAppBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
