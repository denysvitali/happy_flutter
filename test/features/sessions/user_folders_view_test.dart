// The "Folders" sessions layout: user folders with their sessions, unfiled
// sessions below, approval markers, collapse, and folders anchored at a
// session shown among its sub-sessions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/folders/session_folders_doc.dart';
import 'package:happy_flutter/core/folders/session_folders_envelope.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/performance_context_service.dart';
import 'package:happy_flutter/core/utils/session_utils.dart';
import 'package:happy_flutter/features/sessions/widgets/session_list_helpers.dart';
import 'package:happy_flutter/features/sessions/widgets/sessions_list_content.dart';
import 'package:happy_flutter/features/sessions/widgets/user_folder_row.dart';

class _Settings extends SettingsNotifier {
  @override
  Settings build() => Settings()..sessionsViewStyle = 'user_folders';
}

class _Sessions extends SessionsNotifier {
  _Sessions(this._initial);
  final Map<String, Session> _initial;

  @override
  Map<String, Session> build() => _initial;
}

class _Machines extends MachinesNotifier {
  @override
  Map<String, Machine> build() => const {};
}

class _Folders extends SessionFoldersNotifier {
  _Folders(this._state);
  final SessionFoldersState _state;

  @override
  SessionFoldersState build() => _state;
}

Session _s(String id, String name, {String? parent, bool permission = false}) {
  final at = DateTime.now().millisecondsSinceEpoch;
  return Session(
    id: id,
    seq: 1,
    createdAt: at,
    updatedAt: at,
    active: true,
    activeAt: at,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    presence: 'online',
    agentState: permission
        ? AgentState(requests: {'r': const RequestInfo(tool: 'Bash')})
        : null,
    metadata: Metadata(
      host: 'devbox',
      machineId: 'm1',
      path: '/home/dev/$id',
      parentSessionId: parent,
      summary: Summary(text: name, updatedAt: at),
    ),
  );
}

const _doc = FolderDoc(
  folders: {
    'fwork': SessionFolder(name: 'Work'),
    'fclient': SessionFolder(name: 'Client', parent: 'fwork'),
    'fempty': SessionFolder(name: 'Empty'),
    'fkids': SessionFolder(name: 'Kids', anchor: 'parent'),
  },
  sessions: {'parent': 'fwork', 'ask': 'fclient', 'kid1': 'fkids'},
);

Future<void> _pump(
  WidgetTester tester, {
  FolderAccess access = FolderAccess.ready,
}) async {
  final performance = PerformanceContextService()..setCurrentRoute('sessions');
  addTearDown(performance.resetForTesting);
  tester.view.physicalSize = const Size(500, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final sessions = {
    for (final s in [
      _s('parent', 'Parent task'),
      _s('kid1', 'Kid in folder', parent: 'parent'),
      _s('kid2', 'Kid unfiled', parent: 'parent'),
      _s('ask', 'Needs approval', permission: true),
      _s('lone', 'Lone session'),
    ])
      s.id: s,
  };
  final selection = ValueNotifier<SelectionState>(const SelectionState());
  final folder = ValueNotifier<SessionFolderHeader?>(null);
  addTearDown(selection.dispose);
  addTearDown(folder.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsNotifierProvider.overrideWith(_Settings.new),
        sessionsNotifierProvider.overrideWith(() => _Sessions(sessions)),
        machinesNotifierProvider.overrideWith(_Machines.new),
        sessionFoldersProvider.overrideWith(
          () => _Folders(
            SessionFoldersState(access: access, doc: _doc, loaded: true),
          ),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SessionsListContent(
            selectionNotifier: selection,
            folderNotifier: folder,
            searchQuery: '',
            onSessionTap: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('folders list their sessions; unfiled sessions follow', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Client'), findsOneWidget);
    expect(find.text('Empty'), findsOneWidget);
    expect(find.text('Parent task'), findsOneWidget);
    expect(find.text('Needs approval'), findsOneWidget);
    expect(find.text('Not in a folder'), findsOneWidget);
    expect(find.text('Lone session'), findsOneWidget);
    expect(find.text('New folder'), findsOneWidget);
    // Work holds Parent and (through Client) the approval session.
    final work = tester.widget<UserFolderRow>(
      find.widgetWithText(UserFolderRow, 'Work'),
    );
    expect(work.sessionCount, 2);
    expect(work.needsApproval, isTrue);
    final empty = tester.widget<UserFolderRow>(
      find.widgetWithText(UserFolderRow, 'Empty'),
    );
    expect(empty.needsApproval, isFalse);
    expect(empty.sessionCount, 0);
    // Subfolders come before a folder's sessions.
    expect(
      tester.getTopLeft(find.text('Client')).dy,
      lessThan(tester.getTopLeft(find.text('Parent task')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsing a folder hides its contents', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(find.text('Client'), findsNothing);
    expect(find.text('Parent task'), findsNothing);
    expect(find.text('Lone session'), findsOneWidget);
  });

  testWidgets('a session folder shows among its sub-sessions', (tester) async {
    await _pump(tester);
    expect(find.text('Kids'), findsNothing);
    await tester.tap(find.textContaining('sub-session'));
    await tester.pumpAndSettle();
    expect(find.text('Kids'), findsOneWidget);
    expect(find.text('Kid in folder'), findsOneWidget);
    expect(find.text('Kid unfiled'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Kids')).dy,
      lessThan(tester.getTopLeft(find.text('Kid in folder')).dy),
    );
  });

  testWidgets('a newer document is read-only', (tester) async {
    await _pump(tester, access: FolderAccess.readOnly);
    expect(
      find.textContaining('saved by a newer Happy version'),
      findsOneWidget,
    );
    final work = tester.widget<UserFolderRow>(
      find.widgetWithText(UserFolderRow, 'Work'),
    );
    expect(work.onAction, isNull);
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'New folder'),
    );
    expect(button.onPressed, isNull);
  });
}
