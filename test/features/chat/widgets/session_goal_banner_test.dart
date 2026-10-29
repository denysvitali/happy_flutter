import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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

    testWidgets('expands the complete selectable objective and collapses', (
      tester,
    ) async {
      final objective = List.filled(
        30,
        'A long goal with every detail.',
      ).join(' ');
      container.read(sessionsNotifierProvider.notifier).setSessions([
        session(
          's1',
          goal: CodexGoal(objective: objective, status: 'paused'),
        ),
      ]);

      await tester.pumpWidget(wrap(const SessionGoalBanner(sessionId: 's1')));
      expect(find.text('paused'), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
      final preview = tester.widget<Text>(find.text(objective));
      expect(preview.maxLines, 1);
      expect(preview.overflow, TextOverflow.ellipsis);

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();
      final fullObjective = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(fullObjective.data, objective);
      expect(fullObjective.maxLines, isNull);
      expect(find.text('paused'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pump();
      expect(find.byType(SelectableText), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('long goals stay scrollable on a narrow enlarged screen', (
      tester,
    ) async {
      const status = 'paused while waiting for additional information';
      final objective =
          '${List.filled(80, 'Full goal details.').join(' ')} END';
      tester.view.physicalSize = const Size(240, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      container.read(sessionsNotifierProvider.notifier).setSessions([
        session(
          's1',
          goal: CodexGoal(objective: objective, status: status),
        ),
      ]);
      await tester.pumpWidget(
        wrap(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(240, 640),
              textScaler: TextScaler.linear(2.5),
            ),
            child: const SizedBox(
              width: 240,
              child: SessionGoalBanner(sessionId: 's1'),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(status), findsOneWidget);
      expect(tester.widget<Text>(find.text(status)).maxLines, isNull);
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text(status), findsOneWidget);
      final details = find.byKey(const ValueKey('goal-objective-scroll'));
      expect(tester.getSize(details).height, lessThanOrEqualTo(160));
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: details, matching: find.byType(Scrollable)).first,
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();
      expect(scrollable.position.extentAfter, 0);
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        endsWith('END'),
      );
      expect(tester.takeException(), isNull);
    });

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
