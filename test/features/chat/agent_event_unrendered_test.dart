import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/widgets/agent_event_widget.dart';

Widget _app(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AgentEventWidget — unrendered fallback', () {
    testWidgets(
        'renders the message text and a help icon for type=unrendered',
        (tester) async {
      await tester.pumpWidget(
        _app(
          const AgentEventWidget(
            event: <String, dynamic>{
              'type': 'unrendered',
              'message': 'Unsupported message (foo)',
            },
          ),
        ),
      );

      expect(find.text('Unsupported message (foo)'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    });

    testWidgets('falls back to a default label when message is missing',
        (tester) async {
      await tester.pumpWidget(
        _app(
          const AgentEventWidget(
            event: <String, dynamic>{'type': 'unrendered'},
          ),
        ),
      );

      expect(find.text('Unsupported agent message'), findsOneWidget);
    });

    testWidgets('renders nothing for genuinely unknown event types',
        (tester) async {
      await tester.pumpWidget(
        _app(
          const AgentEventWidget(
            event: <String, dynamic>{'type': 'totally-unknown'},
          ),
        ),
      );

      // No text, no icon — the chat stays clean for events we have not
      // explicitly opted into (legacy behaviour preserved).
      expect(find.byType(Text), findsNothing);
      expect(find.byIcon(Icons.help_outline_rounded), findsNothing);
    });
  });
}
