import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/widgets/chat_input_buttons.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── AbortButton ───────────────────────────────────────────────────

  group('AbortButton', () {
    testWidgets('shows stop icon when not aborting', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AbortButton(isAborting: false, onTap: () {}),
        ),
      );

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
    });

    testWidgets('shows spinner when aborting', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AbortButton(isAborting: true, onTap: () {}),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
    });

    testWidgets('calls onTap when tapped and not aborting', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          AbortButton(isAborting: false, onTap: () => tapped = true),
        ),
      );

      await tester.tap(find.byType(AbortButton));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('does not call onTap when aborting', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          AbortButton(isAborting: true, onTap: () => tapped = true),
        ),
      );

      await tester.tap(find.byType(AbortButton));
      await tester.pump();

      expect(tapped, isFalse);
    });

    testWidgets('has semantics label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AbortButton(isAborting: false, onTap: () {}),
        ),
      );

      // Verify the Semantics widget is present with label 'Stop'
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Stop',
        ),
        findsOneWidget,
      );
    });

    testWidgets('tooltip shows Stop', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AbortButton(isAborting: false, onTap: () {}),
        ),
      );

      expect(find.byType(Tooltip), findsOneWidget);
    });
  });

  // ── SendButton ────────────────────────────────────────────────────

  group('SendButton', () {
    late AnimationController scaleController;

    Widget sendButton({
      required bool isSending,
      required bool isSendDisabled,
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AnimatedBuilder(
          animation: scaleController,
          builder: (context, child) {
            return SendButton(
              isSending: isSending,
              isSendDisabled: isSendDisabled,
              onTap: onTap ?? () {},
              scaleAnimation: scaleController,
            );
          },
        ),
      );
    }

    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      scaleController = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 200),
      )..value = 1.0;
    });

    tearDown(() {
      scaleController.dispose();
    });

    testWidgets('shows arrow icon when not sending', (tester) async {
      await tester.pumpWidget(
        sendButton(isSending: false, isSendDisabled: false),
      );

      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('shows spinner when sending', (tester) async {
      await tester.pumpWidget(
        sendButton(isSending: true, isSendDisabled: false),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        sendButton(
          isSending: false,
          isSendDisabled: false,
          onTap: () => tapped = true,
        ),
      );

      await tester.tap(find.byType(SendButton));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('has semantics label', (tester) async {
      await tester.pumpWidget(
        sendButton(isSending: false, isSendDisabled: false),
      );

      expect(find.bySemanticsLabel('Send'), findsOneWidget);
    });

    testWidgets('tooltip shows Send', (tester) async {
      await tester.pumpWidget(
        sendButton(isSending: false, isSendDisabled: false),
      );

      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('button has circle shape decoration', (tester) async {
      await tester.pumpWidget(
        sendButton(isSending: false, isSendDisabled: false),
      );

      // Find the AnimatedContainer with BoxShape.circle.
      final containers = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final circle = containers.firstWhere((c) {
        final decoration = c.decoration as BoxDecoration?;
        return decoration?.shape == BoxShape.circle;
      });
      expect(circle, isNotNull);
    });
  });
}
