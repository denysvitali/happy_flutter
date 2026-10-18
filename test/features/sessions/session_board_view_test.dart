import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/session_ui_state_notifier.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_control_view.dart';
import 'package:happy_flutter/features/sessions/widgets/session_board_view.dart';

Session s(
  String id,
  String name,
  String path,
  String machine, {
  bool thinking = false,
  int ageMin = 5,
  AgentState? agent,
}) {
  final at = DateTime.now().millisecondsSinceEpoch - ageMin * 60000;
  return Session(
    id: id,
    seq: 1,
    createdAt: at,
    updatedAt: at,
    active: true,
    activeAt: at,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    presence: 'online',
    agentState: agent,
    metadata: Metadata(
      host: machine,
      path: path,
      machineId: machine,
      summary: Summary(text: name, updatedAt: at),
    ),
  );
}

Machine m(String id, bool online) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Machine(
    id: id,
    seq: 1,
    createdAt: now,
    updatedAt: now,
    active: online,
    activeAt: online ? now : now - 3600000,
    metadataVersion: 1,
    daemonStateVersion: 1,
    metadata: MachineMetadata(
      host: id,
      platform: 'linux',
      happyCliVersion: '1',
      happyHomeDir: '/h',
      homeDir: '/h',
    ),
  );
}

final _sessions = [
  s('a', 'fw-analyzer', '/home/d/git/fw-analyzer', 'phone', ageMin: 28),
  s(
    'b',
    'pmos-pixel7',
    '/home/d/git/pmos-pixel7',
    'phone',
    thinking: true,
    ageMin: 1,
  ),
  s('c', 'llm-proxy', '/home/d/git/llm-proxy', 'devbox', ageMin: 240),
  s('d', 'happy-cli-go', '/home/d/git/happy-cli-go', 'devbox', ageMin: 1020),
  s('e', 'gps-tracker', '/home/d/git/gps-tracker', 'laptop', ageMin: 1020),
  s('f', 'happy_flutter', '/home/d/git/happy_flutter', 'devbox', ageMin: 1021),
];

const _ui = SessionUiState(
  bySessionId: {
    'a': SessionUiEntry(lastMessageRole: 'agent', unreadCount: 2),
    'c': SessionUiEntry(
      lastMessagePreview: 'API error',
      lastMessageIsError: true,
    ),
  },
);

Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeHelper.buildDarkTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    ),
  );
  return captured;
}

Future<void> _pumpBoard(
  WidgetTester tester,
  List<SessionBoardSection> sections, {
  bool status = true,
  ThemeData? theme,
  double textScale = 1,
  ValueChanged<String>? onNewSession,
  ValueChanged<Set<String>>? onVisibleSessionIdsChanged,
  ValueChanged<String>? onOpenSession,
}) => tester.pumpWidget(
  MaterialApp(
    theme: theme ?? ThemeHelper.buildDarkTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: SessionBoardView(
        sections: sections,
        showStatusFilters: status,
        onNewSession: onNewSession,
        onVisibleSessionIdsChanged: onVisibleSessionIdsChanged,
        rowBuilder: (row) => TextButton(
          onPressed: () => onOpenSession?.call(row.session.id),
          child: Text('session ${row.session.id}'),
        ),
      ),
    ),
  ),
);

Finder _filter(String lane) => find.byKey(ValueKey('board-filter-$lane'));

Finder _header(String lane) => find.byKey(ValueKey('board-header-lane-$lane'));

