import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:happy_flutter/features/chat/markdown/linear_code_syntax.dart';
import 'package:happy_flutter/features/chat/markdown/markdown_view.dart';
import 'package:markdown/markdown.dart' as md;

void main() {
  String render(String text) =>
      md.markdownToHtml(text, inlineSyntaxes: [LinearCodeSyntax()]);

  test('preserves inline code, delimiter widths and CommonMark whitespace', () {
    for (final input in [
      'Use `value` here.',
      'Use ``a ` b`` here.',
      '` value `',
      '`  `',
      '`a\nb`',
      '`<div>&"`',
      r'Escaped \`marker and `code`',
      'An unfinished `value',
      'A ``` marker with `` no match.',
    ]) {
      expect(render(input), md.markdownToHtml(input), reason: input);
    }
  });

  test('long ordinary code and unfinished input preserve all content', () {
    final code = List.filled(1500, 'value ').join();
    expect(render('`$code`'), contains('<code>$code</code>'));
    // Paragraph parsing trims trailing whitespace outside a code span.
    expect(render('`$code'), '<p>`${code.trimRight()}</p>\n');
  });

  testWidgets('both chat markdown views install the safe inline parser', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MarkdownView(markdown: 'Use `value`.'),
              SimpleMarkdownView(markdown: 'Use `value`.'),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // Exercise the actual two production renderers, including their parser
    // configuration, so a helper-only fix cannot leave a crash path behind.
    expect(find.byType(RichText), findsWidgets);
    final bodies = tester.widgetList<MarkdownBody>(find.byType(MarkdownBody));
    expect(bodies, hasLength(2));
    for (final body in bodies) {
      expect(body.inlineSyntaxes?.single, isA<LinearCodeSyntax>());
    }
  });
}
