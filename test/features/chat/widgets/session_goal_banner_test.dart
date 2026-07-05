import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/chat/widgets/session_goal_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionGoalBanner', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          sessionsNotifierProvider.overrideWith(_TestSessionsNotifier.new),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    Widget wrap(Widget child) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: Column(children: [child])),
        ),
      );
    }

    Session session(String id, {CodexGoal? goal}) {
      return Session(
        id: id,
        seq: 1,
        createdAt: 1,
        updatedAt: 1,
        active: true,
        activeAt: 1,
        metadataVersion: 1,
        agentStateVersion: 1,
        thinking: false,
        metadata: const Metadata(host: 'devbox', flavor: 'codex'),
        agentState: AgentState(goal: goal),
        presence: 'online',
      );
    }

    testWidgets('renders nothing without a goal', (tester) async {
      container.read(sessionsNotifierProvider.notifier).setSessions([
        session('s1'),
      ]);

      await tester.pumpWidget(wrap(const SessionGoalBanner(sessionId: 's1')));
      await tester.pumpAndSettle();

      expect(find.text('Goal'), findsNothing);
      expect(find.byIcon(Icons.flag_rounded), findsNothing);
    });

    testWidgets('renders the goal for the active session only', (tester) async {
      container.read(sessionsNotifierProvider.notifier).setSessions([
        session(
          's1',
          goal: const CodexGoal(objective: 'Make Codex goals visible in chat'),
        ),
        session('s2', goal: const CodexGoal(objective: 'Other session goal')),
      ]);

      await tester.pumpWidget(wrap(const SessionGoalBanner(sessionId: 's1')));
      await tester.pumpAndSettle();

      expect(find.text('Goal'), findsOneWidget);
      expect(find.text('active'), findsOneWidget);
      expect(find.text('Make Codex goals visible in chat'), findsOneWidget);
      expect(find.text('Other session goal'), findsNothing);
    });
  });
}

class _TestSessionsNotifier extends SessionsNotifier {
  @override
  Map<String, Session> build() => {};

  @override
  void setSessions(List<Session> sessions) {
    state = {for (final session in sessions) session.id: session};
  }
}
