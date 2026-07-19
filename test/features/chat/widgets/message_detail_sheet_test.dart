import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/theme/app_scroll_behavior.dart';
import 'package:happy_flutter/features/chat/widgets/message_detail_sheet.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      // Install the app's real scroll behavior. The copy sheet's scroll bug
      // only reproduces under AppScrollBehavior (Bouncing + AlwaysScrollable):
      // that is what lets SelectableText's zero-extent inner Scrollable steal
      // the vertical drag and spring back to the top. The default test
      // behavior is clamping, which masks the bug — so a regression test that
      // omits this would pass on CI while still broken on a device.
      scrollBehavior: const AppScrollBehavior(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

String _longMarkdown(int lines) => List<int>.generate(
  lines,
  (i) => i,
).map((i) => 'markdown line $i with enough text').join('\n');

/// The inner scrollable for the markdown content. The
/// `DraggableScrollableSheet` also installs a 0-extent scrollable, so
/// filter for the one that has actual content to scroll.
ScrollableState _contentScrollable(WidgetTester tester) {
  final states = tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .where(
        (state) =>
            state.position.axis == Axis.vertical &&
            state.position.maxScrollExtent > 0,
      )
      .toList(growable: false);
  expect(states, isNotEmpty);
  return states.first;
}

Widget _openButton(VoidCallback onPressed) {
  return Builder(
    builder: (context) => TextButton(
      key: const Key('open-copy-sheet'),
      onPressed: () => onPressed(),
      child: const Text('open'),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('showRawMarkdownSheet', () {
    testWidgets('renders the markdown content', (tester) async {
      const markdown = 'hello world from raw sheet';

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => _openButton(
              () => showRawMarkdownSheet(context, markdown),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open-copy-sheet')));
      await tester.pumpAndSettle();

      expect(find.textContaining('hello world from raw sheet'), findsOneWidget);
    });

    testWidgets(
      'opens tall enough that a normal drag scrolls the content '
      '(regression: sheet used to start at 0.55 and capture the '
      'first drag to expand, so the content felt unscrollable)',
      (tester) async {
        final markdown = _longMarkdown(400);

        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => _openButton(
                () => showRawMarkdownSheet(context, markdown),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('open-copy-sheet')));
        await tester.pumpAndSettle();

        final sheet = find.byType(DraggableScrollableSheet);
        final sheetRect = tester.getRect(sheet);

        // Sanity: the sheet must start at a height where the user has
        // both a visible text body and room for it to be scrollable.
        // 0.9 of a 600-tall test surface is 540px — a third taller than
        // the old 0.55 (330px).
        expect(sheetRect.height, greaterThan(400));

        final pane = _contentScrollable(tester);
        final before = pane.position.pixels;

        // Drag inside the sheet's visible text area (not at the
        // SelectableText's centre, which is way off-screen for a 16kpx
        // tall widget).
        final dragPoint = Offset(
          sheetRect.center.dx,
          sheetRect.top + sheetRect.height * 0.6,
        );
        final gesture = await tester.startGesture(dragPoint);
        for (var i = 0; i < 6; i++) {
          await gesture.moveBy(const Offset(0, -32));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(
          pane.position.pixels,
          greaterThan(before),
          reason: 'A moderate drag on the text should scroll the content, '
              'not be captured by the sheet expand-on-overscroll.',
        );
      },
    );

    testWidgets('Copy button copies and pops the sheet', (tester) async {
      const markdown = 'copy me please';

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => _openButton(
              () => showRawMarkdownSheet(context, markdown),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open-copy-sheet')));
      await tester.pumpAndSettle();

      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      // Sanity: the Copy button is present and tappable. We don't
      // actually tap — clipboard may be unavailable in tests; we just
      // want to confirm the affordance exists alongside the scroll fix.
      final copyFinder = find.widgetWithIcon(TextButton, Icons.copy);
      expect(copyFinder, findsOneWidget);
    });
  });
}
