import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/session_ui_state_notifier.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_control_types.dart';
import 'package:happy_flutter/features/sessions/widgets/session_board_view.dart';
import 'package:happy_flutter/features/sessions/widgets/sessions_view_style.dart';

Session _session(String id, {String? flavor, required int at}) {
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
    metadata: Metadata(
      host: 'devbox',
      path: '/home/d/git/$id',
      machineId: 'devbox',
      flavor: flavor,
      summary: Summary(text: id, updatedAt: at),
    ),
  );
}

Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
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
  const ui = SessionUiState(bySessionId: {});

  test('agent and recent layouts are board styles with stable wires', () {
    expect(SessionsViewStyle.fromWire('agent'), SessionsViewStyle.agent);
    expect(SessionsViewStyle.fromWire('recent'), SessionsViewStyle.recent);
    expect(SessionsViewStyle.agent.isBoard, isTrue);
    expect(SessionsViewStyle.recent.isBoard, isTrue);
    expect(SessionsViewStyle.statusBoard.isBoard, isTrue);
    expect(SessionsViewStyle.machines.isBoard, isTrue);
    expect(SessionsViewStyle.missionControl.isBoard, isFalse);
    expect(SessionsViewStyle.folder.isBoard, isFalse);
  });

  test('harness aliases collapse into one group key', () {
    expect(missionHarnessKey(null), 'claude');
    expect(missionHarnessKey('gemini'), missionHarnessKey('agy'));
    expect(missionHarnessKey('grok-build'), missionHarnessKey('grok'));
    expect(missionHarnessKey('codex'), 'codex');
  });

  testWidgets('agent board groups by harness, busiest first', (tester) async {
    final context = await _context(tester);
    final now = DateTime.now().millisecondsSinceEpoch;
    final sections = buildAgentSections(context, [
      _session('a', flavor: 'codex', at: now - 1000),
      _session('b', at: now - 2000),
      _session('c', flavor: 'codex', at: now - 3000),
      _session('d', flavor: 'gemini', at: now - 4000),
      _session('e', flavor: 'agy', at: now - 5000),
      _session('f', flavor: 'codex', at: now - 6000),
    ], ui);

    expect(sections.map((s) => s.key), [
      'agent-codex',
      'agent-agy',
      'agent-claude',
    ]);
    expect(sections.first.title, 'Codex');
    expect(sections.first.rows.map((r) => r.session.id), ['a', 'c', 'f']);
    expect(sections[1].rows.map((r) => r.session.id), ['d', 'e']);
    // Every session appears exactly once.
    expect(sections.expand((s) => s.rows).length, 6);
  });

  testWidgets('recent board buckets by last activity, newest first', (
    tester,
  ) async {
    final context = await _context(tester);
    final now = DateTime(2026, 11, 20, 12);
    int ago(Duration d) => now.subtract(d).millisecondsSinceEpoch;
    final sections = buildRecentSections(
      context,
      [
        _session('old', at: ago(const Duration(days: 60))),
        _session('today-late', at: ago(const Duration(minutes: 5))),
        _session('yesterday', at: ago(const Duration(hours: 30))),
        _session('today-early', at: ago(const Duration(hours: 3))),
        _session('week', at: ago(const Duration(days: 4))),
        _session('month', at: ago(const Duration(days: 12))),
      ],
      ui,
      now: now,
    );

    expect(sections.map((s) => s.key), [
      'recent-today',
      'recent-yesterday',
      'recent-thisWeek',
      'recent-thisMonth',
      'recent-older',
    ]);
    expect(sections.first.title, 'Today');
    expect(sections.first.rows.map((r) => r.session.id), [
      'today-late',
      'today-early',
    ]);
    expect(sections.last.rows.single.session.id, 'old');
  });
}
