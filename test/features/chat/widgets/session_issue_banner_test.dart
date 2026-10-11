import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/widgets/chat_app_bar.dart'
    show SendIssue;
import 'package:happy_flutter/features/chat/widgets/session_issue_banner.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('recovery action is distinct from diagnostic copy', (
    tester,
  ) async {
    var recovered = 0;
    var copied = 0;
    await tester.pumpWidget(
      _wrap(
        SessionIssueBanner(
          issue: const SendIssue(
            title: 'Stopped',
            message: 'Start a new conversation.',
            blocksSend: true,
          ),
          actionLabel: 'Start new session',
          onAction: () => recovered++,
          onCopy: () => copied++,
        ),
      ),
    );
    await tester.tap(find.text('Start new session'));
    expect(recovered, 1);
    expect(copied, 0);
    await tester.tap(find.byIcon(Icons.copy_rounded));
    expect(copied, 1);
  });

  testWidgets('renders title and message text', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SessionIssueBanner(
          issue: SendIssue(
            title: 'Session process stopped',
            message:
                'The local agent process is gone. Sending a '
                'message will try to restart it.',
            blocksSend: true,
          ),
        ),
      ),
    );
    expect(find.text('Session process stopped'), findsOneWidget);
    expect(
      find.text(
        'The local agent process is gone. Sending a '
        'message will try to restart it.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('blocksSend=true uses the error icon', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SessionIssueBanner(
          issue: SendIssue(
            title: 'Agent failed',
            message: '...',
            blocksSend: true,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.restart_alt_rounded), findsNothing);
  });

  testWidgets('blocksSend=false uses the restart icon', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SessionIssueBanner(
          issue: SendIssue(
            title: 'Will restart',
            message: '...',
            blocksSend: false,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.restart_alt_rounded), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
  });

  testWidgets('shows a copy action when provided', (tester) async {
    var copied = false;
    await tester.pumpWidget(
      _wrap(
        SessionIssueBanner(
          issue: const SendIssue(
            title: 'Agent failed',
            message: 'The process stopped.',
            blocksSend: true,
          ),
          onCopy: () => copied = true,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.copy_rounded));

    expect(copied, isTrue);
  });
}