Future<void> _tapVisibleBoardControl(
  WidgetTester tester,
  Finder control,
) async {
  await tester.ensureVisible(control);
  // Scrolling updates the layout on the next frame, including after the
  // expanded section changes the list's scroll extent.
  await tester.pumpAndSettle();
  expect(control.hitTestable(), findsOneWidget);
  await tester.tap(control);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('status board groups sessions by urgency lane', (tester) async {
    final context = await _context(tester);
    final sections = buildStatusBoardSections(context, _sessions, _ui);
    expect(sections.map((s) => s.key), [
      'lane-error',
      'lane-unread',
      'lane-live',
      'lane-quiet',
    ]);
    expect(sections.last.rows.map((r) => r.session.id), ['d', 'e', 'f']);
    expect(sections.expand((s) => s.rows).map((r) => r.session.id).toSet(), {
      'a',
      'b',
      'c',
      'd',
      'e',
      'f',
    });
  });

  testWidgets('machine board puts online machines first', (tester) async {
    final context = await _context(tester);
    final sections = buildMachineSections(context, _sessions, {
      'phone': m('phone', true),
      'devbox': m('devbox', true),
      'laptop': m('laptop', false),
    }, _ui);
    expect(sections.map((s) => s.key), [
      'machine-phone',
      'machine-devbox',
      'machine-laptop',
    ]);
    // Urgent rows lead inside a machine.
    expect(sections[1].rows.first.lane, MissionLane.error);
    expect(sections.last.subtitle, 'Offline · 1 session');
    expect(sections[1].subtitle, 'Online · 1 error');
    // Only online machines accept a new session.
    expect(sections.first.machineId, 'phone');
    expect(sections.last.machineId, isNull);
    expect(sections.last.dimmed, isTrue);
  });

  testWidgets('machine board lists idle online machines last', (tester) async {
    final context = await _context(tester);
    final sections = buildMachineSections(context, _sessions, {
      'phone': m('phone', true),
      'devbox': m('devbox', true),
      'spare': m('spare', true),
      'laptop': m('laptop', false),
    }, _ui);
    expect(sections.map((s) => s.key), [
      'machine-phone',
      'machine-devbox',
      'machine-spare',
      'machine-laptop',
    ]);
    expect(sections[2].rows, isEmpty);
    expect(sections[2].subtitle, 'Online · No active sessions');
  });

  testWidgets('seven quiet sessions need no filters or disclosure', (
    tester,
  ) async {
    final context = await _context(tester);
    final quiet = [
      for (var i = 0; i < 7; i++)
        s('q$i', 'quiet $i', '/w/q$i', 'devbox', ageMin: 10 + i),
    ];
    final sections = buildStatusBoardSections(
      context,
      quiet,
      const SessionUiState(),
    );
    await _pumpBoard(tester, sections);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('All clear'), findsNothing);
    expect(find.textContaining('Show'), findsNothing);
    for (var i = 0; i < 7; i++) {
      expect(find.text('session q$i'), findsOneWidget);
    }
    expect(tester.getTopLeft(find.text('session q0')).dy, lessThan(80));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('long quiet lane folds behind a footer after its rows', (
    tester,
  ) async {
    final context = await _context(tester);
    final quiet = [
      for (var i = 0; i < 13; i++)
        s('q$i', 'quiet $i', '/w/q$i', 'devbox', ageMin: 10 + i),
    ];
    final sections = buildStatusBoardSections(
      context,
      quiet,
      const SessionUiState(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeHelper.buildDarkTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SessionBoardView(
            sections: sections,
            rowBuilder: (row) => MissionActionRow(
              session: row.session,
              entry: row.entry,
              lane: row.lane,
              onTap: () {},
              onLongPress: () {},
              animateActivity: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('All clear'), findsNothing);
    expect(find.byType(MissionActionRow), findsNWidgets(10));
    expect(
      tester.getTopLeft(find.text('Show 3 more')).dy,
      greaterThan(tester.getBottomLeft(find.byType(MissionActionRow).last).dy),
    );
    await _tapVisibleBoardControl(tester, find.text('Show 3 more'));
    expect(find.byType(MissionActionRow), findsNWidgets(13));
    expect(find.text('Show less'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('status filters include counts and preserve row actions', (
    tester,
  ) async {
    final context = await _context(tester);
    final sections = buildStatusBoardSections(context, _sessions, _ui);
    String? opened;
    await _pumpBoard(tester, sections, onOpenSession: (id) => opened = id);
    expect(find.byType(ChoiceChip), findsNWidgets(5));
    expect(tester.getTopLeft(_filter('all')).dx, lessThan(32));
    expect(tester.getSemantics(_filter('all')).label, 'All, 6');
    expect(tester.getSemantics(_filter('live')).label, 'Working, 1');
    expect(find.text('All clear'), findsNothing);
    expect(_header('error'), findsOneWidget);
    expect(_header('unread'), findsOneWidget);
    expect(find.text('session b'), findsOneWidget);

    await tester.tap(_filter('live'));
    await tester.pump();
    expect(
      tester.getSemantics(_filter('live')).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(_header('quiet'), findsNothing);
    expect(find.text('session a'), findsNothing);
    expect(find.text('session b'), findsOneWidget);
    await tester.tap(find.text('session b'));
    expect(opened, 'b');
    await tester.tap(_filter('all'));
    await tester.pump();
    expect(find.text('session a'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('selected lane stays explicit when its last session changes', (
    tester,
  ) async {
    final context = await _context(tester);
    final sections = buildStatusBoardSections(context, _sessions, _ui);
    final changed = buildStatusBoardSections(context, [
      s('quiet', 'quiet', '/w/quiet', 'devbox'),
    ], const SessionUiState());
    await _pumpBoard(tester, sections);
    await tester.tap(_filter('live'));
    await tester.pump();
    await _pumpBoard(tester, changed);
    expect(tester.getSemantics(_filter('live')).label, 'Working, 0');
    expect(find.text('No sessions in Working'), findsOneWidget);
    expect(find.text('session a'), findsNothing);
    expect(find.text('All clear'), findsNothing);
    await tester.tap(find.text('Show all sessions'));
    await tester.pump();
    expect(_filter('live'), findsNothing);
    expect(find.text('session quiet'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('header controls expose disclosure and preserve quiet preview', (
    tester,
  ) async {
    final context = await _context(tester);
    final quiet = [
      for (var i = 0; i < 13; i++)
        s('q$i', 'quiet $i', '/w/q$i', 'devbox', ageMin: 10 + i),
    ];
    final sections = buildStatusBoardSections(
      context,
      quiet,
      const SessionUiState(),
    );
    await _pumpBoard(tester, sections);
    expect(
      tester.getSemantics(_header('quiet')).flagsCollection.isExpanded,
      Tristate.isTrue,
    );
    expect(find.text('session q10'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Show 3 more')).dy,
      greaterThan(tester.getBottomLeft(find.text('session q9')).dy),
    );
    await _tapVisibleBoardControl(tester, find.text('Show 3 more'));
    expect(find.text('session q12'), findsOneWidget);
    await _tapVisibleBoardControl(tester, find.text('Show less'));
    expect(find.text('session q10'), findsNothing);

    await _tapVisibleBoardControl(tester, _header('quiet'));
    expect(
      tester.getSemantics(_header('quiet')).flagsCollection.isExpanded,
      Tristate.isFalse,
    );
    expect(tester.getSemantics(_header('quiet')).label, 'Expand Quiet');
    expect(find.text('session q0'), findsNothing);
    expect(find.text('Show 3 more'), findsNothing);
    await _tapVisibleBoardControl(tester, _header('quiet'));
    expect(find.text('session q0'), findsOneWidget);
    expect(find.text('session q10'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('bulk selection IDs follow filters and include hidden rows', (
    tester,
  ) async {
    final context = await _context(tester);
    final sessions = [
      s('live', 'working', '/w/live', 'devbox', thinking: true),
      for (var i = 0; i < 13; i++)
        s('q$i', 'quiet', '/w/q$i', 'devbox', ageMin: 10 + i),
    ];
    final sections = buildStatusBoardSections(
      context,
      sessions,
      const SessionUiState(),
    );
    final reports = <Set<String>>[];
    await _pumpBoard(tester, sections, onVisibleSessionIdsChanged: reports.add);
    expect(reports, [sessions.map((session) => session.id).toSet()]);
    await tester.tap(_header('quiet'));
    await tester.pump();
    expect(reports, hasLength(1));
    await tester.tap(_filter('quiet'));
    await tester.pump();
    expect(reports.last, {for (var i = 0; i < 13; i++) 'q$i'});
    expect(find.text('session q0'), findsOneWidget);
    expect(find.text('session q12'), findsNothing);
    await tester.tap(_filter('live'));
    await tester.pump();
    expect(reports.last, {'live'});
    await tester.pump();
    expect(reports, hasLength(3));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('machine board keeps idle and occupied machine actions', (
    tester,
  ) async {
    final context = await _context(tester);
    final sections = buildMachineSections(
      context,
      [_sessions.first],
      {'phone': m('phone', true), 'spare': m('spare', true)},
      const SessionUiState(),
    );
    final launched = <String>[];
    await _pumpBoard(
      tester,
      sections,
      status: false,
      onNewSession: launched.add,
    );
    expect(find.byType(ChoiceChip), findsNothing);
    await tester.tap(find.byTooltip('New session on this machine'));
    await tester.tap(find.text('New session on this machine'));
    expect(launched, ['phone', 'spare']);
    expect(find.text('session a'), findsOneWidget);
    expect(
      tester.widget<ListView>(find.byType(ListView)).physics,
      isA<AlwaysScrollableScrollPhysics>(),
    );
    await tester.pumpWidget(const SizedBox());
  });

  for (final dark in [false, true]) {
    testWidgets('status controls fit 320px at 2x text, dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final context = await _context(tester);
      final sections = buildStatusBoardSections(context, [
        ..._sessions,
        s(
          'blocked',
          'needs approval',
          '/w/blocked',
          'devbox',
          agent: AgentState(
            requests: {'r': const RequestInfo(tool: 'Bash', createdAt: 1)},
          ),
        ),
      ], _ui);
      await _pumpBoard(
        tester,
        sections,
        textScale: 2,
        theme: dark
            ? ThemeHelper.buildDarkTheme()
            : ThemeHelper.buildLightTheme(),
      );
      expect(tester.takeException(), isNull);
      expect(_filter('quiet'), findsOneWidget);
      await tester.ensureVisible(_filter('quiet'));
      await tester.tap(_filter('quiet'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('session d'), findsOneWidget);
      await tester.tap(_header('quiet'));
      await tester.pump();
      expect(find.text('session d'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  test('short host keeps the user when the hostname is unset', () {
    expect(missionShortHost('root@(none) (go)'), 'root');
    expect(missionShortHost('root@OpenWrt (go)'), 'OpenWrt');
  });

  testWidgets('board renders headers and every row', (tester) async {
    final context = await _context(tester);
    final sections = buildStatusBoardSections(context, _sessions, _ui);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeHelper.buildDarkTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SessionBoardView(
            sections: sections,
            rowBuilder: (row) => MissionActionRow(
              session: row.session,
              entry: row.entry,
              lane: row.lane,
              onTap: () {},
              onLongPress: () {},
              animateActivity: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(MissionActionRow), findsNWidgets(6));
    expect(find.text('Quiet  3'), findsOneWidget);
    // Quiet rows show their age instead of repeating the lane name.
    expect(find.text('Quiet'), findsNothing);
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
