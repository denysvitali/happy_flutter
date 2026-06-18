import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/views/read_view.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReadView', () {
    testWidgets('renders file path', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': {'file_path': '/src/main.dart'},
              'state': 'completed',
              'result': 'void main() {}',
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('/src/main.dart'), findsOneWidget);
    });

    testWidgets('renders file content when completed', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': {'file_path': '/test.txt'},
              'state': 'completed',
              'result': 'Hello World',
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('Hello World'), findsOneWidget);
    });

    testWidgets('does not render content when not completed',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': {'file_path': '/test.txt'},
              'state': 'running',
              'result': 'Should not show',
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Should not show'), findsNothing);
    });

    testWidgets('shows "Reading file..." when running', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': {'file_path': '/test.txt'},
              'state': 'running',
              'result': null,
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      // When state is not completed, content is null
      // so we get a "Reading file..." text if totalLines is set
    });

    testWidgets('renders extension badge for known file types',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': {'file_path': '/app.dart'},
              'state': 'completed',
              'result': 'code',
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('dart'), findsOneWidget);
    });

    testWidgets('handles Gemini format with locations array',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': {
                'locations': [
                  {'path': '/gemini/file.py'},
                ],
              },
              'state': 'completed',
              'result': 'python code',
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('/gemini/file.py'), findsOneWidget);
    });

    testWidgets('shows metadata row with offset and limit',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': {
                'file_path': '/big.txt',
                'offset': 10,
                'limit': 20,
              },
              'state': 'completed',
              'result': {
                'content': 'line 11\nline 12',
                'totalLines': 100,
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('Lines'), findsOneWidget);
    });

    testWidgets('shows Content section label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': {'file_path': '/f.txt'},
              'state': 'completed',
              'result': 'some content',
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('CONTENT'), findsOneWidget);
    });

    testWidgets('renders copy button when content is available',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': {'file_path': '/f.txt'},
              'state': 'completed',
              'result': 'copyable',
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('renders long content in a bounded, scrollable viewport',
        (tester) async {
      // 200 lines × ~20dp each = ~4000dp of content. The pane must clip
      // it into a fixed-height viewport and offer a draggable
      // SingleChildScrollView so the user can reach the rest, instead of
      // growing the chat row unbounded or hiding the tail behind a toggle.
      final longContent =
          List.generate(200, (i) => 'line ${i.toString().padLeft(3, '0')}')
              .join('\n');
      // Height covers header chrome (file pill + header + meta) plus the
      // 400dp content viewport with breathing room.
      const boundedHeight = 600.0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            // Bounded parent so the read pane itself is height-constrained
            // — mirrors how a real chat list (the outer ListView) provides
            // a finite height for each tool card.
            body: SizedBox(
              height: boundedHeight,
              child: ReadView(
                tool: {
                  'input': {'file_path': '/long.txt'},
                  'state': 'completed',
                  'result': longContent,
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The inner pane is a SingleChildScrollView (vertical, bounded
      // by maxHeight 400). The outer ChatScreen ListView owns the
      // primary vertical controller; this inner one is non-primary and
      // can be dragged to reveal lines past the viewport.
      final scrollViews = find.byType(SingleChildScrollView);
      expect(scrollViews, findsWidgets);

      // The line numbers live in a single SelectableText (one span per
      // line, joined with \n) — so the tail and head share a widget.
      // The first line number ("1") and the last ("200") both render in
      // the tree even though only the top slice is on-screen.
      final lineNumberText = tester.widgetList<SelectableText>(
        find.byType(SelectableText),
      );
      final allLineNumberText = lineNumberText
          .map((w) => w.data ?? '')
          .join('|');
      expect(allLineNumberText, contains('1\n'));
      expect(allLineNumberText, contains('\n200'));

      // The viewport has a Scrollbar attached so the user sees scroll
      // position feedback (Flutter renders the bar when the inner
      // Scrollable is overflowing).
      expect(find.byType(Scrollbar), findsWidgets);
    });

    testWidgets('defaults to "Unknown" when no file path',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReadView(
            tool: {
              'input': <String, dynamic>{},
              'state': 'completed',
              'result': 'no path',
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Unknown'), findsOneWidget);
    });

    testWidgets(
      'strips cat -n line-number prefix from content', (tester) async {
        // Claude Code's Read tool returns content wrapped in `cat -n`
        // output. Each line carries a right-aligned number + tab
        // (`     1\tcode`). The view renders its own line-number column,
        // so without prefix stripping the line numbers render twice.
        // Exact production format: `cat -n` uses a 6-wide right-aligned
        // field followed by a tab.
        const catNContent =
            '     1\tvoid main() {\n'
            '     2\t  print("hi");\n'
            '     3\t}\n';

        await tester.pumpWidget(
          _wrap(
            ReadView(
              tool: {
                'input': {'file_path': '/example.dart'},
                'state': 'completed',
                'result': catNContent,
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Line-number column shows the three numbers, once.
        final lineNumberData = tester
            .widgetList<SelectableText>(find.byType(SelectableText))
            .map((w) => w.data ?? '')
            .where((s) => RegExp(r'^\d+(\n\d+)*$').hasMatch(s))
            .join('|');
        expect(lineNumberData, '1\n2\n3');

        // No tab characters anywhere in the rendered text — confirms
        // the cat -n prefix was stripped before reaching the
        // SyntaxHighlighter (otherwise `1\tvoid` would appear).
        for (final sel
            in tester.widgetList<SelectableText>(find.byType(SelectableText))) {
          expect(sel.data ?? '', isNot(contains('\t')),
              reason: 'SelectableText has tab (cat -n prefix leak)');
        }
        for (final t in tester.widgetList<Text>(find.byType(Text))) {
          expect(t.data ?? '', isNot(contains('\t')),
              reason: 'Text still contains a tab (cat -n prefix leak)');
        }

        // The actual code text is rendered, sans prefix.
        expect(find.textContaining('void main()'), findsOneWidget);
        expect(find.textContaining('print("hi")'), findsOneWidget);
      },
    );

    testWidgets(
      'uses cat -n start line for offset/limit reads (e.g. line 100, not 1)',
      (tester) async {
        // When the agent requests offset=99, limit=3, Claude Code
        // returns the actual file slice with the file's true line
        // numbers prefixed (100–102), not 1–3. The line-number column
        // should reflect the file's line index so the user sees the
        // same numbers they would in their editor.
        const catNContent =
            '   100\tline 100\n'
            '   101\tline 101\n'
            '   102\tline 102\n';

        await tester.pumpWidget(
          _wrap(
            ReadView(
              tool: {
                'input': {
                  'file_path': '/big.txt',
                  'offset': 99,
                  'limit': 3,
                },
                'state': 'completed',
                'result': catNContent,
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        final lineNumberData = tester
            .widgetList<SelectableText>(find.byType(SelectableText))
            .map((w) => w.data ?? '')
            .where((s) => RegExp(r'^\d+(\n\d+)*$').hasMatch(s))
            .join('|');
        expect(lineNumberData, '100\n101\n102');
      },
    );

    testWidgets(
      'no phantom line at the end from cat -n trailing newline',
      (tester) async {
        // `cat -n` always emits one trailing newline. Without trimming
        // it, `split('\n')` produces an empty phantom entry that would
        // render as a line number past EOF (visible as a blank row at
        // the bottom of the content pane).
        const catNContent =
            '     1\tfirst\n'
            '     2\tsecond\n'
            '     3\tthird\n';

        await tester.pumpWidget(
          _wrap(
            ReadView(
              tool: {
                'input': {'file_path': '/three.txt'},
                'state': 'completed',
                'result': catNContent,
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        final lineNumberData = tester
            .widgetList<SelectableText>(find.byType(SelectableText))
            .map((w) => w.data ?? '')
            .where((s) => RegExp(r'^\d+(\n\d+)*$').hasMatch(s))
            .join('|');
        // Exactly three numbers — no phantom "4".
        expect(lineNumberData, '1\n2\n3');
        expect(lineNumberData, isNot(contains('\n4')));
      },
    );

    testWidgets(
      'plain (non cat-n) content is rendered unchanged',
      (tester) async {
        // Backward-compat: legacy daemons or other agents send raw file
        // content without line-number prefixes. The view should fall
        // back to (offset ?? 0) + 1 and render the content as-is.
        const plainContent = 'apple\nbanana\ncherry';

        await tester.pumpWidget(
          _wrap(
            ReadView(
              tool: {
                'input': {'file_path': '/fruit.txt'},
                'state': 'completed',
                'result': plainContent,
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        final lineNumberData = tester
            .widgetList<SelectableText>(find.byType(SelectableText))
            .map((w) => w.data ?? '')
            .where((s) => RegExp(r'^\d+(\n\d+)*$').hasMatch(s))
            .join('|');
        expect(lineNumberData, '1\n2\n3');
        expect(find.textContaining('apple'), findsOneWidget);
        expect(find.textContaining('banana'), findsOneWidget);
        expect(find.textContaining('cherry'), findsOneWidget);
      },
    );
  });
}
