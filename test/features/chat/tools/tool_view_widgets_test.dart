import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/tools/tool_status_indicator.dart'
    show ToolState;
import 'package:happy_flutter/features/chat/tools/tool_view_helpers.dart';
import 'package:happy_flutter/features/chat/tools/tool_view_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ToolHeader', () {
    testWidgets('title and status share a common alphabetic baseline '
        '(regression: Workflow 1 steps misalignment)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToolHeader(
              toolIcon: const Icon(Icons.rocket_launch),
              toolTitle: 'Workflow',
              status: '1 steps',
              state: ToolState.completed,
              hasContent: false,
              showCheckFlash: false,
              chevronAnim: const AlwaysStoppedAnimation<double>(0),
              hasPermissionRequest: false,
            ),
          ),
        ),
      );

      final rows = tester.widgetList<Row>(find.byType(Row)).toList();
      final titleRow = rows.firstWhere(
        (r) => r.crossAxisAlignment == CrossAxisAlignment.baseline,
      );
      expect(titleRow.textBaseline, TextBaseline.alphabetic);
    });

    for (final entry in <ToolState, String>{
      ToolState.running: 'Running',
      ToolState.error: 'Failed',
      ToolState.pending: 'Pending',
    }.entries) {
      testWidgets('${entry.key.name} badge includes an explicit label', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ToolStatusBadge(state: entry.key)),
          ),
        );

        expect(find.text(entry.value), findsOneWidget);
      });
    }

    testWidgets('completed badge is a quiet check without repeated text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ToolStatusBadge(state: ToolState.completed)),
        ),
      );

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('Succeeded'), findsNothing);
    });

    testWidgets('completed header omits the status badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToolHeader(
              toolIcon: const Icon(Icons.terminal),
              toolTitle: 'Terminal',
              state: ToolState.completed,
              hasContent: false,
              showCheckFlash: false,
              chevronAnim: const AlwaysStoppedAnimation<double>(0),
              hasPermissionRequest: false,
            ),
          ),
        ),
      );

      expect(find.byType(ToolStatusBadge), findsNothing);
      expect(find.text('Succeeded'), findsNothing);
    });

    testWidgets('renders the tool family accent in an icon tile', (
      tester,
    ) async {
      const accent = Colors.deepPurple;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ToolHeader(
              toolIcon: Icon(Icons.extension),
              toolTitle: 'MCP: Search',
              state: ToolState.completed,
              accentColor: accent,
              hasContent: false,
              showCheckFlash: false,
              chevronAnim: AlwaysStoppedAnimation<double>(0),
              hasPermissionRequest: false,
            ),
          ),
        ),
      );

      final iconTile = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(ToolHeader),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = iconTile.decoration as BoxDecoration;
      expect(decoration.color, accent.withValues(alpha: 0.14));
      expect(decoration.border, isNotNull);
    });

    testWidgets('falls back to the execution accent without a family color', (
      tester,
    ) async {
      final colorScheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: colorScheme),
          home: Scaffold(
            body: ToolHeader(
              toolIcon: const Icon(Icons.build),
              toolTitle: 'Unknown Tool',
              state: ToolState.error,
              hasContent: false,
              showCheckFlash: false,
              chevronAnim: const AlwaysStoppedAnimation<double>(0),
              hasPermissionRequest: false,
            ),
          ),
        ),
      );

      final iconTile = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(ToolHeader),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = iconTile.decoration as BoxDecoration;
      expect(decoration.color, colorScheme.error.withValues(alpha: 0.14));
    });
  });

  group('toolAccentColor', () {
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.indigo);

    test('keeps tool families visually distinct', () {
      expect(
        toolAccentColor('Bash', colorScheme),
        isNot(toolAccentColor('Read', colorScheme)),
      );
      expect(
        toolAccentColor('Read', colorScheme),
        isNot(toolAccentColor('Edit', colorScheme)),
      );
      expect(
        toolAccentColor('github.get_issue', colorScheme),
        colorScheme.tertiary,
      );
    });
  });

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
            (i) => SizedBox(height: 40, child: Text('content line $i')),
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
                    children: [const Text('OUTPUT'), tallChild],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // No layout overflow must be reported.
        expect(
          overflowed.where(
            (e) => e.contains('RenderFlex') && e.contains('OVERFLOWING'),
          ),
          isEmpty,
          reason:
              'CollapsibleOutput(scrollable:true) must not assert '
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

    // Regression test for the "scroll bounces back to top" bug. Tool output
    // panes nest a stateful scrollable whose offset lives in its State. When
    // streaming output crosses the 200px collapse threshold, CollapsibleOutput
    // flips between its bare and collapsible layouts. The child must be
    // *reparented* (its State preserved) rather than torn down and remounted —
    // otherwise the inner ScrollController is recreated at offset 0 and the
    // user's scroll position snaps back. We prove this by counting initState
    // calls on a stateful child across the flip: it must stay 1.
    testWidgets('child State survives the collapse-threshold flip', (
      tester,
    ) async {
      _ProbeState.initCount = 0;

      Widget build(double height) => MaterialApp(
        home: Scaffold(
          body: CollapsibleOutput(
            toolId: 'tool-1',
            child: _Probe(height: height),
          ),
        ),
      );

      // Start short: under 200px so CollapsibleOutput renders the bare child.
      await tester.pumpWidget(build(120));
      await tester.pump();
      expect(_ProbeState.initCount, 1);
      expect(find.text('Show more'), findsNothing);

      // Grow tall: crosses the threshold, flipping to the collapsible layout.
      await tester.pumpWidget(build(600));
      await tester.pump();
      await tester.pump();

      // The flip must reparent the child, not remount it.
      expect(
        _ProbeState.initCount,
        1,
        reason:
            'CollapsibleOutput must preserve child State across the '
            'collapse-threshold flip so inner scroll offset is not reset',
      );
      expect(find.text('Show more'), findsOneWidget);
    });
  });
}

/// A stateful probe that counts how many times its State is initialised.
/// Used to detect whether an ancestor rebuild remounts (initState fires again)
/// or merely reparents (initState stays put) the subtree.
class _Probe extends StatefulWidget {
  const _Probe({required this.height});
  final double height;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  static int initCount = 0;

  @override
  void initState() {
    super.initState();
    initCount++;
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: widget.height, child: const Text('probe'));
}
