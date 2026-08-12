import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/features/chat/widgets/agent_event_widget.dart';
import 'package:happy_flutter/features/chat/widgets/sub_agent_status_banner.dart';
import 'package:happy_flutter/features/chat/widgets/task_event_summary_card.dart';

import '../../../helpers/test_helpers.dart';

/// Reconstructs the screenshot the user disliked: sticky banner over a
/// burst of task start/progress/complete rows, including a Read tool
/// whose description starts with "Reading".
Widget _app(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Sync sync;

  setUp(() {
    sync = createTestSync();
  });

  tearDown(() {
    sync.testClearSessionMessageState('layout-session');
  });

  testWidgets('sub-agent stream layout does not wrap mid-word or ghost', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    sync.testSetSessionMessages('layout-session', [
      for (var i = 0; i < 10; i++)
        <String, dynamic>{
          'id': 'task-$i',
          'kind': 'tool-call',
          'name': 'Task',
          'state': 'running',
          'isSidechain': false,
          'seq': i,
        },
    ]);

    await tester.pumpWidget(
      _app(
        Column(
          children: [
            const SubAgentStatusBanner(sessionId: 'layout-session'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                children: const [
                  AgentEventWidget(
                    event: {
                      'type': 'message',
                      'message': 'Running Read kafel include base policies',
                    },
                    message: {
                      'taskEvent': true,
                      'taskPhase': 'task_progress',
                      'subAgentLastTool': 'Bash',
                    },
                  ),
                  AgentEventWidget(
                    event: {
                      'type': 'message',
                      'message': 'Strings libQtCarGUI for tidk writer',
                    },
                    message: {'taskEvent': true, 'taskPhase': 'task_started'},
                  ),
                  TaskEventSummaryCard(
                    data: {
                      'taskEvent': true,
                      'taskStatus': 'completed',
                      'content': 'Strings libQtCarGUI for tidk writer',
                    },
                  ),
                  AgentEventWidget(
                    event: {
                      'type': 'message',
                      'message':
                          'Reading ~/.claude/projects/-home-workspace- '
                          'git-fw-analyzer/2150fa82-9.jsonl',
                    },
                    message: {
                      'taskEvent': true,
                      'taskPhase': 'task_progress',
                      'subAgentLastTool': 'Read',
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('10 of 10 sub-agents running'), findsOneWidget);
    expect(find.textContaining('Reading'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^ing\b')), findsNothing);

    final banner = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(SubAgentStatusBanner),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(banner.color?.a, 1.0);
  });
}
