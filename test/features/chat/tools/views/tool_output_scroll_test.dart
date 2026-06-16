import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/theme/app_scroll_behavior.dart';
import 'package:happy_flutter/features/chat/tools/json_viewer.dart';
import 'package:happy_flutter/features/chat/tools/tool_error.dart';
import 'package:happy_flutter/features/chat/tools/tool_view.dart';
import 'package:happy_flutter/features/chat/tools/views/codex_patch_view.dart';

/// Scroll-behaviour regression coverage for tool-output panes inside the chat.
///
/// These assert the inner bounded panes actually scroll on a touch drag while
/// embedded in a scrollable reverse ListView (the chat). They also document a
/// known liability: text rendered via [SelectableText] installs its own
/// (max=0) vertical viewport that overlaps the pane — kept here so a future
/// change that lets that phantom viewport steal the drag is caught.
String _long(String prefix) =>
    List<int>.generate(300, (i) => i).map((i) => '$prefix $i').join('\n');

ScrollableState _scrollablePane(WidgetTester tester) {
  final states = tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .toList();
  return states.firstWhere(
    (s) =>
        s.position.axis == Axis.vertical &&
        s.position.maxScrollExtent > 0 &&
        s.position.viewportDimension < 450,
    orElse: () => states.first,
  );
}

Finder _richTextContaining(String text) {
  return find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains(text),
  );
}

Future<void> _stepDrag(WidgetTester tester, Offset origin) async {
  final g = await tester.startGesture(origin);
  for (var i = 0; i < 10; i++) {
    await g.moveBy(const Offset(0, -20));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Read content pane scrolls inside a scrollable chat list', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(
              reverse: true,
              children: [
                ToolView(
                  tool: {
                    'name': 'Read',
                    'state': 'completed',
                    'input': {'file_path': '/test.dart'},
                    'result': _long('line'),
                  },
                  sessionId: 's1',
                ),
                for (var i = 0; i < 20; i++)
                  SizedBox(height: 120, child: Text('filler $i')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Expand the (collapsed) completed tool.
    final top = tester.getTopLeft(find.byType(ToolView));
    await tester.tapAt(top + const Offset(60, 20));
    await tester.pumpAndSettle();

    final sized = find.byWidgetPredicate(
      (w) => w is SizedBox && w.height == 400,
    );
    final pane = _scrollablePane(tester);
    final before = pane.position.pixels;
    await _stepDrag(tester, tester.getCenter(sized.first));
    expect(pane.position.pixels, greaterThan(before));
  });

  testWidgets('generic output pane scrolls inside a scrollable chat list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            reverse: true,
            children: [
              SmartOutputContainer(content: _long('out'), maxHeight: 300),
              for (var i = 0; i < 20; i++)
                SizedBox(height: 120, child: Text('filler $i')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pane = _scrollablePane(tester);
    final before = pane.position.pixels;
    await _stepDrag(
      tester,
      tester.getCenter(find.byType(ToolOutputScrollFrame).first),
    );
    expect(pane.position.pixels, greaterThan(before));
  });

  testWidgets(
    'generic output pane scrolls under app-wide bouncing scroll behavior',
    (tester) async {
      // Reproduces the production bounce-back: AppScrollBehavior forces
      // BouncingScrollPhysics + AlwaysScrollable on every descendant, so
      // SelectableText's internal (max=0) EditableText scrollable accepts the
      // drag, wins the arena as the innermost vertical scrollable, overscrolls,
      // and springs back to the top — the real pane never scrolls. Without the
      // clamping override on the content, this test fails (pane stays at 0).
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const AppScrollBehavior(),
          home: Scaffold(
            body: ListView(
              reverse: true,
              children: [
                SmartOutputContainer(content: _long('out'), maxHeight: 300),
                for (var i = 0; i < 20; i++)
                  SizedBox(height: 120, child: Text('filler $i')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pane = _scrollablePane(tester);
      final before = pane.position.pixels;
      await _stepDrag(
        tester,
        tester.getCenter(find.byType(ToolOutputScrollFrame).first),
      );
      expect(pane.position.pixels, greaterThan(before));
    },
  );

  testWidgets('unbounded generic output still creates an inner scroll pane', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SmartOutputContainer(
              content: _long('unbounded'),
              maxHeight: double.infinity,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pane = _scrollablePane(tester);
    final before = pane.position.pixels;
    await _stepDrag(
      tester,
      tester.getCenter(find.byType(ToolOutputScrollFrame).first),
    );
    expect(pane.position.pixels, greaterThan(before));
  });

  testWidgets('failed tool error output scrolls inside a chat list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            reverse: true,
            children: [
              ToolError(message: _long('error')),
              for (var i = 0; i < 20; i++)
                SizedBox(height: 120, child: Text('filler $i')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pane = _scrollablePane(tester);
    final before = pane.position.pixels;
    await _stepDrag(
      tester,
      tester.getCenter(find.byType(ToolOutputScrollFrame).first),
    );
    expect(pane.position.pixels, greaterThan(before));
  });

  testWidgets('expanded apply patch detail remains vertically scrollable', (
    tester,
  ) async {
    final patchLines = List<String>.generate(
      80,
      (i) => '-old line $i\n+new line $i',
    ).join('\n');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CodexPatchView(
              tool: {
                'input': {
                  'patch':
                      '''
*** Begin Patch
*** Update File: lib/long_file.dart
@@
$patchLines
*** End Patch
''',
                },
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_richTextContaining('long_file.dart'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Show all'));
    await tester.pumpAndSettle();

    final pane = _scrollablePane(tester);
    final before = pane.position.pixels;
    await _stepDrag(
      tester,
      tester.getCenter(find.byType(ToolOutputScrollFrame).last),
    );
    expect(pane.position.pixels, greaterThan(before));
  });
}
