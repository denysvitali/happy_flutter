/// Comprehensive tests for markdown rendering functionality.
///
/// Tests the markdown view widgets and overall rendering
/// to ensure feature parity with React Native implementation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/markdown/markdown.dart';

void main() {
  group('MarkdownView Widget', () {
    testWidgets('renders plain text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleMarkdownView(markdown: 'Hello World'),
          ),
        ),
      );

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('renders bold text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleMarkdownView(markdown: '**Bold text**'),
          ),
        ),
      );

      expect(find.textContaining('Bold text'), findsOneWidget);
    });

    testWidgets('renders italic text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleMarkdownView(markdown: '_italic text_'),
          ),
        ),
      );

      expect(find.textContaining('italic text'), findsOneWidget);
    });

    testWidgets('renders headers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleMarkdownView(markdown: '# Header 1\n\n## Header 2'),
          ),
        ),
      );

      expect(find.text('Header 1'), findsOneWidget);
      expect(find.text('Header 2'), findsOneWidget);
    });

    testWidgets('renders unordered lists', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleMarkdownView(
              markdown: '- Item 1\n- Item 2\n- Item 3',
            ),
          ),
        ),
      );

      expect(find.textContaining('Item 1'), findsOneWidget);
      expect(find.textContaining('Item 2'), findsOneWidget);
      expect(find.textContaining('Item 3'), findsOneWidget);
    });

    testWidgets('renders ordered lists', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleMarkdownView(
              markdown: '1. First\n2. Second\n3. Third',
            ),
          ),
        ),
      );

      expect(find.textContaining('First'), findsOneWidget);
      expect(find.textContaining('Second'), findsOneWidget);
      expect(find.textContaining('Third'), findsOneWidget);
    });

    testWidgets('renders code blocks', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleMarkdownView(
              markdown: '```dart\nprint("Hello");\n```',
            ),
          ),
        ),
      );

      expect(find.text('print("Hello");'), findsOneWidget);
    });

    testWidgets('renders tables', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleMarkdownView(
              markdown: '| H1 | H2 |\n|-----|-----|\n| D1 | D2 |',
            ),
          ),
        ),
      );

      expect(find.text('H1'), findsOneWidget);
      expect(find.text('H2'), findsOneWidget);
      expect(find.text('D1'), findsOneWidget);
      expect(find.text('D2'), findsOneWidget);
    });

    testWidgets('renders horizontal rules', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleMarkdownView(markdown: '---'),
          ),
        ),
      );

      final container = find.byType(Container);
      expect(container, findsWidgets);
    });

    testWidgets('renders options blocks', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownView(
              markdown: '<options>\n<option>Option 1</option>\n</options>',
            ),
          ),
        ),
      );

      expect(find.text('Option 1'), findsOneWidget);
    });
  });
}
