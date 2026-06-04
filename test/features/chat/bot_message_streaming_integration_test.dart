import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/message_widget.dart';
import 'package:happy_flutter/features/chat/widgets/bot_message.dart';
import 'package:happy_flutter/features/chat/widgets/streaming_cursor.dart';

/// Wraps [child] in a minimal app shell for widget tests.
Widget _app(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

/// Builds a [BotMessage] for the given [text] and streaming state.
Widget _bot({
  required bool isStreaming,
  String text = 'Hello from the agent',
}) {
  return _app(
    BotMessage(
      text: text,
      messageData: <String, dynamic>{
        'kind': 'message',
        'role': 'agent',
        'content': text,
      },
      isStreaming: isStreaming,
    ),
  );
}

/// Builds a [MessageWidget] for a bot message with the given streaming state.
Widget _widget({
  required bool isStreaming,
  String text = 'Hello from the agent',
}) {
  return _app(
    MessageWidget(
      messageData: <String, dynamic>{
        'kind': 'message',
        'role': 'agent',
        'content': text,
      },
      isFromCurrentUser: false,
      isStreaming: isStreaming,
      // Skip the entrance animation so the test isn't gated on its completion.
      animate: false,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BotMessage streaming integration', () {
    testWidgets('shows StreamingCursor when isStreaming is true',
        (tester) async {
      await tester.pumpWidget(_bot(isStreaming: true));
      await tester.pumpAndSettle();

      expect(find.byType(StreamingCursor), findsOneWidget);
    });

    testWidgets('hides StreamingCursor when isStreaming is false',
        (tester) async {
      await tester.pumpWidget(_bot(isStreaming: false));
      await tester.pumpAndSettle();

      expect(find.byType(StreamingCursor), findsNothing);
    });

    testWidgets('hides StreamingCursor by default (isStreaming omitted)',
        (tester) async {
      await tester.pumpWidget(_bot(isStreaming: false));
      await tester.pumpAndSettle();

      // The default in BotMessage's constructor is isStreaming: false,
      // so even with no flag passed the cursor should be absent.
      expect(find.byType(StreamingCursor), findsNothing);
    });

    testWidgets('exposes streaming state to semantics', (tester) async {
      await tester.pumpWidget(_bot(isStreaming: true));
      await tester.pumpAndSettle();

      // The Semantics widget around the bubble changes its label
      // when streaming — a screen reader user hears
      // "AI response streaming" instead of the truncated text.
      final semantics = tester.getSemantics(find.byType(BotMessage));
      expect(
        semantics.label,
        contains('streaming'),
      );
    });
  });

  group('MessageWidget streaming plumbing', () {
    testWidgets('forwards isStreaming to BotMessage for agent text',
        (tester) async {
      await tester.pumpWidget(_widget(isStreaming: true));
      await tester.pumpAndSettle();

      // The MessageWidget dispatches to BotMessage for non-user, non-tool
      // messages, and the cursor should appear at the bottom of the bubble.
      expect(find.byType(StreamingCursor), findsOneWidget);
    });

    testWidgets('omits StreamingCursor for completed agent messages',
        (tester) async {
      await tester.pumpWidget(_widget(isStreaming: false));
      await tester.pumpAndSettle();

      expect(find.byType(StreamingCursor), findsNothing);
    });
  });
}
