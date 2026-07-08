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

    testWidgets(
        'renders fallback text for unknown event types', (tester) async {
      await tester.pumpWidget(
        _app(
          const AgentEventWidget(
            event: <String, dynamic>{'type': 'totally-unknown'},
          ),
        ),
      );

      expect(find.text('Unsupported agent message'), findsNothing);
      expect(
        find.text('Unsupported agent event (totally-unknown)'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.help_outline_rounded), findsNothing);
    });

    testWidgets(
        'uses explicit message over generated fallback', (tester) async {
      await tester.pumpWidget(
        _app(
          const AgentEventWidget(
            event: <String, dynamic>{
              'type': 'totally-unknown',
              'message': 'Something happened',
            },
          ),
        ),
      );

      expect(find.text('Something happened'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline_rounded), findsNothing);
    });

    testWidgets(
        'renders sub-agent tool name and icon when provided', (tester) async {
      await tester.pumpWidget(
        _app(
          const AgentEventWidget(
            event: <String, dynamic>{'type': 'message', 'message': 'Working'},
            message: <String, dynamic>{'subAgentLastTool': 'Bash'},
          ),
        ),
      );

      expect(find.text('Bash'), findsOneWidget);
      expect(find.text('Working'), findsOneWidget);
    });

    testWidgets('ignores empty sub-agent tool name', (tester) async {
      await tester.pumpWidget(
        _app(
          const AgentEventWidget(
            event: <String, dynamic>{
              'type': 'unrendered',
              'message': 'Unsupported message',
            },
            message: <String, dynamic>{'subAgentLastTool': ''},
          ),
        ),
      );

      expect(find.text('Unsupported message'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    });

    testWidgets('message parameter is optional', (tester) async {
      await tester.pumpWidget(
        _app(
          const AgentEventWidget(
            event: <String, dynamic>{'type': 'message', 'message': 'Hello'},
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
    });
  });

  group('AgentEventWidget.shouldRenderInChat', () {
    test('hides telemetry-only event types from chat list', () {
      expect(
        AgentEventWidget.shouldRenderInChat(
          <String, dynamic>{'type': 'usage_report'},
        ),
        isFalse,
      );
      expect(
        AgentEventWidget.shouldRenderInChat(<String, dynamic>{'type': 'ready'}),
        isFalse,
      );
      expect(
        AgentEventWidget.shouldRenderInChat(
          <String, dynamic>{'type': 'tool-execution-update'},
        ),
        isFalse,
      );
      expect(
        AgentEventWidget.shouldRenderInChat(
          <String, dynamic>{'type': 'thinking'},
        ),
        isFalse,
      );
      expect(
        AgentEventWidget.shouldRenderInChat(
          <String, dynamic>{'type': 'grok-event'},
        ),
        isFalse,
      );
      expect(
        AgentEventWidget.shouldRenderInChat(
          <String, dynamic>{'type': 'opencode-event'},
        ),
        isFalse,
      );
    });

    test('shows unknown and unsupported agent events in chat', () {
      expect(
        AgentEventWidget.shouldRenderInChat(
          <String, dynamic>{'type': 'totally-unknown'},
        ),
        isTrue,
      );
      expect(
        AgentEventWidget.shouldRenderInChat(
          <String, dynamic>{'type': 'unrendered'},
        ),
        isTrue,
      );
      expect(
        AgentEventWidget.shouldRenderInChat(<String, dynamic>{}),
        isTrue,
      );
    });

    test('ignores malformed event payloads', () {
      expect(AgentEventWidget.shouldRenderInChat(null), isFalse);
      expect(AgentEventWidget.shouldRenderInChat('not-a-map'), isFalse);
    });
  });

  group('AgentEventWidget.labelFor', () {
    test('returns labels for renderable event types', () {
      expect(
        AgentEventWidget.labelFor(
          <String, dynamic>{'type': 'switch', 'mode': 'remote'},
        ),
        'Switched to remote mode',
      );
      expect(
        AgentEventWidget.labelFor(
          <String, dynamic>{'type': 'message', 'message': 'hi'},
        ),
        'hi',
      );
      expect(
        AgentEventWidget.labelFor(<String, dynamic>{'type': 'limit-reached'}),
        'Usage limit reached',
      );
      expect(
        AgentEventWidget.labelFor(<String, dynamic>{'type': 'unrendered'}),
        'Unsupported agent message',
      );
    });

    test('returns null for label-less events not shown in timeline', () {
      // usage_report / ready rows still exist in older message caches;
      // the chat list must not give them a padded row.
      expect(
        AgentEventWidget.labelFor(
          <String, dynamic>{'type': 'usage_report', 'cost': 0.1},
        ),
        isNull,
      );
      expect(
        AgentEventWidget.labelFor(<String, dynamic>{'type': 'ready'}),
        isNull,
      );
      expect(
        AgentEventWidget.labelFor(<String, dynamic>{'type': 'unknown-x'}),
        isNull,
      );
      expect(AgentEventWidget.labelFor(null), isNull);
      expect(AgentEventWidget.labelFor('not-a-map'), isNull);
    });
  });
}
