import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/widgets/chat_input_buttons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── SendButton ────────────────────────────────────────────────────

  group('SendButton', () {
    late AnimationController scaleController;

    Widget sendButton({
      required bool isSending,
      required bool isSendDisabled,
      VoidCallback? onTap,
      String? lastDeliveryStatus,
      MediaQueryData? mediaQueryData,
    }) {
      final button = AnimatedBuilder(
        animation: scaleController,
        builder: (context, child) {
          return SendButton(
            isSending: isSending,
            isSendDisabled: isSendDisabled,
            onTap: onTap ?? () {},
            scaleAnimation: scaleController,
            lastDeliveryStatus: lastDeliveryStatus,
          );
        },
      );
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: mediaQueryData == null
            ? button
            : MediaQuery(data: mediaQueryData, child: button),
      );
    }

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
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
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        sendButton(isSending: false, isSendDisabled: false),
      );

      final node = tester.getSemantics(find.byType(SendButton));
      expect(
        node,
        isSemantics(
          label: 'Send',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      handle.dispose();
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

    testWidgets('disabled state has no tap action', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        sendButton(isSending: false, isSendDisabled: true, onTap: () => taps++),
      );

      await tester.tap(find.byType(SendButton));
      await tester.pump();

      final node = tester.getSemantics(find.byType(SendButton));
      expect(taps, 0);
      expect(
        node,
        isSemantics(
          label: 'Send',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );

      handle.dispose();
    });

    testWidgets('announces sending as a live disabled state', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        sendButton(isSending: true, isSendDisabled: false),
      );

      final node = tester.getSemantics(find.byType(SendButton));
      expect(
        node,
        isSemantics(
          label: 'Sending',
          isButton: true,
          isLiveRegion: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );

      handle.dispose();
    });

    testWidgets('announces a delivered message', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        sendButton(isSending: false, isSendDisabled: true),
      );
      await tester.pumpWidget(
        sendButton(
          isSending: false,
          isSendDisabled: true,
          lastDeliveryStatus: 'sent',
        ),
      );

      final node = tester.getSemantics(find.byType(SendButton));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(
        node,
        isSemantics(
          label: 'Sent',
          isButton: true,
          isLiveRegion: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );

      await tester.pump(kCheckMorphDuration + kCheckHoldDuration);
      handle.dispose();
    });

    testWidgets('removes decorative motion when animations are disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        sendButton(
          isSending: false,
          isSendDisabled: false,
          mediaQueryData: const MediaQueryData(disableAnimations: true),
        ),
      );

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final switcher = tester.widget<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher),
      );
      expect(container.duration, Duration.zero);
      expect(switcher.duration, Duration.zero);
    });

    testWidgets('keeps a 44 pixel touch target', (tester) async {
      await tester.pumpWidget(
        sendButton(isSending: false, isSendDisabled: false),
      );

      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });
}
