import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tool_work_summary.dart';
import 'package:happy_flutter/features/chat/widgets/turn_review_bar.dart';

void main() {
  testWidgets('review exposes the answer, changed file and command output', (
    tester,
  ) async {
    Map<String, dynamic>? opened;
    final turn = ChatTurnWork.fromMessages([
      {'role': 'user', 'content': 'Fix it'},
      {
        'id': 'edit',
        'role': 'agent',
        'kind': 'tool-call',
        'name': 'Edit',
        'state': 'completed',
        'input': {'file_path': 'lib/app.dart'},
      },
      {
        'id': 'check',
        'role': 'agent',
        'kind': 'tool-call',
        'name': 'Bash',
        'state': 'error',
        'input': {'command': 'flutter analyze'},
      },
      {'role': 'agent', 'kind': 'text', 'content': 'Updated the layout.'},
    ]);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TurnReviewBar(turn: turn, onOpenTool: (tool) => opened = tool),
        ),
      ),
    );
    expect(find.textContaining('1 failed'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('turn-review-bar')));
    await tester.pumpAndSettle();
    expect(find.text('Latest answer'), findsOneWidget);
    expect(find.text('Updated the layout.'), findsOneWidget);
    expect(find.text('Changed files'), findsOneWidget);
    expect(find.text('lib/app.dart'), findsOneWidget);
    expect(find.text('Failed tools'), findsOneWidget);
    await tester.tap(find.text('lib/app.dart'));
    await tester.pumpAndSettle();
    expect(opened?['id'], 'edit');
    expect(find.text('Changed files'), findsNothing);
  });

  testWidgets('review handles tool-only results and narrow large-text panes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final turn = ChatTurnWork.fromMessages([
      {'role': 'user'},
      {
        'id': 'patch',
        'kind': 'tool-call',
        'name': 'Write',
        'state': 'completed',
        'input': {'file_path': 'long/path/file.dart'},
      },
    ]);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: TurnReviewBar(turn: turn, onOpenTool: (_) {}),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('turn-review-bar')));
    await tester.pumpAndSettle();
    expect(
      find.text('No final answer recorded for this turn.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
