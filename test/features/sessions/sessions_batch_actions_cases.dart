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

class _StubArchiveApi extends SessionsApi {
  _StubArchiveApi(this.archive);
  final Future<void> Function(String, bool) archive;

  @override
  Future<void> setSessionArchived(String id, bool archived) =>
      archive(id, archived);
}

void _registerBatchActionTests() {
  _registerArchiveBatchTests();
  _registerSelectionBackTests();
  for (final (view, result, width) in [
    ('status', 0, 390.0),
    ('unread_focus', 1, 680.0),
    ('status', null, 390.0),
  ]) {
    testWidgets('batch delete keeps selection stable and recovers: '
        '$view, result=$result', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      try {
        final pending = Completer<int>();
        final captured = <List<String>>[];
        final sessions = _batchSessions();
        await tester.pumpWidget(
          _app(
            sessions: sessions,
            viewStyle: view,
            onBatchDelete: (ids) {
              captured.add(List.of(ids));
              return pending.future;
            },
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.longPress(find.text('Alpha one'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Select All'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Delete'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(TextButton, 'Delete'),
          ),
        );
        // Finish the dialog transition without settling the pending progress.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(find.byType(AlertDialog), findsNothing);

        expect(captured, hasLength(1));
        expect(captured.single, unorderedEquals(sessions.keys));
        final appBar = find.byType(SessionSelectionAppBar);
        expect(tester.widget<SessionSelectionAppBar>(appBar).busy, isTrue);
        expect(
          find.descendant(
            of: appBar,
            matching: find.byType(AppLinearProgressIndicator),
          ),
          findsOneWidget,
        );
        final buttons = tester.widgetList<IconButton>(
          find.descendant(of: appBar, matching: find.byType(IconButton)),
        );
        expect(buttons, isNotEmpty);
        expect(buttons.every((button) => button.onPressed == null), isTrue);
        final actions = tester.widgetList<TextButton>(
          find.descendant(of: appBar, matching: find.byType(TextButton)),
        );
        expect(actions, isNotEmpty);
        expect(actions.every((button) => button.onPressed == null), isTrue);
        expect(
          tester
              .widget<TextButton>(
                find.widgetWithText(TextButton, 'Deselect All'),
              )
              .onPressed,
          isNull,
        );
        final row = tester
            .getSemantics(
              find.ancestor(
                of: find.text('Alpha one'),
                matching: find.byType(MissionActionRow),
              ),
            )
            .getSemanticsData();
        expect(row.hasAction(SemanticsAction.tap), isFalse);
        expect(row.hasAction(SemanticsAction.longPress), isFalse);
        expect(row.hasAction(SemanticsAction.focus), isFalse);

        await tester.tap(find.text('Alpha one'), warnIfMissed: false);
        await tester.tap(find.byTooltip('Cancel'), warnIfMissed: false);
        if (view == 'status') {
          await tester.tap(
            find.byKey(const ValueKey('sessions-archived-scope')),
            warnIfMissed: false,
          );
        }
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.text('2 selected'), findsOneWidget);

        final list = tester.widget<SessionsListContent>(
          find.byType(SessionsListContent),
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SessionsScreen)),
        );
        // Optimistic removal and catalog updates must not edit the batch IDs.
        (container.read(sessionsNotifierProvider.notifier)
                as _StubSessionsNotifier)
            .publish({'Alpha two': sessions['Alpha two']!});
        await tester.pump();
        await tester.pump();
        expect(list.selectionNotifier.value.selectedIds, sessions.keys.toSet());
        expect(
          list.selectionNotifier.value.selectableIds,
          sessions.keys.toSet(),
        );
        expect(find.text('2 selected'), findsOneWidget);
        expect(captured, hasLength(1));

        if (result == null) {
          pending.completeError(StateError('delete unavailable'));
        } else {
          pending.complete(result);
        }
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(SessionSelectionAppBar), findsNothing);
        expect(list.selectionNotifier.value.isActive, isFalse);
        if (result != 0) {
          final l10n = tester.element(find.byType(SessionsScreen)).l10n;
          expect(
            find.text(
              l10n.sessionsDeletePartialFail(result ?? sessions.length),
            ),
            findsOneWidget,
          );
        }

        await tester.longPress(find.text('Alpha two'));
        await tester.pumpAndSettle();
        expect(find.text('1 selected'), findsOneWidget);
        expect(tester.widget<SessionSelectionAppBar>(appBar).busy, isFalse);
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton && widget.tooltip == 'Cancel',
                ),
              )
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
}

void _registerArchiveBatchTests() {
  for (final failSecond in [false, true]) {
    testWidgets('batch archive is sequential and refreshes after completion: '
        'partial=$failSecond', (tester) async {
      tester.view.physicalSize = Size(failSecond ? 680 : 390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final pending = Completer<void>();
      final captured = <String>[];
      final sessions = _batchSessions();
      await tester.pumpWidget(
        _app(
          sessions: sessions,
          viewStyle: 'status',
          sessionsApi: _StubArchiveApi((id, archived) async {
            expect(archived, isTrue);
            captured.add(id);
            final index = captured.length;
            if (index == 1) await pending.future;
            if (index == 2 && failSecond) {
              throw StateError('archive unavailable');
            }
          }),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.longPress(find.text('Alpha one'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Archive'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Archive'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      expect(captured, hasLength(1));
      expect(find.text('2 selected'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SessionsScreen)),
      );
      final notifier =
          container.read(sessionsNotifierProvider.notifier)
              as _StubSessionsNotifier;
      final refreshes = notifier.refreshCount;
      notifier.publish({'Alpha two': sessions['Alpha two']!});
      await tester.pump();
      await tester.pump();
      expect(find.text('2 selected'), findsOneWidget);
      pending.complete();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(captured, unorderedEquals(sessions.keys));
      expect(
        notifier.archivedIds,
        failSecond ? [captured.first] : unorderedEquals(sessions.keys),
      );
      expect(notifier.refreshCount, greaterThan(refreshes));
      expect(find.byType(SessionSelectionAppBar), findsNothing);
      if (failSecond) {
        final l10n = tester.element(find.byType(SessionsScreen)).l10n;
        expect(find.text(l10n.sessionsArchivePartialFail(1)), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
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
