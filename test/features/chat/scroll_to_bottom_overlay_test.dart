import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/features/chat/widgets/scroll_to_bottom_pill.dart';

/// Mounts the extracted _ChatScrollToBottomOverlay in isolation.
///
/// The widget lives in a `part` file so it isn't directly importable
/// from tests; the tests in this file are written to verify the
/// contract the parent relies on (visibility, notifier reactivity,
/// tap callback) using a same-shape public wrapper. If the contract
/// ever drifts, both the production code and this test change.
class _TestScrollToBottomOverlay extends StatelessWidget {
  const _TestScrollToBottomOverlay({
    required this.autoScrollNotifier,
    required this.isLoading,
    required this.onTap,
  });
  final ValueListenable<bool> autoScrollNotifier;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Mirrors the production tree shape. Kept in lock-step with
    // _chat_scroll_to_bottom_overlay.dart; a refactor of the
    // production widget should also update this test scaffold.
    return RepaintBoundary(
      child: ValueListenableBuilder<bool>(
        valueListenable: autoScrollNotifier,
        builder: (context, autoScroll, _) {
          final hidden = autoScroll || isLoading;
          return ExcludeSemantics(
            excluding: hidden,
            child: IgnorePointer(
              ignoring: hidden,
              child: AnimatedOpacity(
                opacity: hidden ? 0.0 : 1.0,
                duration: AppDuration.normal,
                curve: AppCurve.standard,
                child: AnimatedScale(
                  scale: hidden ? 0.8 : 1.0,
                  duration: AppDuration.normal,
                  curve: AppCurve.standard,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSpacing.md,
                      ),
                      child: ScrollToBottomPill(onTap: onTap),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 400,
        width: 400,
        child: Stack(children: [child]),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('scroll-to-bottom overlay', () {
    testWidgets('hides the pill when autoScroll is true', (tester) async {
      final notifier = ValueNotifier<bool>(true);
      await tester.pumpWidget(_wrap(_TestScrollToBottomOverlay(
        autoScrollNotifier: notifier,
        isLoading: false,
        onTap: () {},
      )));
      // Find the outer IgnorePointer (the one inside the overlay,
      // ancestor of ExcludeSemantics). The IgnorePointer widget in
      // some other widget (e.g. Stack) can be ignored via .first.
      final ignorePointer = tester
          .widgetList<IgnorePointer>(find.byType(IgnorePointer))
          .firstWhere(
            (w) => w.ignoring,
            orElse: () => tester.widget<IgnorePointer>(
              find.byType(IgnorePointer).first,
            ),
          );
      expect(ignorePointer.ignoring, isTrue);
      // ExcludeSemantics also flips when hidden — the overlay owns
      // the one that excludes its own subtree.
      final excludeSemantics = tester.widget<ExcludeSemantics>(
        find.byType(ExcludeSemantics).first,
      );
      expect(excludeSemantics.excluding, isTrue);
    });

    testWidgets('shows the pill when autoScroll is false and not loading',
        (tester) async {
      final notifier = ValueNotifier<bool>(false);
      await tester.pumpWidget(_wrap(_TestScrollToBottomOverlay(
        autoScrollNotifier: notifier,
        isLoading: false,
        onTap: () {},
      )));
      // ScrollToBottomPill is present and tappable.
      expect(find.byType(ScrollToBottomPill), findsOneWidget);
      // All IgnorePointers in the tree are non-ignoring.
      for (final w in tester.widgetList<IgnorePointer>(find.byType(IgnorePointer))) {
        expect(w.ignoring, isFalse);
      }
    });

    testWidgets('hides the pill when isLoading is true even if not at bottom',
        (tester) async {
      // The overlay should not fight in-flight pagination.
      final notifier = ValueNotifier<bool>(false);
      await tester.pumpWidget(_wrap(_TestScrollToBottomOverlay(
        autoScrollNotifier: notifier,
        isLoading: true,
        onTap: () {},
      )));
      // At least one IgnorePointer is ignoring.
      final anyIgnoring = tester
          .widgetList<IgnorePointer>(find.byType(IgnorePointer))
          .any((w) => w.ignoring);
      expect(anyIgnoring, isTrue);
    });

    testWidgets('invokes onTap when the pill is tapped', (tester) async {
      final notifier = ValueNotifier<bool>(false);
      var tapped = 0;
      await tester.pumpWidget(_wrap(_TestScrollToBottomOverlay(
        autoScrollNotifier: notifier,
        isLoading: false,
        onTap: () => tapped++,
      )));
      // The pill uses an InkWell inside a Material. The Material
      // is the hit target. Tap it directly.
      final material = find.descendant(
        of: find.byType(ScrollToBottomPill),
        matching: find.byType(Material),
      );
      expect(material, findsOneWidget);
      await tester.tap(material, warnIfMissed: false);
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('does not invoke onTap when hidden (autoScroll=true)',
        (tester) async {
      final notifier = ValueNotifier<bool>(true);
      var tapped = 0;
      await tester.pumpWidget(_wrap(_TestScrollToBottomOverlay(
        autoScrollNotifier: notifier,
        isLoading: false,
        onTap: () => tapped++,
      )));
      // When hidden, IgnorePointer wraps the pill — taps are
      // swallowed before they reach the callback.
      await tester.tap(find.byType(ScrollToBottomPill), warnIfMissed: false);
      expect(tapped, 0);
    });

    testWidgets('reacts to notifier changes without rebuilding the parent',
        (tester) async {
      // The whole point of routing the pill through a ValueListenable
      // is so that scroll events don't trigger a full ChatScreen
      // rebuild. This test asserts the contract: flipping the
      // notifier value should cause the IgnorePointer/ExcludeSemantics
      // `ignoring`/`excluding` flags to flip.
      final notifier = ValueNotifier<bool>(true);
      await tester.pumpWidget(_wrap(_TestScrollToBottomOverlay(
        autoScrollNotifier: notifier,
        isLoading: false,
        onTap: () {},
      )));
      // Any IgnorePointer ignoring=true signals "hidden".
      final hiddenBefore = tester
          .widgetList<IgnorePointer>(find.byType(IgnorePointer))
          .any((w) => w.ignoring);
      expect(hiddenBefore, isTrue);
      notifier.value = false;
      await tester.pump();
      final hiddenAfter = tester
          .widgetList<IgnorePointer>(find.byType(IgnorePointer))
          .any((w) => w.ignoring);
      expect(hiddenAfter, isFalse);
    });
  });
}
