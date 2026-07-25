import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/message_widget.dart';

/// Tapping a `Workflow` tool-call row must deep-link to the run detail
/// route when the run id is resolvable (grouped `workflowRunId` tag or the
/// `Run ID: wf_…` echo in the launch receipt), and only fall back to the
/// workflows list when no id has crossed the wire yet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Map<String, dynamic> messageData) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              child: MessageWidget(
                messageData: messageData,
                isFromCurrentUser: false,
                sessionId: 's1',
                animate: false,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/chat/:sessionId/workflows',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('workflows-list'))),
        ),
        GoRoute(
          path: '/chat/:sessionId/workflow/:workflowRunId',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text('run:${state.pathParameters['workflowRunId']}'),
            ),
          ),
        ),
      ],
    );
    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  Map<String, dynamic> workflowTool({
    String? workflowRunId,
    dynamic result,
  }) => {
    'id': 'm1',
    'kind': 'tool-call',
    'name': 'Workflow',
    'state': 'completed',
    'input': {'name': 'inspect-go-mod'},
    if (workflowRunId != null) 'workflowRunId': workflowRunId,
    if (result != null) 'result': result,
  };

  // Bounded pumps instead of pumpAndSettle: the tool row hosts repeating
  // animations (live-state shimmer/spinner) that never settle.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapHeader(WidgetTester tester) async {
    await tester.tap(find.byType(InkWell).first, warnIfMissed: false);
    await settle(tester);
  }

  testWidgets('grouped workflowRunId tag routes to the run detail', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(workflowTool(workflowRunId: 'wf_aaa-111')));
    await settle(tester);

    await tapHeader(tester);

    expect(find.text('run:wf_aaa-111'), findsOneWidget);
  });

  testWidgets('launch receipt "Run ID:" echo routes to the run detail', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        workflowTool(
          result:
              'Workflow launched in background. Task ID: wo9gouhnm\n'
              'Run ID: wf_56b970d8-22d\n'
              'Use /workflows to watch live progress.',
        ),
      ),
    );
    await settle(tester);

    await tapHeader(tester);

    expect(find.text('run:wf_56b970d8-22d'), findsOneWidget);
  });

  testWidgets('no resolvable run id falls back to the workflows list', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(workflowTool()));
    await settle(tester);

    await tapHeader(tester);

    expect(find.text('workflows-list'), findsOneWidget);
  });
}
