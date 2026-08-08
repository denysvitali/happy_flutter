import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/features/loops/goal_loop_card.dart';

Loop _goalLoop({
  String status = '',
  bool paused = false,
  int fireCount = 2,
  int maxIterations = 25,
  String? activeSessionId,
  String statusDetail = '',
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Loop(
    id: 'cafef00d',
    sessionId: '',
    expression: '',
    prompt: '',
    recurring: true,
    createdAt: now - 60000,
    expiresAt: now + 30 * 24 * 60 * 60 * 1000,
    fireCount: fireCount,
    paused: paused,
    machineId: 'machine-1',
    directory: '/home/user/project',
    agent: 'claude',
    model: 'opus:max',
    goal: 'Get the integration suite passing',
    maxIterations: maxIterations,
    status: status,
    statusDetail: statusDetail,
    activeSessionId: activeSessionId,
  );
}

Widget _wrap({required Loop loop, Future<void> Function()? onResume}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: GoalLoopCard(
        loop: loop,
        onPauseToggle: (_) async {},
        onResume: onResume ?? () async {},
        onDelete: () async {},
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoalLoopCard', () {
    testWidgets('shows the goal, directory, and iteration progress', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(loop: _goalLoop(activeSessionId: 'run-1')));

      expect(find.text('Get the integration suite passing'), findsOneWidget);
      expect(find.text('/home/user/project'), findsOneWidget);
      expect(find.text('claude · opus:max'), findsOneWidget);
      // Iteration 2 of 2 is in flight → 1 completed of 25.
      expect(find.text('1 of 25 iterations'), findsOneWidget);
      expect(find.text('Working now'), findsOneWidget);
    });

    testWidgets('shows the status detail for a terminal loop', (tester) async {
      await tester.pumpWidget(
        _wrap(
          loop: _goalLoop(
            status: 'blocked',
            statusDetail: 'Needs a registry push token',
          ),
        ),
      );
      expect(find.text('Needs a registry push token'), findsOneWidget);
      expect(find.text('Needs you'), findsOneWidget);
    });

    testWidgets('a running loop offers pause, a terminal loop offers resume', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(loop: _goalLoop()));
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Resume loop'), findsNothing);

      await tester.pumpWidget(_wrap(loop: _goalLoop(status: 'complete')));
      expect(find.text('Resume loop'), findsOneWidget);
      expect(find.text('Pause'), findsNothing);
    });

    testWidgets('resume tap invokes the callback', (tester) async {
      var resumed = false;
      await tester.pumpWidget(
        _wrap(
          loop: _goalLoop(status: 'exhausted'),
          onResume: () async => resumed = true,
        ),
      );
      await tester.tap(find.text('Resume loop'));
      expect(resumed, isTrue);
    });

    testWidgets('the chip reflects each terminal status', (tester) async {
      final cases = <String, String>{
        'complete': 'Reached',
        'blocked': 'Needs you',
        'stalled': 'Stalled',
        'exhausted': 'Out of iterations',
      };
      for (final entry in cases.entries) {
        await tester.pumpWidget(_wrap(loop: _goalLoop(status: entry.key)));
        expect(
          find.text(entry.value),
          findsOneWidget,
          reason: 'status ${entry.key}',
        );
      }
      // paused wins over running-but-idle.
      await tester.pumpWidget(_wrap(loop: _goalLoop(paused: true)));
      expect(find.text('Paused'), findsOneWidget);
    });

    testWidgets('open-session action only when a session exists', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(loop: _goalLoop()));
      expect(find.text('Open session'), findsNothing);

      await tester.pumpWidget(_wrap(loop: _goalLoop(activeSessionId: 'run-1')));
      expect(find.text('Open session'), findsOneWidget);
    });
  });
}
