import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/workflow_run.dart';
import 'package:happy_flutter/core/providers/workflows_notifier.dart';
import 'package:happy_flutter/core/repositories/workflows_repository.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/features/workflows/workflows_screen.dart';

import '../../helpers/test_helpers.dart';

const _sid = 's1';

class _FakeWorkflowsNotifier extends WorkflowsNotifier {
  _FakeWorkflowsNotifier(this._initial);
  final Map<String, List<WorkflowRun>> _initial;
  int refreshSessionCalls = 0;
  bool failRefresh = false;
  Completer<void>? pendingRefresh;
  int refreshFromSyncCalls = 0;

  @override
  Map<String, List<WorkflowRun>> build() => _initial;

  @override
  Future<void> refreshSession(String sessionId) async {
    refreshSessionCalls++;
    if (failRefresh) throw StateError('offline');
    await pendingRefresh?.future;
  }

  @override
  Future<void> refreshFromSync() async {
    refreshFromSyncCalls++;
  }
}

class _FakeRepo implements WorkflowsRepository {
  Map<String, List<WorkflowRun>> cached = const {};
  bool failRefresh = false;
  int refreshCalls = 0;
  @override
  Map<String, List<WorkflowRun>> get workflows => cached;
  @override
  Future<void> refreshRelevantSessions() async {}
  @override
  Future<void> refreshSession(String sessionId) async {
    refreshCalls++;
    if (failRefresh) throw StateError('repository unavailable');
  }

  @override
  Future<WorkflowRun?> fetchSnapshot(String sessionId, String runId) async =>
      null;
  @override
  bool isWorkflowListUnsupportedForSession(String sessionId) => false;
}

Widget _harness(Map<String, List<WorkflowRun>> initial) => ProviderScope(
  overrides: [
    workflowsNotifierProvider.overrideWith(
      () => _FakeWorkflowsNotifier(initial),
    ),
    workflowsRepositoryProvider.overrideWithValue(_FakeRepo()),
  ],
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: WorkflowsScreen(sessionId: _sid),
  ),
);

Future<_FakeWorkflowsNotifier> _notifierOf(WidgetTester tester) async =>
    ProviderScope.containerOf(
          tester.element(find.byType(WorkflowsScreen)),
        ).read(workflowsNotifierProvider.notifier)
        as _FakeWorkflowsNotifier;

void main() {
  final run = WorkflowRun(
    runId: 'wf_1',
    workflowName: 'sweep',
    status: 'completed',
    phases: const <WorkflowPhase>[WorkflowPhase(title: 'P')],
  );

  setUp(() {
    createTestSync()
      ..testIsInitialized = true
      ..testSetSessionMessages(_sid, const <Map<String, dynamic>>[]);
  });

  tearDown(() {
    Sync().testIsInitialized = false;
  });

  testWidgets('renders the runs from the notifier', (tester) async {
    await tester.pumpWidget(
      _harness({
        _sid: [run],
      }),
    );
    await tester.pump();

    expect(find.text('sweep'), findsOneWidget);
    // initState's microtask _refresh primes the visible session once.
    final n = await _notifierOf(tester);
    expect(n.refreshSessionCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed refresh retains runs and offers a working retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness({
        _sid: [run],
      }),
    );
    await tester.pump();
    final n = await _notifierOf(tester);
    n.failRefresh = true;

    await tester.tap(find.byIcon(Icons.refresh).first);
    await tester.pump();
    expect(find.text('sweep'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    n.failRefresh = false;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(n.refreshSessionCalls, 3);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('sweep'), findsOneWidget);
  });

  testWidgets('empty list can refresh and prevents duplicate requests', (
    tester,
  ) async {
    await tester.pumpWidget(_harness({}));
    await tester.pump();
    final n = await _notifierOf(tester);
    n.pendingRefresh = Completer<void>();

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    final refresh = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.refresh),
    );
    expect(refresh.onPressed, isNull);
    expect(n.refreshSessionCalls, 2);

    n.pendingRefresh!.complete();
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.refresh))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('uninitialized sync shows recovery instead of loading forever', (
    tester,
  ) async {
    Sync().testIsInitialized = false;
    await tester.pumpWidget(_harness({}));
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
    final n = await _notifierOf(tester);
    expect(n.refreshSessionCalls, 0);

    Sync().testIsInitialized = true;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(n.refreshSessionCalls, 1);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('real notifier surfaces repository failure and retains cache', (
    tester,
  ) async {
    final repository = _FakeRepo()
      ..cached = {
        _sid: [run],
      }
      ..failRefresh = true;
    final container = ProviderContainer(
      overrides: [workflowsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container.read(workflowsNotifierProvider.notifier).loadFromSync();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WorkflowsScreen(sessionId: _sid),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('sweep'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(repository.refreshCalls, 1);

    repository.failRefresh = false;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(repository.refreshCalls, 2);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('sweep'), findsOneWidget);
  });

  testWidgets('a message change debounces a refetch of this session', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness({
        _sid: [run],
      }),
    );
    await tester.pump();
    final n = await _notifierOf(tester);
    expect(n.refreshSessionCalls, 1);

    // Tick for THIS session: schedules the 1s-debounced refetch, not yet fired.
    Sync().testNotifySessionMessagesChanged(_sid);
    await tester.pump();
    expect(n.refreshSessionCalls, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(n.refreshSessionCalls, 2);

    // A tick for a DIFFERENT session is filtered out — no extra refetch.
    Sync().testNotifySessionMessagesChanged('other');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(n.refreshSessionCalls, 2);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dispose cancels the pending debounced refetch', (tester) async {
    await tester.pumpWidget(
      _harness({
        _sid: [run],
      }),
    );
    await tester.pump();
    final n = await _notifierOf(tester);
    expect(n.refreshSessionCalls, 1);

    Sync().testNotifySessionMessagesChanged(_sid);
    await tester.pump(); // timer scheduled but not fired
    await tester.pumpWidget(const SizedBox.shrink()); // dispose cancels it
    await tester.pump(const Duration(seconds: 1));

    expect(n.refreshSessionCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
