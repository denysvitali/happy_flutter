import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/message_widget.dart';

/// Wraps [child] in a minimal app shell for widget tests.
Widget _app(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

/// Builds a [MessageWidget] configured as a thinking block.
Widget _thinkingMessage({String content = 'Some reasoning'}) {
  return _app(
    MessageWidget(
      messageData: <String, dynamic>{
        'kind': 'message',
        'content': content,
        'isThinking': true,
      },
      isFromCurrentUser: false,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThinkingBlock', () {
    testWidgets('renders collapsed with Thinking label', (tester) async {
      await tester.pumpWidget(_thinkingMessage());
      await tester.pumpAndSettle();

      // Header is visible.
      expect(find.text('Thinking'), findsOneWidget);
      // Psychology icon is present.
      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
      // Expand chevron is present.
      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
    });

    testWidgets('content is hidden when collapsed', (tester) async {
      await tester.pumpWidget(
        _thinkingMessage(content: 'Hidden reasoning text'),
      );
      await tester.pumpAndSettle();

      // The SizeTransition starts fully collapsed so the
      // content text should have zero height and not be visible.
      final sizeTransition = tester.widget<SizeTransition>(
        find.byType(SizeTransition),
      );
      expect(sizeTransition.sizeFactor.value, 0.0);
    });

    testWidgets('expands and shows content on tap', (tester) async {
      await tester.pumpWidget(
        _thinkingMessage(content: 'Detailed reasoning'),
      );
      await tester.pumpAndSettle();

      // Tap the header to expand.
      await tester.tap(find.text('Thinking'));
      await tester.pumpAndSettle();

      // After expansion the SizeTransition should be fully open.
      final sizeTransition = tester.widget<SizeTransition>(
        find.byType(SizeTransition),
      );
      expect(sizeTransition.sizeFactor.value, 1.0);
    });

    testWidgets('collapses again on second tap', (tester) async {
      await tester.pumpWidget(
        _thinkingMessage(content: 'Collapse test'),
      );
      await tester.pumpAndSettle();

      // Expand.
      await tester.tap(find.text('Thinking'));
      await tester.pumpAndSettle();

      // Collapse.
      await tester.tap(find.text('Thinking'));
      await tester.pumpAndSettle();

      final sizeTransition = tester.widget<SizeTransition>(
        find.byType(SizeTransition),
      );
      expect(sizeTransition.sizeFactor.value, 0.0);
    });

    testWidgets('strips *Thinking...* prefix from content', (tester) async {
      await tester.pumpWidget(
        _thinkingMessage(content: '*Thinking...*\nActual reasoning'),
      );
      await tester.pumpAndSettle();

      // Expand to render the content.
      await tester.tap(find.text('Thinking'));
      await tester.pumpAndSettle();

      // The cleaned text should be rendered (via MarkdownView).
      expect(find.textContaining('Actual reasoning'), findsOneWidget);
      // The raw prefix should NOT appear as standalone text.
      expect(find.text('*Thinking...*'), findsNothing);
    });

    testWidgets('copy icon is present in header', (tester) async {
      await tester.pumpWidget(_thinkingMessage());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
    });

    testWidgets('has ClipRRect and ClipRect for proper clipping',
        (tester) async {
      await tester.pumpWidget(_thinkingMessage());
      await tester.pumpAndSettle();

      // ClipRRect wraps the container for rounded-corner clipping.
      expect(find.byType(ClipRRect), findsWidgets);

      // ClipRect wraps SizeTransition to prevent overflow
      // during the expand/collapse animation.
      expect(find.byType(ClipRect), findsWidgets);
    });

    testWidgets('does not render thinking block for user messages',
        (tester) async {
      await tester.pumpWidget(
        _app(
          MessageWidget(
            messageData: <String, dynamic>{
              'kind': 'message',
              'content': 'User thinking',
              'isThinking': true,
            },
            isFromCurrentUser: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // When isFromCurrentUser is true, even with isThinking,
      // it renders as a normal user bubble — no Thinking label.
      expect(find.text('Thinking'), findsNothing);
    });

    testWidgets('hides block when content is literally **', (tester) async {
      // Simulates Opus 4.7 redacted thinking: the parser wraps an empty
      // `thinking` field into `*Thinking...*\n\n**`, which cleans to `**`.
      await tester.pumpWidget(
        _thinkingMessage(content: '*Thinking...*\n\n**'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thinking'), findsNothing);
      expect(find.byIcon(Icons.psychology_outlined), findsNothing);
    });

    testWidgets('hides block when content is empty', (tester) async {
      await tester.pumpWidget(_thinkingMessage(content: ''));
      await tester.pumpAndSettle();

      expect(find.text('Thinking'), findsNothing);
      expect(find.byIcon(Icons.psychology_outlined), findsNothing);
    });

    testWidgets('no background fill color on container', (tester) async {
      await tester.pumpWidget(_thinkingMessage());
      await tester.pumpAndSettle();

      // Find the decorated container inside ClipRRect.
      final clipRRect = find.byType(ClipRRect);
      expect(clipRRect, findsWidgets);

      // The Container should NOT have a background color — only
      // a border. This prevents the gray blob effect.
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(ClipRRect).first,
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.color, isNull);
    });
  });
}
