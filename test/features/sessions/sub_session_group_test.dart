import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/utils/session_nesting.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';
import 'package:happy_flutter/features/chat/widgets/sub_session_links.dart';
import 'package:happy_flutter/features/sessions/widgets/sub_session_group.dart';

Session _s(
  String id, {
  String? title,
  String? parent,
  bool thinking = false,
  bool permission = false,
}) => Session(
  id: id,
  seq: 1,
  createdAt: 1,
  updatedAt: 1,
  active: true,
  activeAt: 1,
  metadataVersion: 1,
  agentStateVersion: 1,
  thinking: thinking,
  presence: 'online',
  agentState: permission
      ? AgentState(requests: {'r': const RequestInfo(tool: 'Bash')})
      : null,
  metadata: Metadata(
    path: '/w/$id',
    parentSessionId: parent,
    summary: title == null ? null : Summary(text: title, updatedAt: 1),
  ),
);

class _StubSessions extends SessionsNotifier {
  _StubSessions(this.initial);

  final Map<String, Session> initial;

  @override
  Map<String, Session> build() => initial;

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync({bool includeMachines = false}) async {}
}

Widget _app(Widget child, {Map<String, Session> sessions = const {}}) =>
    ProviderScope(
      overrides: [
        sessionsNotifierProvider.overrideWith(() => _StubSessions(sessions)),
      ],
      child: MaterialApp(
        theme: ThemeHelper.buildLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

/// Mirrors the list's recursive row builder with plain text rows.
Widget _tree(
  SessionNesting nesting,
  Session session,
  Set<String> expanded,
  void Function(String) toggle,
) => SubSessionGroup(
  parent: session,
  parentRow: Text('row:${session.id}'),
  children: nesting.childrenOf(session.id),
  summary: nesting.summaryOf(session.id),
  expanded: expanded.contains(session.id),
  onToggle: () => toggle(session.id),
  childBuilder: (child) => _tree(nesting, child, expanded, toggle),
);

void main() {
  testWidgets('disclosure expands multi-level children once each', (
    tester,
  ) async {
    final nesting = SessionNesting.build([
      _s('root'),
      _s('c1', parent: 'root', thinking: true),
      _s('g1', parent: 'c1', permission: true),
      _s('c2', parent: 'root'),
    ]);
    final expanded = <String>{};
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              for (final s in nesting.topLevel)
                _tree(
                  nesting,
                  s,
                  expanded,
                  (id) => setState(
                    () => expanded.contains(id)
                        ? expanded.remove(id)
                        : expanded.add(id),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('row:root'), findsOneWidget);
    expect(find.text('row:c1'), findsNothing);
    expect(
      find.textContaining('3 sub-sessions · 1 needs you · 1 working'),
      findsOneWidget,
    );

    await tester.tap(find.byType(SubSessionDisclosure));
    await tester.pumpAndSettle();
    expect(find.text('row:c1'), findsOneWidget);
    expect(find.text('row:c2'), findsOneWidget);
    expect(find.text('row:g1'), findsNothing);

    // c1's own disclosure reveals the grandchild.
    await tester.tap(find.textContaining('1 sub-session'));
    await tester.pumpAndSettle();
    expect(find.text('row:g1'), findsOneWidget);

    await tester.tap(find.byType(SubSessionDisclosure).first);
    await tester.pumpAndSettle();
    expect(find.text('row:c1'), findsNothing);
    expect(find.text('row:g1'), findsNothing);
  });

  testWidgets('a session without children renders only its row', (
    tester,
  ) async {
    final nesting = SessionNesting.build([_s('solo')]);
    await tester.pumpWidget(
      _app(_tree(nesting, nesting.topLevel.single, {}, (_) {})),
    );
    expect(find.text('row:solo'), findsOneWidget);
    expect(find.byType(SubSessionDisclosure), findsNothing);
  });

  testWidgets('sub-session badge is labelled', (tester) async {
    await tester.pumpWidget(_app(const SubSessionBadge()));
    expect(find.text('Sub-session'), findsOneWidget);
  });

  testWidgets('parent banner names the parent; top-level shows none', (
    tester,
  ) async {
    final sessions = {
      'p': _s('p', title: 'Release train'),
      'c': _s('c', parent: 'p'),
      'lost': _s('lost', parent: 'missing'),
    };
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            ParentSessionBanner(sessionId: 'c'),
            ParentSessionBanner(sessionId: 'p'),
            ParentSessionBanner(sessionId: 'lost'),
          ],
        ),
        sessions: sessions,
      ),
    );
    expect(find.text('Sub-session of Release train'), findsOneWidget);
    expect(
      find.text('Sub-session of a session that is not loaded'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
  });

  testWidgets('session info lists sub-sessions with their state', (
    tester,
  ) async {
    final sessions = {
      'p': _s('p', title: 'Parent'),
      'a': _s('a', title: 'Writer', parent: 'p', thinking: true),
      'b': _s('b', title: 'Reviewer', parent: 'p', permission: true),
    };
    await tester.pumpWidget(
      _app(SessionNestingSections(session: sessions['p']!), sessions: sessions),
    );
    expect(find.text('Sub-sessions'), findsOneWidget);
    expect(find.text('Writer'), findsOneWidget);
    expect(find.text('Working'), findsOneWidget);
    expect(find.text('Reviewer'), findsOneWidget);
    expect(find.text('Needs approval'), findsOneWidget);
    expect(find.text('Spawned by'), findsNothing);

    await tester.pumpWidget(
      _app(SessionNestingSections(session: sessions['a']!), sessions: sessions),
    );
    expect(find.text('Spawned by'), findsOneWidget);
    expect(find.text('Parent'), findsOneWidget);
  });
}
