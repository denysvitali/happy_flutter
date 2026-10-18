// Pins the memoized list-item structure of the standard sessions list
// against its real inputs.
//
// `SessionsListContent._buildListItems` caches the whole `ListItem` list
// behind one signature. Every field the builder reads must be in that
// signature: presence drives the project header's active badge, the
// session path drives project/path grouping, and `updatedAt` drives the
// archived date bucket when no message timestamp exists. A field the
// output depends on but the key omits renders one entity's data under a
// stale grouping — the exact stale-render class this suite guards.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/performance_context_service.dart';
import 'package:happy_flutter/core/utils/session_utils.dart';
import 'package:happy_flutter/features/sessions/widgets/session_headers.dart';
import 'package:happy_flutter/features/sessions/widgets/session_list_helpers.dart';
import 'package:happy_flutter/features/sessions/widgets/sessions_list_content.dart';

class _StubSettingsNotifier extends SettingsNotifier {
  @override
  Settings build() => Settings()..sessionsViewStyle = 'list';
}

class _StubSessionsNotifier extends SessionsNotifier {
  _StubSessionsNotifier(this._initial);
  final Map<String, Session> _initial;

  @override
  Map<String, Session> build() => _initial;

  void replaceAll(Map<String, Session> sessions) {
    state = sessions;
  }
}

class _StubMachinesNotifier extends MachinesNotifier {
  @override
  Map<String, Machine> build() => const {};
}

class _StubSessionUiStateNotifier extends SessionUiStateNotifier {
  _StubSessionUiStateNotifier(this._initial);
  final SessionUiState _initial;

  @override
  SessionUiState build() => _initial;
}

int _minutesAgo(int minutes) =>
    DateTime.now().subtract(Duration(minutes: minutes)).millisecondsSinceEpoch;

int _daysAgo(int days) =>
    DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;

Session _session({
  required String id,
  required String name,
  required String path,
  required bool archived,
  required int at,
  String presence = 'offline',
}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: at - 1000,
    updatedAt: at,
    active: !archived,
    activeAt: archived ? at : _minutesAgo(1),
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    archived: archived,
    presence: presence,
    metadata: Metadata(
      host: 'devbox',
      machineId: 'm1',
      path: path,
      summary: Summary(text: name, updatedAt: at),
    ),
  );
}

/// Ui state with no message timestamps, so archived date grouping falls
/// back to the session's own `updatedAt`.
SessionUiState _uiStateFor(Map<String, Session> sessions) {
  return SessionUiState(
    bySessionId: {
      for (final session in sessions.values)
        session.id: const SessionUiEntry(lastMessageRole: 'assistant'),
    },
  );
}

class _Harness {
  _Harness(this.container);

  final ProviderContainer container;

  _StubSessionsNotifier get sessions =>
      container.read(sessionsNotifierProvider.notifier)
          as _StubSessionsNotifier;
}

Future<_Harness> _pumpHarness(
  WidgetTester tester,
  Map<String, Session> sessions,
) async {
  final performanceContext = PerformanceContextService()
    ..setCurrentRoute('sessions');
  addTearDown(performanceContext.resetForTesting);
  tester.view.physicalSize = const Size(500, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      settingsNotifierProvider.overrideWith(_StubSettingsNotifier.new),
      sessionsNotifierProvider.overrideWith(
        () => _StubSessionsNotifier(sessions),
      ),
      machinesNotifierProvider.overrideWith(_StubMachinesNotifier.new),
      sessionUiStateNotifierProvider.overrideWith(
        () => _StubSessionUiStateNotifier(_uiStateFor(sessions)),
      ),
    ],
  );
  final selection = ValueNotifier<SelectionState>(const SelectionState());
  final folder = ValueNotifier<SessionFolderHeader?>(null);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: SessionsListContent(
            selectionNotifier: selection,
            folderNotifier: folder,
            searchQuery: '',
          ),
        ),
      ),
      GoRoute(
        path: '/chat/:sessionId',
        name: 'chat',
        builder: (_, _) => const Scaffold(body: Text('chat')),
      ),
    ],
  );
  addTearDown(() {
    router.dispose();
    selection.dispose();
    folder.dispose();
    container.dispose();
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return _Harness(container);
}

void main() {
  testWidgets('project header active badge follows presence', (tester) async {
    final live = _session(
      id: 'alpha-1',
      name: 'Alpha one',
      path: '/home/dev/alpha',
      archived: false,
      at: _minutesAgo(2),
    );
    final harness = await _pumpHarness(tester, {live.id: live});

    expect(
      tester.widget<ProjectHeader>(find.byType(ProjectHeader)).activeCount,
      0,
    );

    harness.sessions.replaceAll({live.id: live.copyWith(presence: 'online')});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      tester.widget<ProjectHeader>(find.byType(ProjectHeader)).activeCount,
      1,
      reason: 'presence is a grouping input of the memoized list items',
    );
  });

  testWidgets('project grouping follows the session path', (tester) async {
    final live = _session(
      id: 'alpha-1',
      name: 'Alpha one',
      path: '/home/dev/alpha',
      archived: false,
      at: _minutesAgo(2),
    );
    final harness = await _pumpHarness(tester, {live.id: live});

    expect(
      tester.widget<ProjectHeader>(find.byType(ProjectHeader)).projectName,
      'alpha',
    );

    harness.sessions.replaceAll({
      live.id: live.copyWith(
        metadata: live.metadata!.copyWith(path: '/home/dev/beta'),
      ),
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      tester.widget<ProjectHeader>(find.byType(ProjectHeader)).projectName,
      'beta',
      reason: 'metadata.path is a grouping input of the memoized list items',
    );
  });

  testWidgets('archived date bucket follows updatedAt', (tester) async {
    final archived = _session(
      id: 'arch-1',
      name: 'Archived one',
      path: '/home/dev/alpha',
      archived: true,
      at: _daysAgo(3),
    );
    final harness = await _pumpHarness(tester, {archived.id: archived});

    expect(
      tester
          .widget<CollapsibleDateHeader>(find.byType(CollapsibleDateHeader))
          .date,
      'This Week',
    );

    harness.sessions.replaceAll({
      archived.id: archived.copyWith(updatedAt: _minutesAgo(3)),
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      tester
          .widget<CollapsibleDateHeader>(find.byType(CollapsibleDateHeader))
          .date,
      'Today',
      reason:
          'updatedAt is the date-group input when no message timestamp '
          'exists',
    );
  });
}
