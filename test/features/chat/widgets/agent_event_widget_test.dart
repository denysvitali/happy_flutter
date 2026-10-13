import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/utils/task_label.dart';
import 'package:happy_flutter/features/chat/widgets/agent_event_widget.dart';

const _recoveryInstruction =
    'Start a new Prime Agent conversation to continue.';
const _lifecycleError =
    'Prime Agent could not start: open saved Prime Agent ACP conversation '
    '/home/workspace/.local/share/prime-agent/sessions/saved-session.jsonl: '
    'the saved transcript is unavailable. $_recoveryInstruction';

Widget _app(Map<String, dynamic> event, {double textScale = 1}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: ListView(children: [AgentEventWidget(event: event)]),
        ),
      ),
    ),
  );
}

Finder _fullText(String text) => find.byWidgetPredicate(
  (widget) => widget is SelectableText && widget.data == text,
);

void main() {
  testWidgets('long lifecycle errors expand to the full recovery instruction', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app({'type': 'message', 'message': _lifecycleError}, textScale: 2),
    );
    final collapsedHeight = tester
        .getSize(find.byType(AgentEventWidget))
        .height;
    expect(_fullText(_lifecycleError), findsNothing);
    final preview = tester.widget<Text>(
      find.text(compactTaskLabel(_lifecycleError)),
    );
    expect(preview.maxLines, 2);
    expect(preview.overflow, TextOverflow.ellipsis);

    await tester.tap(find.text('Show more'));
    await tester.pump();
    final details = tester.widget<SelectableText>(_fullText(_lifecycleError));
    expect(details.data, endsWith(_recoveryInstruction));
    expect(details.maxLines, isNull);
    expect(
      tester.getSize(find.byType(AgentEventWidget)).height,
      greaterThan(collapsedHeight),
    );
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Show less'));
    await tester.tap(find.text('Show less'));
    await tester.pump();
    expect(_fullText(_lifecycleError), findsNothing);
    expect(
      tester.getSize(find.byType(AgentEventWidget)).height,
      collapsedHeight,
    );
  });

  testWidgets('layout overflow below the character limit can expand', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const notice =
        'The request will resume after the current operation completes. '
        'You can keep this conversation open.';
    expect(compactTaskLabel(notice), notice);

    await tester.pumpWidget(
      _app({'type': 'message', 'message': notice}, textScale: 2),
    );
    await tester.tap(find.text('Show more'));
    await tester.pump();
    expect(_fullText(notice), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('character-clamped notices can expand even on a wide screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app({'type': 'message', 'message': _lifecycleError}),
    );
    await tester.tap(find.text('Show more'));
    await tester.pump();
    expect(_fullText(_lifecycleError), findsOneWidget);
  });

  testWidgets('cached notices without a type retain their complete text', (
    tester,
  ) async {
    await tester.pumpWidget(_app({'message': _lifecycleError}));
    await tester.tap(find.text('Show more'));
    await tester.pump();
    expect(_fullText(_lifecycleError), findsOneWidget);
  });

  testWidgets('short ordinary messages keep compact neutral styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app({'type': 'message', 'message': 'Context compacted'}),
    );
    final text = tester.widget<Text>(find.text('Context compacted'));
    final theme = Theme.of(tester.element(find.byType(AgentEventWidget)));
    expect(
      text.style?.color,
      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
    );
    expect(find.text('Show more'), findsNothing);
    expect(find.byType(SelectableText), findsNothing);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets('replacing the event resets expanded details', (tester) async {
    await tester.pumpWidget(
      _app({'type': 'message', 'message': _lifecycleError}),
    );
    await tester.tap(find.text('Show more'));
    await tester.pump();

    await tester.pumpWidget(
      _app({'type': 'message', 'message': 'Context compacted'}),
    );
    expect(find.text('Context compacted'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    expect(find.text('Show less'), findsNothing);
  });
}
