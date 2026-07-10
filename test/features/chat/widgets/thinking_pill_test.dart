import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/widgets/thinking_pill.dart';

Widget _app(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThinkingPill', () {
    testWidgets('shows main-agent tool label after delay', (tester) async {
      await tester.pumpWidget(
        _app(
          const ThinkingPill(
            isThinking: true,
            isTextStreaming: false,
            lastToolName: 'BashTool',
          ),
        ),
      );

      expect(find.text('Bash tool…'), findsNothing);

      await tester.pump(const Duration(seconds: 4));

      expect(find.text('Bash tool…'), findsOneWidget);
    });

    testWidgets('prefers sub-agent tool name over main-agent tool', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const ThinkingPill(
            isThinking: false,
            isTextStreaming: false,
            lastToolName: 'Read',
            subAgentToolName: 'Edit',
            subAgentStartedAt: 0,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 4));

      expect(find.text('Edit…'), findsOneWidget);
      expect(find.text('Read…'), findsNothing);
    });

    testWidgets(
      'stays visible for sub-agent work when main agent stops thinking',
      (tester) async {
        await tester.pumpWidget(
          _app(
            const ThinkingPill(
              isThinking: false,
              isTextStreaming: false,
              subAgentToolName: 'Bash',
              subAgentStartedAt: 0,
            ),
          ),
        );

        await tester.pump(const Duration(seconds: 4));

        expect(find.text('Bash…'), findsOneWidget);
      },
    );

    testWidgets('hides when text is streaming', (tester) async {
      await tester.pumpWidget(
        _app(
          const ThinkingPill(
            isThinking: true,
            isTextStreaming: true,
            lastToolName: 'Bash',
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 4));

      expect(find.text('Bash…'), findsNothing);
    });

    testWidgets('shows Working label when no tool is given', (tester) async {
      await tester.pumpWidget(
        _app(const ThinkingPill(isThinking: true, isTextStreaming: false)),
      );

      await tester.pump(const Duration(seconds: 4));

      expect(find.text('Working…'), findsOneWidget);
    });

    testWidgets('clears when sub-agent tool is removed', (tester) async {
      await tester.pumpWidget(
        _app(
          const ThinkingPill(
            isThinking: false,
            isTextStreaming: false,
            subAgentToolName: 'Bash',
            subAgentStartedAt: 0,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Bash…'), findsOneWidget);

      await tester.pumpWidget(
        _app(
          const ThinkingPill(
            isThinking: false,
            isTextStreaming: false,
            subAgentToolName: null,
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Bash…'), findsNothing);
    });

    testWidgets('shows stopping progress and suppresses repeated stop', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ThinkingPill(
            isThinking: true,
            isTextStreaming: false,
            isStopping: true,
            onStop: () {},
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 4));

      expect(find.text('Stopping…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
    });
  });
}
