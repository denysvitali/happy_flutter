import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/workflow_run.dart';
import 'package:happy_flutter/core/widgets/app_linear_progress_indicator.dart';
import 'package:happy_flutter/features/workflows/workflow_run_header.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('refresh warning retries at phone width in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var retries = 0;

      await tester.pumpWidget(
        _harness(
          brightness: brightness,
          child: WorkflowRunHeader(
            run: _run(),
            groups: const [],
            showRefreshWarning: true,
            onRetry: () async {
              retries++;
            },
          ),
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retries, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'run model overrides shared fallback and zero stats stay hidden',
    (tester) async {
      Future<void> render(WorkflowRun run) => tester.pumpWidget(
        _harness(
          child: WorkflowRunHeader(
            run: run,
            groups: const [],
            commonModel: 'shared-model',
            onRetry: () async {},
          ),
        ),
      );

      await render(_run(agentCount: 1, totalTokens: 0, totalToolCalls: 0));
      expect(find.text('shared-model'), findsOneWidget);
      expect(find.text('1 agent'), findsOneWidget);
      expect(find.text('0 tokens'), findsNothing);
      expect(find.text('0 tools'), findsNothing);

      await render(
        _run(
          defaultModel: 'run-model',
          agentCount: 2,
          totalTokens: 12500,
          totalToolCalls: 3,
        ),
      );
      expect(find.text('run-model'), findsOneWidget);
      expect(find.text('shared-model'), findsNothing);
      expect(find.text('2 agents'), findsOneWidget);
      expect(find.text('12.5k tokens'), findsOneWidget);
      expect(find.text('3 tools'), findsOneWidget);
    },
  );

  testWidgets('phase progress distinguishes pending, active, and complete', (
    tester,
  ) async {
    Future<void> render(List<String> states) => tester.pumpWidget(
      _harness(
        child: WorkflowRunHeader(
          run: _run(),
          groups: [for (final state in states) _group(state)],
          onRetry: () async {},
        ),
      ),
    );

    double? fraction() => tester
        .widget<AppLinearProgressIndicator>(
          find.byType(AppLinearProgressIndicator),
        )
        .value;

    await render([WorkflowPhaseState.pending, WorkflowPhaseState.pending]);
    expect(find.text('2 phases'), findsOneWidget);
    expect(fraction(), 0);

    await render([WorkflowPhaseState.done, WorkflowPhaseState.active]);
    expect(find.text('Phase 2 of 2'), findsOneWidget);
    expect(fraction(), greaterThan(0.5));
    expect(fraction(), lessThan(1));

    await render([WorkflowPhaseState.done, WorkflowPhaseState.done]);
    expect(find.text('Phase 2 of 2'), findsOneWidget);
    expect(fraction(), 1);

    await render([WorkflowPhaseState.done]);
    expect(find.byType(AppLinearProgressIndicator), findsNothing);
  });

  testWidgets('elapsed timer follows live, paused, and recorded durations', (
    tester,
  ) async {
    // A future start makes the elapsed label deterministic and exercises the
    // existing zero clamp without relying on the widget test clock for now().
    final start = DateTime.now()
        .add(const Duration(days: 1))
        .millisecondsSinceEpoch;
    Future<void> render(String status, {int? durationMs}) => tester.pumpWidget(
      _harness(
        child: WorkflowRunHeader(
          run: _run(status: status, startTime: start, durationMs: durationMs),
          groups: const [],
          onRetry: () async {},
        ),
      ),
    );

    await render(WorkflowStatus.running);
    expect(find.text('0s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0s'), findsOneWidget);

    await render(WorkflowStatus.paused);
    expect(find.text('0s'), findsNothing);
    await render(WorkflowStatus.paused, durationMs: 123000);
    expect(find.text('2m 3s'), findsOneWidget);
    await render(WorkflowStatus.completed, durationMs: 123000);
    expect(find.text('2m 3s'), findsOneWidget);

    await render(WorkflowStatus.running);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}

Widget _harness({
  required Widget child,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData(brightness: brightness),
  home: Scaffold(body: child),
);

WorkflowRun _run({
  String status = WorkflowStatus.completed,
  String? defaultModel,
  int? agentCount,
  int? totalTokens,
  int? totalToolCalls,
  int? startTime,
  int? durationMs,
}) => WorkflowRun(
  runId: 'run-1',
  workflowName: 'Review',
  status: status,
  defaultModel: defaultModel,
  agentCount: agentCount,
  totalTokens: totalTokens,
  totalToolCalls: totalToolCalls,
  startTime: startTime,
  durationMs: durationMs,
);

WorkflowPhaseGroup _group(String state) => WorkflowPhaseGroup(
  phase: const WorkflowPhase(title: 'Review'),
  agents: const [],
  state: state,
);
