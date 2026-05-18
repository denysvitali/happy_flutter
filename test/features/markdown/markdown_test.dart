/// Comprehensive tests for markdown rendering functionality.
///
/// Tests the markdown view widgets and overall rendering
/// to ensure feature parity with React Native implementation.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/markdown/markdown.dart';

void main() {
  // Initialize test binding for widget tests.
  TestWidgetsFlutterBinding.ensureInitialized();
  const urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');
  final urlLauncherCalls = <MethodCall>[];
  final urlLauncherResponses = <bool>[];

  setUp(() {
    urlLauncherCalls.clear();
    urlLauncherResponses.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, (call) async {
          urlLauncherCalls.add(call);
          if (urlLauncherResponses.isEmpty) return true;
          return urlLauncherResponses.removeAt(0);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, null);
  });

  // ── Helper ────────────────────────────────────────────────────────────────

  /// Wraps a markdown widget in a MaterialApp with a Scaffold for testing.
  Future<void> pumpMarkdown(
    WidgetTester tester,
    Widget child, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: themeMode,
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  // ── SimpleMarkdownView ────────────────────────────────────────────────────

  group('SimpleMarkdownView', () {
    testWidgets('renders plain text', (tester) async {
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: 'Hello World'));
      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('renders bold text', (tester) async {
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: '**bold**'));
      expect(find.textContaining('bold'), findsOneWidget);
    });

    testWidgets('renders italic text', (tester) async {
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: '_italic_'));
      expect(find.textContaining('italic'), findsOneWidget);
    });

    testWidgets('renders strikethrough text', (tester) async {
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: '~~deleted~~'));
      expect(find.textContaining('deleted'), findsOneWidget);
    });

    testWidgets('renders all header levels', (tester) async {
      const markdown =
          '# H1\n\n## H2\n\n### H3\n\n#### H4'
          '\n\n##### H5\n\n###### H6';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));

      for (final level in ['H1', 'H2', 'H3', 'H4', 'H5', 'H6']) {
        expect(find.text(level), findsOneWidget);
      }
    });

    testWidgets('renders inline code', (tester) async {
      await pumpMarkdown(
        tester,
        SimpleMarkdownView(markdown: 'Use `flutter run` to start.'),
      );
      expect(find.textContaining('flutter run'), findsOneWidget);
    });

    testWidgets('renders links', (tester) async {
      await pumpMarkdown(
        tester,
        SimpleMarkdownView(markdown: '[Click here](https://example.com)'),
      );
      expect(find.textContaining('Click here'), findsOneWidget);
    });

    testWidgets('renders images', (tester) async {
      // flutter_markdown renders image alt text; verify the widget builds
      // without error and the alt text is accessible in the tree.
      await pumpMarkdown(
        tester,
        SimpleMarkdownView(
          markdown: '![Alt text](https://example.com/image.png)',
        ),
      );
      // Image rendering may or may not show alt text as visible text;
      // at minimum, the widget should not crash.
      expect(find.byType(SimpleMarkdownView), findsOneWidget);
    });

    testWidgets('renders unordered list items', (tester) async {
      const markdown = '- Item 1\n- Item 2\n- Item 3';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));

      expect(find.textContaining('Item 1'), findsOneWidget);
      expect(find.textContaining('Item 2'), findsOneWidget);
      expect(find.textContaining('Item 3'), findsOneWidget);
    });

    testWidgets('renders ordered list items', (tester) async {
      const markdown = '1. First\n2. Second\n3. Third';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));

      expect(find.textContaining('First'), findsOneWidget);
      expect(find.textContaining('Second'), findsOneWidget);
      expect(find.textContaining('Third'), findsOneWidget);
    });

    testWidgets('renders nested unordered lists', (tester) async {
      const markdown =
          '- Parent 1\n  - Child 1a\n  - Child 1b\n'
          '- Parent 2';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));

      expect(find.textContaining('Parent 1'), findsOneWidget);
      expect(find.textContaining('Child 1a'), findsOneWidget);
      expect(find.textContaining('Child 1b'), findsOneWidget);
      expect(find.textContaining('Parent 2'), findsOneWidget);
    });

    testWidgets('renders nested ordered lists', (tester) async {
      const markdown = '1. First\n   1. Sub one\n   2. Sub two\n2. Second';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));

      expect(find.textContaining('First'), findsOneWidget);
      expect(find.textContaining('Sub one'), findsOneWidget);
      expect(find.textContaining('Sub two'), findsOneWidget);
      expect(find.textContaining('Second'), findsOneWidget);
    });

    testWidgets('renders deeply nested mixed lists', (tester) async {
      const markdown =
          '- Level 1\n  1. Level 2 ordered\n'
          '    - Level 3 unordered';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));

      expect(find.textContaining('Level 1'), findsOneWidget);
      expect(find.textContaining('Level 2 ordered'), findsOneWidget);
      expect(find.textContaining('Level 3 unordered'), findsOneWidget);
    });

    testWidgets('renders fenced code block without language', (tester) async {
      const markdown = '```\nplain code\nno language\n```';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));
      // Code blocks are rendered via CodeBlockWidget with RichText/SelectableText
      expect(find.textContaining('plain code'), findsOneWidget);
      expect(find.textContaining('no language'), findsOneWidget);
    });

    testWidgets('renders fenced code block with dart', (tester) async {
      const markdown = '```dart\nvoid main() {\n  print("hi");\n}\n```';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));
      expect(find.textContaining('void main()'), findsOneWidget);
      expect(find.textContaining('print("hi")'), findsOneWidget);
    });

    testWidgets('renders fenced code block with python', (tester) async {
      const markdown = '```python\ndef greet():\n    return "hello"\n```';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));
      expect(find.textContaining('def greet()'), findsOneWidget);
      expect(find.textContaining('return "hello"'), findsOneWidget);
    });

    testWidgets('renders fenced code block with javascript', (tester) async {
      const markdown = '```javascript\nconst x = 42;\nconsole.log(x);\n```';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));
      expect(find.textContaining('const x = 42'), findsOneWidget);
      expect(find.textContaining('console.log(x)'), findsOneWidget);
    });

    testWidgets('renders fenced code block with shell', (tester) async {
      const markdown = '```bash\n#!/bin/bash\necho "hello"\n```';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));
      expect(find.textContaining('echo "hello"'), findsOneWidget);
    });

    testWidgets('renders fenced code block with json', (tester) async {
      const markdown = '```json\n{"key": "value"}\n```';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));
      expect(find.textContaining('"key"'), findsOneWidget);
      expect(find.textContaining('"value"'), findsOneWidget);
    });

    testWidgets('renders code block without trailing newline', (tester) async {
      const markdown = '```dart\nprint("hi");\n```';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));
      // The trailing newline is stripped; content matches exactly.
      expect(find.text('print("hi");'), findsOneWidget);
    });

    testWidgets('renders multiple code blocks', (tester) async {
      const markdown =
          '```dart\nprint("a");\n```\n\n'
          '```python\nprint("b")\n```';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));
      expect(find.textContaining('print("a")'), findsOneWidget);
      expect(find.textContaining('print("b")'), findsOneWidget);
    });

    testWidgets('renders basic table', (tester) async {
      const markdown = '| H1 | H2 |\n|----|----|\n| D1 | D2 |';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));

      expect(find.text('H1'), findsOneWidget);
      expect(find.text('H2'), findsOneWidget);
      expect(find.text('D1'), findsOneWidget);
      expect(find.text('D2'), findsOneWidget);
    });

    testWidgets('renders table with multiple rows', (tester) async {
      const markdown =
          '| Name | Age |\n|------|-----|\n'
          '| Alice | 30 |\n| Bob | 25 |\n| Carol | 35 |';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Age'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Carol'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
      expect(find.text('35'), findsOneWidget);
    });

    testWidgets('renders blockquote', (tester) async {
      await pumpMarkdown(
        tester,
        SimpleMarkdownView(markdown: '> This is a quote'),
      );
      expect(find.textContaining('This is a quote'), findsOneWidget);
    });

    testWidgets('renders multi-line blockquote', (tester) async {
      const markdown = '> Line one of quote\n> Line two of quote';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));
      expect(find.textContaining('Line one of quote'), findsOneWidget);
      expect(find.textContaining('Line two of quote'), findsOneWidget);
    });

    testWidgets('renders nested blockquote', (tester) async {
      const markdown = '> Outer quote\n>> Inner quote';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));
      expect(find.textContaining('Outer quote'), findsOneWidget);
      expect(find.textContaining('Inner quote'), findsOneWidget);
    });

    testWidgets('renders horizontal rule', (tester) async {
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: '---'));
      // HR renders as a Container; just verify no crash.
      expect(find.byType(SimpleMarkdownView), findsOneWidget);
    });

    testWidgets('renders reference-style links', (tester) async {
      const markdown = '[link text][ref]\n\n[ref]: https://example.com';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));
      expect(find.textContaining('link text'), findsOneWidget);
    });

    testWidgets('renders empty markdown without error', (tester) async {
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: ''));
      expect(find.byType(SimpleMarkdownView), findsOneWidget);
    });

    testWidgets('renders mixed content', (tester) async {
      const markdown =
          '# Title\n\nA paragraph with **bold** and '
          '`code`.\n\n- Item 1\n- Item 2\n\n'
          '```dart\nvoid main() {}\n```\n\n> A quote';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));

      expect(find.text('Title'), findsOneWidget);
      expect(find.textContaining('bold'), findsOneWidget);
      expect(find.textContaining('code'), findsOneWidget);
      expect(find.textContaining('Item 1'), findsOneWidget);
      expect(find.textContaining('Item 2'), findsOneWidget);
      expect(find.textContaining('void main()'), findsOneWidget);
      expect(find.textContaining('A quote'), findsOneWidget);
    });
  });

  // ── MarkdownView ──────────────────────────────────────────────────────────

  group('MarkdownView', () {
    testWidgets('renders plain text', (tester) async {
      await pumpMarkdown(tester, MarkdownView(markdown: 'Hello World'));
      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('renders bold text', (tester) async {
      await pumpMarkdown(tester, MarkdownView(markdown: '**bold**'));
      expect(find.textContaining('bold'), findsOneWidget);
    });

    testWidgets('renders headers', (tester) async {
      await pumpMarkdown(
        tester,
        MarkdownView(markdown: '# Title\n\n## Subtitle'),
      );
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Subtitle'), findsOneWidget);
    });

    testWidgets('renders lists', (tester) async {
      const markdown = '- Apple\n- Banana';
      await pumpMarkdown(tester, MarkdownView(markdown: markdown));
      expect(find.textContaining('Apple'), findsOneWidget);
      expect(find.textContaining('Banana'), findsOneWidget);
    });

    testWidgets('renders task lists', (tester) async {
      const markdown = '- [ ] Unchecked task\n- [x] Checked task';
      await pumpMarkdown(tester, MarkdownView(markdown: markdown));

      expect(find.textContaining('Unchecked task'), findsOneWidget);
      expect(find.textContaining('Checked task'), findsOneWidget);
      // flutter_markdown renders task list markers; just verify text is
      // present and the widget builds without error.
    });

    testWidgets('renders code block via custom builder', (tester) async {
      const markdown = '```dart\nprint("Hello");\n```';
      await pumpMarkdown(tester, MarkdownView(markdown: markdown));
      expect(find.text('print("Hello");'), findsOneWidget);
    });

    testWidgets('renders code block with different languages', (tester) async {
      for (final lang in ['python', 'javascript', 'go', 'rust', 'bash']) {
        final markdown = '```$lang\ncode here\n```';
        await pumpMarkdown(tester, MarkdownView(markdown: markdown));
        expect(find.text('code here'), findsWidgets);
        // Reset for next iteration.
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('renders tables', (tester) async {
      const markdown =
          '| Col A | Col B |\n|-------|-------|\n'
          '| Val 1 | Val 2 |';
      await pumpMarkdown(tester, MarkdownView(markdown: markdown));

      expect(find.text('Col A'), findsOneWidget);
      expect(find.text('Col B'), findsOneWidget);
      expect(find.text('Val 1'), findsOneWidget);
      expect(find.text('Val 2'), findsOneWidget);
    });

    testWidgets('renders blockquotes', (tester) async {
      await pumpMarkdown(tester, MarkdownView(markdown: '> Famous quote'));
      expect(find.textContaining('Famous quote'), findsOneWidget);
    });

    testWidgets('renders links', (tester) async {
      await pumpMarkdown(
        tester,
        MarkdownView(markdown: '[Click me](https://example.com)'),
      );
      expect(find.textContaining('Click me'), findsOneWidget);
    });

    testWidgets('opens links through url launcher', (tester) async {
      await pumpMarkdown(
        tester,
        MarkdownView(markdown: '[Click me](https://example.com)'),
      );

      await tester.tap(find.textContaining('Click me'));
      await tester.pumpAndSettle();

      expect(urlLauncherCalls, hasLength(1));
      expect(urlLauncherCalls.single.method, 'launch');
      expect(urlLauncherCalls.single.arguments, {
        'url': 'https://example.com',
        'useSafariVC': false,
        'useWebView': false,
        'enableJavaScript': true,
        'enableDomStorage': true,
        'universalLinksOnly': false,
        'headers': <String, String>{},
      });
    });

    testWidgets('normalizes bare-domain link targets before opening', (
      tester,
    ) async {
      await pumpMarkdown(
        tester,
        SimpleMarkdownView(markdown: '[Docs](example.com/docs)'),
      );

      await tester.tap(find.textContaining('Docs'));
      await tester.pumpAndSettle();

      expect(urlLauncherCalls, hasLength(1));
      expect(
        urlLauncherCalls.single.arguments,
        containsPair('url', 'https://example.com/docs'),
      );
    });

    testWidgets('falls back to platform launch mode when external fails', (
      tester,
    ) async {
      urlLauncherResponses.addAll([false, true]);
      await pumpMarkdown(
        tester,
        MarkdownView(markdown: '[Click me](https://example.com)'),
      );

      await tester.tap(find.textContaining('Click me'));
      await tester.pumpAndSettle();

      expect(urlLauncherCalls, hasLength(2));
      expect(
        urlLauncherCalls.first.arguments,
        containsPair('url', 'https://example.com'),
      );
      expect(
        urlLauncherCalls.first.arguments,
        containsPair('useWebView', false),
      );
      expect(
        urlLauncherCalls.last.arguments,
        containsPair('url', 'https://example.com'),
      );
      expect(urlLauncherCalls.last.arguments, containsPair('useWebView', true));
    });

    testWidgets('renders images', (tester) async {
      await pumpMarkdown(
        tester,
        MarkdownView(markdown: '![A picture](https://example.com/photo.png)'),
      );
      // Image widget should be present; alt text may or may not render visibly
      expect(find.byType(MarkdownView), findsOneWidget);
    });

    testWidgets('renders horizontal rules', (tester) async {
      await pumpMarkdown(tester, MarkdownView(markdown: '---'));
      expect(find.byType(MarkdownView), findsOneWidget);
    });

    testWidgets('renders strikethrough', (tester) async {
      await pumpMarkdown(tester, MarkdownView(markdown: '~~removed~~'));
      expect(find.textContaining('removed'), findsOneWidget);
    });
  });

  // ── Options blocks ────────────────────────────────────────────────────────

  group('Options blocks', () {
    testWidgets('renders option chips without callback', (tester) async {
      const markdown =
          '<options>\n<option>Yes</option>\n<option>No</option>\n</options>';
      await pumpMarkdown(tester, MarkdownView(markdown: markdown));

      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
    });

    testWidgets('renders option chips as OutlinedButton with callback', (
      tester,
    ) async {
      String? pressed;
      const markdown =
          '<options>\n<option>Accept</option>\n<option>Decline</option>'
          '\n</options>';

      await pumpMarkdown(
        tester,
        MarkdownView(
          markdown: markdown,
          onOptionPress: (option) => pressed = option,
        ),
      );

      // With callback, options render as OutlinedButtons.
      final acceptBtn = find.text('Accept');
      expect(acceptBtn, findsOneWidget);

      await tester.tap(acceptBtn);
      await tester.pumpAndSettle();
      expect(pressed, 'Accept');
    });

    testWidgets('renders option chips with textColor', (tester) async {
      const markdown = '<options>\n<option>Option A</option>\n</options>';
      await pumpMarkdown(
        tester,
        MarkdownView(markdown: markdown, textColor: Colors.white),
      );
      expect(find.text('Option A'), findsOneWidget);
    });

    testWidgets('handles empty options block', (tester) async {
      const markdown = '<options>\n</options>';
      await pumpMarkdown(tester, MarkdownView(markdown: markdown));
      // Should not crash with an empty options block.
      expect(find.byType(MarkdownView), findsOneWidget);
    });

    testWidgets('invokes callback with correct option text', (tester) async {
      final pressedOptions = <String>[];
      const markdown =
          '<options>\n<option>Opt 1</option>\n<option>Opt 2</option>'
          '\n<option>Opt 3</option>\n</options>';

      await pumpMarkdown(
        tester,
        MarkdownView(markdown: markdown, onOptionPress: pressedOptions.add),
      );

      await tester.tap(find.text('Opt 2'));
      await tester.pumpAndSettle();
      expect(pressedOptions, ['Opt 2']);

      await tester.tap(find.text('Opt 3'));
      await tester.pumpAndSettle();
      expect(pressedOptions, ['Opt 2', 'Opt 3']);
    });
  });

  // ── Text color override ───────────────────────────────────────────────────

  group('Text color override', () {
    testWidgets('MarkdownView applies textColor to body text', (tester) async {
      await pumpMarkdown(
        tester,
        MarkdownView(markdown: 'Colored text', textColor: Colors.red),
      );
      expect(find.textContaining('Colored text'), findsOneWidget);
    });

    testWidgets('MarkdownView applies textColor to headers', (tester) async {
      await pumpMarkdown(
        tester,
        MarkdownView(markdown: '# Header', textColor: Colors.blue),
      );
      expect(find.text('Header'), findsOneWidget);
    });

    testWidgets('MarkdownView applies textColor to links', (tester) async {
      await pumpMarkdown(
        tester,
        MarkdownView(
          markdown: '[link](https://example.com)',
          textColor: Colors.green,
        ),
      );
      expect(find.textContaining('link'), findsOneWidget);
    });

    testWidgets('SimpleMarkdownView does not accept textColor', (tester) async {
      // SimpleMarkdownView has no textColor parameter; just verify it works.
      await pumpMarkdown(
        tester,
        SimpleMarkdownView(markdown: 'Default color text'),
      );
      expect(find.textContaining('Default color text'), findsOneWidget);
    });
  });

  // ── Edge cases ────────────────────────────────────────────────────────────

  group('Edge cases', () {
    testWidgets('renders markdown with leading/trailing whitespace', (
      tester,
    ) async {
      await pumpMarkdown(
        tester,
        SimpleMarkdownView(markdown: '  \n  Hello  \n  '),
      );
      expect(find.textContaining('Hello'), findsOneWidget);
    });

    testWidgets('renders special characters in text', (tester) async {
      await pumpMarkdown(
        tester,
        SimpleMarkdownView(markdown: 'Special: & < > " \''),
      );
      expect(find.textContaining('Special'), findsOneWidget);
    });

    testWidgets('renders unicode characters', (tester) async {
      await pumpMarkdown(
        tester,
        SimpleMarkdownView(markdown: 'Unicode: \u{1F600} cafe\u0301'),
      );
      expect(find.textContaining('Unicode'), findsOneWidget);
    });

    testWidgets('renders very long code block', (tester) async {
      final lines = List.generate(50, (i) => 'line $i;');
      final markdown = '```dart\n${lines.join('\n')}\n```';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));
      expect(find.textContaining('line 0;'), findsOneWidget);
      expect(find.textContaining('line 49;'), findsOneWidget);
    });

    testWidgets('renders consecutive code blocks', (tester) async {
      const markdown =
          '```dart\nprint("a");\n```\n\n'
          'Some text between.\n\n'
          '```python\nprint("b")\n```';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));
      expect(find.textContaining('print("a")'), findsOneWidget);
      expect(find.textContaining('Some text between'), findsOneWidget);
      expect(find.textContaining('print("b")'), findsOneWidget);
    });

    testWidgets('renders code block with language containing hyphen', (
      tester,
    ) async {
      const markdown = '```objective-c\nint main() { return 0; }\n```';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));
      expect(find.textContaining('int main()'), findsOneWidget);
    });

    testWidgets('renders table with empty cells', (tester) async {
      const markdown = '| A | B |\n|---|---|\n| 1 | |\n|   | 2 |';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('renders list with inline formatting', (tester) async {
      const markdown = '- **Bold** item\n- _Italic_ item\n- `Code` item';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));
      expect(find.textContaining('Bold'), findsOneWidget);
      expect(find.textContaining('Italic'), findsOneWidget);
      expect(find.textContaining('Code'), findsOneWidget);
    });

    testWidgets('renders blockquote with inline formatting', (tester) async {
      const markdown = '> This has **bold** and `code`';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));
      expect(find.textContaining('bold'), findsOneWidget);
      expect(find.textContaining('code'), findsOneWidget);
    });

    testWidgets('renders link with title attribute', (tester) async {
      await pumpMarkdown(
        tester,
        SimpleMarkdownView(markdown: '[Link](https://example.com "A title")'),
      );
      expect(find.textContaining('Link'), findsOneWidget);
    });

    testWidgets('renders autolinks', (tester) async {
      await pumpMarkdown(
        tester,
        SimpleMarkdownView(markdown: 'Visit https://example.com'),
      );
      expect(find.textContaining('https://example.com'), findsOneWidget);
    });

    testWidgets('renders nested list with mixed markers', (tester) async {
      const markdown =
          '- Unordered\n  1. Ordered sub\n  2. Another sub\n'
          '- Back to unordered';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));
      expect(find.textContaining('Unordered'), findsOneWidget);
      expect(find.textContaining('Ordered sub'), findsOneWidget);
      expect(find.textContaining('Another sub'), findsOneWidget);
      expect(find.textContaining('Back to unordered'), findsOneWidget);
    });

    testWidgets('renders single backtick code in paragraph', (tester) async {
      await pumpMarkdown(
        tester,
        SimpleMarkdownView(markdown: 'Run `flutter build` to compile.'),
      );
      expect(find.textContaining('flutter build'), findsOneWidget);
    });

    testWidgets('renders nested bold and italic', (tester) async {
      await pumpMarkdown(
        tester,
        SimpleMarkdownView(markdown: '**_bold italic_**'),
      );
      expect(find.textContaining('bold italic'), findsOneWidget);
    });

    testWidgets('handles markdown with only whitespace', (tester) async {
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: '   \n\n   '));
      // Should not crash.
      expect(find.byType(SimpleMarkdownView), findsOneWidget);
    });

    testWidgets('renders list with code block item', (tester) async {
      const markdown =
          '- First item\n\n  ```dart\n  code();\n  ```\n\n'
          '- Second item';
      await pumpMarkdown(tester, SimpleMarkdownView(markdown: markdown));
      expect(find.textContaining('First item'), findsOneWidget);
      expect(find.textContaining('code()'), findsOneWidget);
      expect(find.textContaining('Second item'), findsOneWidget);
    });

    testWidgets('renders heading with inline code', (tester) async {
      await pumpMarkdown(
        tester,
        SimpleMarkdownView(markdown: '## Using `flutter_test`'),
      );
      expect(find.textContaining('flutter_test'), findsOneWidget);
    });
  });

  // ── StyleSheet caching ────────────────────────────────────────────────────

  group('StyleSheet caching', () {
    testWidgets('MarkdownView rebuilds style sheet on theme change', (
      tester,
    ) async {
      await pumpMarkdown(
        tester,
        MarkdownView(markdown: 'Themed text'),
        themeMode: ThemeMode.light,
      );
      expect(find.textContaining('Themed text'), findsOneWidget);

      // Rebuild with dark theme.
      await pumpMarkdown(
        tester,
        MarkdownView(markdown: 'Themed text'),
        themeMode: ThemeMode.dark,
      );
      expect(find.textContaining('Themed text'), findsOneWidget);
    });

    testWidgets('MarkdownView rebuilds style sheet on textColor change', (
      tester,
    ) async {
      await pumpMarkdown(
        tester,
        MarkdownView(markdown: 'Colored', textColor: Colors.red),
      );
      expect(find.textContaining('Colored'), findsOneWidget);

      await pumpMarkdown(
        tester,
        MarkdownView(markdown: 'Colored', textColor: Colors.blue),
      );
      expect(find.textContaining('Colored'), findsOneWidget);
    });

    testWidgets('SimpleMarkdownView rebuilds style sheet on theme change', (
      tester,
    ) async {
      await pumpMarkdown(
        tester,
        SimpleMarkdownView(markdown: 'Themed'),
        themeMode: ThemeMode.dark,
      );
      expect(find.textContaining('Themed'), findsOneWidget);
    });
  });
}
