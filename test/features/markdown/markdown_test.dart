/// Comprehensive tests for markdown rendering functionality.
///
/// Tests the markdown parser, block widgets, and overall rendering
/// to ensure feature parity with React Native implementation.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/markdown/markdown.dart';

void main() {
  group('MarkdownParser', () {
    test('parses plain text', () {
      const markdown = 'This is plain text.';
      final blocks = parseMarkdown(markdown);

      expect(blocks.length, 1);
      expect(blocks[0], isA<TextBlock>());
      final textBlock = blocks[0] as TextBlock;
      expect(textBlock.content.length, 1);
      expect(textBlock.content[0].text, 'This is plain text.');
    });

    test('parses headers H1-H6', () {
      const markdown = '''
# H1 Header
## H2 Header
### H3 Header
#### H4 Header
##### H5 Header
###### H6 Header
''';
      final blocks = parseMarkdown(markdown);

      expect(blocks.length, 6);
      for (int i = 0; i < 6; i++) {
        expect(blocks[i], isA<HeaderBlock>());
        final header = blocks[i] as HeaderBlock;
        expect(header.level, i + 1);
      }
    });

    test('parses unordered lists', () {
      const markdown = '''
- Item 1
- Item 2
- Item 3
''';
      final blocks = parseMarkdown(markdown);

      expect(blocks.length, 1);
      expect(blocks[0], isA<ListBlock>());
      final list = blocks[0] as ListBlock;
      expect(list.items.length, 3);
    });

    test('parses numbered lists', () {
      const markdown = '''
1. First item
2. Second item
3. Third item
''';
      final blocks = parseMarkdown(markdown);

      expect(blocks.length, 1);
      expect(blocks[0], isA<NumberedListBlock>());
      final list = blocks[0] as NumberedListBlock;
      expect(list.items.length, 3);
      expect(list.items[0].number, 1);
      expect(list.items[1].number, 2);
      expect(list.items[2].number, 3);
    });

    test('parses code blocks with language', () {
      const markdown = '''
```dart
void main() {
  print('Hello');
}
```
''';
      final blocks = parseMarkdown(markdown);

      expect(blocks.length, 1);
      expect(blocks[0], isA<CodeBlock>());
      final code = blocks[0] as CodeBlock;
      expect(code.language, 'dart');
      expect(code.content, contains('void main'));
    });

    test('parses code blocks without language', () {
      const markdown = '''
```
print('Hello');
```
''';
      final blocks = parseMarkdown(markdown);

      expect(blocks.length, 1);
      expect(blocks[0], isA<CodeBlock>());
      final code = blocks[0] as CodeBlock;
      expect(code.language, null);
    });

    test('parses mermaid diagrams', () {
      const markdown = '''
```mermaid
graph TD
    A-->B
```
''';
      final blocks = parseMarkdown(markdown);

      expect(blocks.length, 1);
      expect(blocks[0], isA<MermaidBlock>());
      final mermaid = blocks[0] as MermaidBlock;
      expect(mermaid.content, contains('graph TD'));
    });

    test('parses horizontal rules', () {
      const markdown = '---';
      final blocks = parseMarkdown(markdown);

      expect(blocks.length, 1);
      expect(blocks[0], isA<HorizontalRuleBlock>());
    });

    test('parses tables', () {
      const markdown = '''
| Header 1 | Header 2 |
|----------|----------|
| Cell 1   | Cell 2   |
''';
      final blocks = parseMarkdown(markdown);

      expect(blocks.length, 1);
      expect(blocks[0], isA<TableBlock>());
      final table = blocks[0] as TableBlock;
      expect(table.headers.length, 2);
      expect(table.headers[0], 'Header 1');
      expect(table.headers[1], 'Header 2');
      expect(table.rows.length, 1);
      expect(table.rows[0].length, 2);
    });

    test('parses options blocks', () {
      const markdown = '''
<options>
<option>Option 1</option>
<option>Option 2</option>
</options>
''';
      final blocks = parseMarkdown(markdown);

      expect(blocks.length, 1);
      expect(blocks[0], isA<OptionsBlock>());
      final options = blocks[0] as OptionsBlock;
      expect(options.items.length, 2);
      expect(options.items[0], 'Option 1');
      expect(options.items[1], 'Option 2');
    });

    test('parses inline bold', () {
      const markdown = 'This is **bold** text.';
      final blocks = parseMarkdown(markdown);

      expect(blocks.length, 1);
      final textBlock = blocks[0] as TextBlock;
      expect(textBlock.content.length, greaterThan(1));

      final boldSpan = textBlock.content.firstWhere(
        (span) => span.styles.contains(MarkdownTextStyle.bold),
        orElse: () => throw Exception('No bold span found'),
      );
      expect(boldSpan.text, 'bold');
    });

    test('parses inline italic', () {
      const markdown = 'This is *italic* text.';
      final blocks = parseMarkdown(markdown);

      expect(blocks.length, 1);
      final textBlock = blocks[0] as TextBlock;

      final italicSpan = textBlock.content.firstWhere(
        (span) => span.styles.contains(MarkdownTextStyle.italic),
        orElse: () => throw Exception('No italic span found'),
      );
      expect(italicSpan.text, 'italic');
    });

    test('parses inline code', () {
      const markdown = 'This is `code` text.';
      final blocks = parseMarkdown(markdown);

      expect(blocks.length, 1);
      final textBlock = blocks[0] as TextBlock;

      final codeSpan = textBlock.content.firstWhere(
        (span) => span.styles.contains(MarkdownTextStyle.code),
        orElse: () => throw Exception('No code span found'),
      );
      expect(codeSpan.text, 'code');
    });

    test('parses links', () {
      const markdown = 'This is a [link](https://example.com).';
      final blocks = parseMarkdown(markdown);

      expect(blocks.length, 1);
      final textBlock = blocks[0] as TextBlock;

      final linkSpan = textBlock.content.firstWhere(
        (span) => span.url != null,
        orElse: () => throw Exception('No link span found'),
      );
      expect(linkSpan.text, 'link');
      expect(linkSpan.url, 'https://example.com');
    });

    test('handles incomplete links gracefully', () {
      const markdown = 'This is [incomplete link.';
      final blocks = parseMarkdown(markdown);

      expect(blocks.length, 1);
      final textBlock = blocks[0] as TextBlock;
      // Should render the raw markdown when link is incomplete
      expect(
        textBlock.content.any((span) => span.text.contains('[incomplete')),
        true,
      );
    });

    test('parses mixed inline formatting', () {
      const markdown = '**Bold** and *italic* and `code`';
      final blocks = parseMarkdown(markdown);

      expect(blocks.length, 1);
      final textBlock = blocks[0] as TextBlock;
      expect(textBlock.content.any((s) => s.styles.contains(MarkdownTextStyle.bold)),
          true);
      expect(textBlock.content.any((s) => s.styles.contains(MarkdownTextStyle.italic)),
          true);
      expect(textBlock.content.any((s) => s.styles.contains(MarkdownTextStyle.code)),
          true);
    });

    test('parses complex markdown document', () {
      const markdown = '''
# Title

This is a paragraph with **bold** and *italic* text.

## Subtitle

- List item 1
- List item 2

```dart
void main() {
  print('Hello');
}
```

| Column 1 | Column 2 |
|----------|----------|
| Data 1   | Data 2   |

---

More text here.
''';

      final blocks = parseMarkdown(markdown);

      expect(blocks.length, greaterThan(5));
      expect(blocks[0], isA<HeaderBlock>());
      expect(blocks[1], isA<TextBlock>());
      expect(blocks[2], isA<HeaderBlock>());
      expect(blocks[3], isA<ListBlock>());
      expect(blocks[4], isA<CodeBlock>());
      expect(blocks[5], isA<TableBlock>());
      expect(blocks[6], isA<HorizontalRuleBlock>());
    });

    test('handles empty lines', () {
      const markdown = '''
Text 1


Text 2
''';
      final blocks = parseMarkdown(markdown);

      // Should skip empty lines
      expect(blocks.length, 2);
    });

    test('handles multiline code blocks', () {
      const markdown = '''
```dart
void main() {
  print('Line 1');
  print('Line 2');
  print('Line 3');
}
```
''';
      final blocks = parseMarkdown(markdown);

      expect(blocks.length, 1);
      expect(blocks[0], isA<CodeBlock>());
      final code = blocks[0] as CodeBlock;
      expect(code.content, contains('Line 1'));
      expect(code.content, contains('Line 2'));
      expect(code.content, contains('Line 3'));
    });
  });

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

    testWidgets('renders headers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleMarkdownView(markdown: '# Header\n## Subheader'),
          ),
        ),
      );

      expect(find.text('Header'), findsOneWidget);
      expect(find.text('Subheader'), findsOneWidget);
    });

    testWidgets('renders unordered lists', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleMarkdownView(markdown: '- Item 1\n- Item 2'),
          ),
        ),
      );

      expect(find.text('•'), findsNWidgets(2));
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('renders numbered lists', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleMarkdownView(markdown: '1. First\n2. Second'),
          ),
        ),
      );

      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
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
            body: SimpleMarkdownView(
              markdown: '<options>\n<option>Option 1</option>\n</options>',
            ),
          ),
        ),
      );

      expect(find.text('Option 1'), findsOneWidget);
    });
  });

  group('Markdown Models', () {
    test('MarkdownSpan equality', () {
      const span1 = MarkdownSpan(
        styles: [MarkdownTextStyle.bold],
        text: 'test',
        url: null,
      );
      const span2 = MarkdownSpan(
        styles: [MarkdownTextStyle.bold],
        text: 'test',
        url: null,
      );
      const span3 = MarkdownSpan(
        styles: [MarkdownTextStyle.italic],
        text: 'test',
        url: null,
      );

      expect(span1, equals(span2));
      expect(span1, isNot(equals(span3)));
    });

    test('NumberedItem equality', () {
      const item1 = NumberedItem(
        number: 1,
        spans: [],
      );
      const item2 = NumberedItem(
        number: 1,
        spans: [],
      );
      const item3 = NumberedItem(
        number: 2,
        spans: [],
      );

      expect(item1, equals(item2));
      expect(item1, isNot(equals(item3)));
    });
  });
}
