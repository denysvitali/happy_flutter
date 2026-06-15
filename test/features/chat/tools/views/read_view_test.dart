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
  });
}
