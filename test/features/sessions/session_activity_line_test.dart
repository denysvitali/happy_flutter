import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/features/sessions/widgets/active_session_card.dart';
import 'package:happy_flutter/features/sessions/widgets/session_cards.dart';

/// Finding 1: a session card must say what the session is doing —
/// the running tool when the agent is working, the last message
/// otherwise, and nothing at all when neither is known.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpCard(
    WidgetTester tester,
    Session session, {
    String? preview,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ActiveSessionCard(
            session: session,
            showFlavorIcon: false,
            lastMessagePreview: preview,
            lastMessageRole: 'agent',
          ),
        ),
      ),
    );
  }

  testWidgets('shows the pending tool when approval is required', (
    tester,
  ) async {
    final session = _session(
      id: 'act-1',
      path: '/home/project',
      thinking: true,
      agentState: AgentState(
        requests: {
          'r1': const RequestInfo(tool: 'Bash', createdAt: 20),
          'r0': const RequestInfo(tool: 'Read', createdAt: 10),
        },
      ),
    );

    await pumpCard(tester, session, preview: 'older chatter');

    expect(find.text('Bash needs approval'), findsOneWidget);
    expect(find.text('older chatter'), findsNothing);
  });

  testWidgets('shows the running tool while the agent is thinking', (
    tester,
  ) async {
    final session = _session(
      id: 'act-2',
      path: '/home/project',
      thinking: true,
      agentState: AgentState(
        completedRequests: {
          'c0': const CompletedRequestInfo(
            tool: 'Read',
            status: 'done',
            createdAt: 5,
          ),
          'c1': const CompletedRequestInfo(
            tool: 'Edit',
            status: 'done',
            createdAt: 50,
          ),
        },
      ),
    );

    await pumpCard(tester, session);

    expect(find.text('Running Edit'), findsOneWidget);
  });

  testWidgets('falls back to a generic working label with no tool', (
    tester,
  ) async {
    final session = _session(id: 'act-3', path: '/p', thinking: true);

    await pumpCard(tester, session);

    expect(find.text('Working…'), findsOneWidget);
  });

  testWidgets('falls back to the last message when idle', (tester) async {
    final session = _session(id: 'act-4', path: '/p');

    await pumpCard(tester, session, preview: 'all done here');

    expect(
      find.textContaining('all done here', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('renders no activity line when nothing is known', (
    tester,
  ) async {
    final session = _session(id: 'act-5', path: '/home/quiet');

    await pumpCard(tester, session);

    expect(find.text('Working…'), findsNothing);
    // Only the project subtitle remains.
    expect(find.textContaining('quiet'), findsWidgets);
  });

  testWidgets('getSessionActivity returns null for an idle session', (
    tester,
  ) async {
    SessionActivity? activity;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            activity = getSessionActivity(
              context,
              _session(id: 'act-6', path: '/p'),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(activity, isNull);
  });
}

Session _session({
  required String id,
  required String path,
  bool thinking = false,
  AgentState? agentState,
}) {
  return Session(
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
    agentState: agentState,
    metadata: Metadata(host: 'localhost', path: path),
  );
}
