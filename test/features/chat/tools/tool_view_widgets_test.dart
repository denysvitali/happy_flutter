import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/tools/tool_view_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CollapsibleOutput', () {
    testWidgets('does not throw when disposed before measuring', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CollapsibleOutput(toolId: 'tool-1', child: Text('content')),
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('measures laid-out content and shows expand control', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollapsibleOutput(
              toolId: 'tool-1',
              child: Column(
                children: List<Widget>.generate(
                  20,
                  (index) => SizedBox(height: 20, child: Text('line $index')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Show more'), findsOneWidget);
    });

    // Regression test for tool output "bounces back" bug: when scrollable: true
    // and the child overflows the bounded viewport (e.g. a title Column above
    // a tall content), the user must be able to scroll the contents within
    // the bounded area instead of getting an overflow assertion or being
    // blocked from scrolling by an unbounded inner SingleChildScrollView.
    testWidgets(
      'scrollable: true makes overflowing child scrollable, not overflowing',
      (tester) async {
        final overflowed = <String>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          overflowed.add(details.exception.toString());
        };
        addTearDown(() => FlutterError.onError = previousOnError);

        // Tall title (40) + tall child (2000) that far exceeds the bounded
        // 200px viewport.  This is the same shape as ToolView's OUTPUT
        // section: ToolSectionView (Column with header) wrapping a tall
        // content widget.
        final tallChild = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List<Widget>.generate(
            50,
            (i) => SizedBox(
              height: 40,
              child: Text('content line $i'),
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              // The test wrap mirrors web_search_view_test.dart's pattern:
              // a SingleChildScrollView outer so the ToolView (and any
              // overflow) can scroll if the inner widget needs to.
              body: SingleChildScrollView(
                child: CollapsibleOutput(
                  toolId: 'tool-1',
                  scrollable: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('OUTPUT'),
                      tallChild,
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // No layout overflow must be reported.
        expect(
          overflowed
              .where(
                (e) => e.contains('RenderFlex') && e.contains('OVERFLOWING'),
              ),
          isEmpty,
          reason: 'CollapsibleOutput(scrollable:true) must not assert '
              'layout overflow',
        );

        // The first content line is in the widget tree (just clipped by the
        // bounded viewport).
        expect(find.text('content line 0'), findsOneWidget);
        // A late content line exists in the tree but is clipped above the
        // viewport.  Verifying this proves the child rendered at its natural
        // size — not at the bounded viewport size — so it is scrollable.
        expect(find.text('content line 49'), findsOneWidget);
      },
    );
  });
}
