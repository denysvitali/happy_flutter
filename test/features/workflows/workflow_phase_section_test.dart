import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/workflow_run.dart';
import 'package:happy_flutter/features/workflows/workflow_phase_section.dart';

void main() {
  testWidgets('unreached phases become skipped once the run stops', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_section(runIsLive: true)));
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Skipped'), findsNothing);

    await tester.pumpWidget(_harness(_section(runIsLive: false)));
    expect(find.text('Skipped'), findsOneWidget);
    expect(find.text('Pending'), findsNothing);
  });

  testWidgets('empty reached phases retain their reported state', (
    tester,
  ) async {
    for (final (state, label) in [
      (WorkflowPhaseState.active, 'Starting…'),
      (WorkflowPhaseState.done, 'Completed'),
      (WorkflowPhaseState.failed, 'Failed'),
    ]) {
      await tester.pumpWidget(_harness(_section(state: state)));
      expect(find.text(label), findsOneWidget);
      expect(find.text('Skipped'), findsNothing);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'agent expansion keeps safe errors and details in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const agent = WorkflowAgent(
          agentId: 'agent-1',
          label: 'Reviewer',
          phaseIndex: 1,
          phaseTitle: 'Review',
          model: 'model-a',
          state: 'failed',
          durationMs: 23000,
          tokens: 1200,
          toolCalls: 4,
          lastToolName: 'Read',
          lastToolSummary: 'Inspect source',
          promptPreview: '  Review source files  ',
          resultPreview: '  Review complete  ',
          error: 'rpc: secret-host.internal refused bearer abc123',
        );

        await tester.pumpWidget(
          _harness(
            _section(agents: [agent], state: WorkflowPhaseState.failed),
            brightness: brightness,
          ),
        );
        expect(find.text('23s · 1.2k tokens · 4 tools'), findsOneWidget);
        expect(find.text('Read · Inspect source'), findsOneWidget);
        expect(find.text('model-a'), findsOneWidget);
        expect(find.text('Review source files'), findsNothing);

        await tester.tap(find.text('Reviewer'));
        await tester.pumpAndSettle();
        expect(find.text('Review source files'), findsOneWidget);
        expect(find.text('Review complete'), findsOneWidget);
        expect(find.textContaining('secret-host.internal'), findsNothing);
        expect(
          find.text('This agent step failed unexpectedly.'),
          findsOneWidget,
        );
        expect(find.text('Show more'), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          _harness(
            _section(
              agents: [agent],
              state: WorkflowPhaseState.failed,
              hideModel: true,
            ),
            brightness: brightness,
          ),
        );
        expect(find.text('model-a'), findsNothing);
        // Updating display preferences must not collapse the expanded agent.
        expect(find.text('Review source files'), findsOneWidget);
      },
    );
  }

  testWidgets('long prompt can expand and collapse without losing its text', (
    tester,
  ) async {
    final prompt = List.generate(12, (index) => 'Focus line $index').join('\n');
    final agent = WorkflowAgent(
      agentId: 'agent-1',
      label: 'Reviewer',
      phaseIndex: 1,
      phaseTitle: 'Review',
      model: '',
      state: 'done',
      promptPreview: prompt,
    );
    await tester.pumpWidget(_harness(_section(agents: [agent])));
    await tester.tap(find.text('Reviewer'));
    await tester.pumpAndSettle();

    SelectableText body() => tester.widget<SelectableText>(
      find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == prompt,
      ),
    );
    expect(body().maxLines, 8);
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    expect(body().maxLines, isNull);
    expect(body().data, prompt);
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(body().maxLines, 8);
    expect(body().data, prompt);
  });
}

Widget _harness(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

WorkflowPhaseSection _section({
  List<WorkflowAgent> agents = const [],
  String state = WorkflowPhaseState.pending,
  bool runIsLive = true,
  bool hideModel = false,
}) => WorkflowPhaseSection(
  group: WorkflowPhaseGroup(
    phase: const WorkflowPhase(title: 'Review'),
    agents: agents,
    state: state,
  ),
  hideModel: hideModel,
  runIsLive: runIsLive,
);
