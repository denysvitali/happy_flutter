import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/session_ui_state_notifier.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_control_types.dart';
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
    expect(sections.last.subtitle, 'Offline');
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
    expect(find.text('QUIET'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
