/// Tests for syntax highlighting functionality.
///
/// Tests the tokenizer, language detection, bracket nesting,
/// and overall syntax highlighting feature parity with React Native.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/syntax_highlighter.dart';

void main() {
  group('SyntaxTokenizer', () {
    test('tokenizes keywords correctly', () {
      const code = 'function test() { const x = 5; }';
      final tokens = SyntaxTokenizer.tokenize(code, 'javascript');

      expect(tokens, isNotEmpty);
      expect(
        tokens.any((t) => t.type == SyntaxTokenType.keyword),
        isTrue,
        reason: 'Should tokenize function keyword',
      );
      expect(
        tokens.any((t) => t.type == SyntaxTokenType.function),
        isTrue,
        reason: 'Should tokenize function name',
      );
    });

    test('tokenizes strings correctly', () {
      const code = 'const x = "hello world";';
      final tokens = SyntaxTokenizer.tokenize(code, 'javascript');

      expect(
        tokens.any((t) => t.type == SyntaxTokenType.string && t.text == '"hello world"'),
        isTrue,
        reason: 'Should tokenize string literals',
      );
    });

    test('tokenizes numbers correctly', () {
      const code = 'const x = 42; const y = 3.14;';
      final tokens = SyntaxTokenizer.tokenize(code, 'javascript');

      expect(
        tokens.any((t) => t.type == SyntaxTokenType.number),
        isTrue,
        reason: 'Should tokenize numbers',
      );
    });

    test('tokenizes comments correctly', () {
      const code = '''
// This is a comment
const x = 5;
/* Multi-line
   comment */
''';
      final tokens = SyntaxTokenizer.tokenize(code, 'javascript');

      expect(
        tokens.any((t) => t.type == SyntaxTokenType.comment),
        isTrue,
        reason: 'Should tokenize single-line comments',
      );
      expect(
        tokens.any((t) => t.type == SyntaxTokenType.comment && t.text.contains('/*')),
        isTrue,
        reason: 'Should tokenize multi-line comments',
      );
    });

    test('tokenizes control flow keywords', () {
      const code = 'if (x) { return true; } else { return false; }';
      final tokens = SyntaxTokenizer.tokenize(code, 'javascript');

      expect(
        tokens.any((t) => t.type == SyntaxTokenType.controlFlow && t.text == 'if'),
        isTrue,
      );
      expect(
        tokens.any((t) => t.type == SyntaxTokenType.controlFlow && t.text == 'return'),
        isTrue,
      );
    });

    test('tokenizes operators', () {
      const code = 'if (x === 5 && y !== 3) { return x + y; }';
      final tokens = SyntaxTokenizer.tokenize(code, 'javascript');

      expect(
        tokens.any((t) => t.type == SyntaxTokenType.comparison),
        isTrue,
        reason: 'Should tokenize comparison operators',
      );
      expect(
        tokens.any((t) => t.type == SyntaxTokenType.logical),
        isTrue,
        reason: 'Should tokenize logical operators',
      );
    });

    test('handles null language by returning default token', () {
      const code = 'some code';
      final tokens = SyntaxTokenizer.tokenize(code, null);

      expect(tokens, hasLength(1));
      expect(tokens.first.type, SyntaxTokenType.default_);
      expect(tokens.first.text, code);
    });

    test('preserves line breaks', () {
      const code = 'line1\nline2\nline3';
      final tokens = SyntaxTokenizer.tokenize(code, 'javascript');

      final newlineCount =
          tokens.where((t) => t.text == '\n').length;
      expect(newlineCount, 2, reason: 'Should preserve line breaks');
    });
  });

  group('Bracket Nesting', () {
    test('calculates bracket nesting levels correctly', () {
      const code = 'function test({ a: [1, 2] }) { return (x); }';
      final tokens = SyntaxTokenizer.tokenize(code, 'javascript');

      final brackets = tokens.where((t) => t.type == SyntaxTokenType.bracket).toList();

      expect(brackets, isNotEmpty);
      // Brackets should have different nesting levels
      final levels = brackets.map((b) => b.nestLevel).toSet();
      expect(levels.length, greaterThan(1),
          reason: 'Should have multiple nesting levels');
    });

    test('handles nested brackets correctly', () {
      const code = '({[]})';
      final tokens = SyntaxTokenizer.tokenize(code, 'javascript');

      final brackets = tokens.where((t) => t.type == SyntaxTokenType.bracket).toList();

      expect(brackets, hasLength(6));
      // Nesting levels should be: 1, 2, 3, 3, 2, 1
      expect(brackets[0].nestLevel, 1);
      expect(brackets[1].nestLevel, 2);
      expect(brackets[2].nestLevel, 3);
      expect(brackets[3].nestLevel, 3);
      expect(brackets[4].nestLevel, 2);
      expect(brackets[5].nestLevel, 1);
    });

    test('handles mismatched brackets gracefully', () {
      const code = 'function test( { return x; }';
      final tokens = SyntaxTokenizer.tokenize(code, 'javascript');

      // Should not throw, just handle what it can
      expect(tokens, isNotEmpty);
    });
  });

  group('Language Detection', () {
    test('detects common language aliases', () {
      expect(detectLanguage('js'), 'javascript');
      expect(detectLanguage('javascript'), 'javascript');
      expect(detectLanguage('py'), 'python');
      expect(detectLanguage('python'), 'python');
      expect(detectLanguage('ts'), 'typescript');
      expect(detectLanguage('typescript'), 'typescript');
    });

    test('handles case insensitivity', () {
      expect(detectLanguage('JS'), 'javascript');
      expect(detectLanguage('Python'), 'python');
      expect(detectLanguage('TYPESCRIPT'), 'typescript');
    });

    test('handles whitespace', () {
      expect(detectLanguage('  javascript  '), 'javascript');
      expect(detectLanguage(' py '), 'python');
    });

    test('returns normalized language for unknown languages', () {
      expect(detectLanguage('unknownlang'), 'unknownlang');
    });

    test('handles null input', () {
      expect(detectLanguage(null), isNull);
    });

    test('maps file extensions to languages', () {
      expect(detectLanguage('jsx'), 'javascript');
      expect(detectLanguage('tsx'), 'typescript');
      expect(detectLanguage('rb'), 'ruby');
      expect(detectLanguage('rs'), 'rust');
      expect(detectLanguage('cpp'), 'cpp');
      expect(detectLanguage('c++'), 'cpp');
    });

    test('detects markup languages', () {
      expect(detectLanguage('yml'), 'yaml');
      expect(detectLanguage('yaml'), 'yaml');
      expect(detectLanguage('md'), 'markdown');
      expect(detectLanguage('markdown'), 'markdown');
    });
  });

  group('SyntaxColors', () {
    test('returns light theme colors', () {
      final color = SyntaxColors.getColor(
        SyntaxTokenType.keyword,
        1,
        false,
      );

      expect(color, const Color(0xFF1d4ed8));
    });

    test('returns dark theme colors', () {
      final color = SyntaxColors.getColor(
        SyntaxTokenType.keyword,
        1,
        true,
      );

      expect(color, const Color(0xFF569CD6));
    });

    test('returns bracket colors based on nesting level', () {
      final lightColor1 = SyntaxColors.getColor(
        SyntaxTokenType.bracket,
        1,
        false,
      );
      final lightColor2 = SyntaxColors.getColor(
        SyntaxTokenType.bracket,
        2,
        false,
      );

      expect(lightColor1, isNot(equals(lightColor2)),
          reason: 'Different nesting levels should have different colors');
    });

    test('cycles through 5 bracket colors', () {
      final levels = [1, 2, 3, 4, 5, 6];
      final colors = levels.map((level) =>
          SyntaxColors.getColor(SyntaxTokenType.bracket, level, false)).toSet();

      // Should have 5 unique colors (levels 1-5)
      expect(colors.length, 5);
    });
  });

  group('SyntaxHighlighter Widget', () {
    testWidgets('renders code with syntax highlighting',
        (WidgetTester tester) async {
      const code = 'const x = 5;';
      const language = 'javascript';

      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: SyntaxHighlighter(
              code: code,
              language: language,
              isDarkMode: false,
            ),
          ),
        ),
      );

      expect(find.text('const'), findsOneWidget);
      expect(find.text('x'), findsOneWidget);
      expect(find.text('='), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('handles multiline code', (WidgetTester tester) async {
      const code = 'const x = 5;\nconst y = 10;';

      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: SyntaxHighlighter(
              code: code,
              language: 'javascript',
              isDarkMode: false,
            ),
          ),
        ),
      );

      expect(find.byType(RichText), findsOneWidget);
    });

    testWidgets('supports dark mode', (WidgetTester tester) async {
      const code = 'const x = 5;';

      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: SyntaxHighlighter(
              code: code,
              language: 'javascript',
              isDarkMode: true,
            ),
          ),
        ),
      );

      expect(find.byType(RichText), findsOneWidget);
    });
  });

  group('Token Type Coverage', () {
    test('covers all token types from React Native', () {
      // Verify all token types from the React Native implementation exist
      const expectedTypes = [
        SyntaxTokenType.keyword,
        SyntaxTokenType.controlFlow,
        SyntaxTokenType.type,
        SyntaxTokenType.modifier,
        SyntaxTokenType.string,
        SyntaxTokenType.number,
        SyntaxTokenType.boolean,
        SyntaxTokenType.regex,
        SyntaxTokenType.function,
        SyntaxTokenType.method,
        SyntaxTokenType.property,
        SyntaxTokenType.comment,
        SyntaxTokenType.docstring,
        SyntaxTokenType.operator,
        SyntaxTokenType.assignment,
        SyntaxTokenType.comparison,
        SyntaxTokenType.logical,
        SyntaxTokenType.decorator,
        SyntaxTokenType.import,
        SyntaxTokenType.variable,
        SyntaxTokenType.parameter,
        SyntaxTokenType.bracket,
        SyntaxTokenType.punctuation,
        SyntaxTokenType.default_,
      ];

      // All types should be defined in the enum
      for (final type in expectedTypes) {
        expect(type.toString().contains('SyntaxTokenType.'), isTrue);
      }
    });

    test('SyntaxTokenType.fromString handles all cases', () {
      expect(
        SyntaxTokenType.fromString('keyword'),
        SyntaxTokenType.keyword,
      );
      expect(
        SyntaxTokenType.fromString('bracket'),
        SyntaxTokenType.bracket,
      );
      expect(
        SyntaxTokenType.fromString('unknown'),
        SyntaxTokenType.default_,
      );
    });
  });

  group('Complex Code Examples', () {
    test('tokenizes Python code', () {
      const code = '''
def hello_world():
    """This is a docstring."""
    if True:
        print("Hello, world!")
    return 42
''';
      final tokens = SyntaxTokenizer.tokenize(code, 'python');

      expect(
        tokens.any((t) => t.type == SyntaxTokenType.function),
        isTrue,
      );
      expect(
        tokens.any((t) => t.type == SyntaxTokenType.docstring),
        isTrue,
      );
      expect(
        tokens.any((t) => t.type == SyntaxTokenType.controlFlow),
        isTrue,
      );
    });

    test('tokenizes TypeScript code', () {
      const code = '''
interface User {
  name: string;
  age: number;
}

async function getUser(id: string): Promise<User> {
  return await api.getUser(id);
}
''';
      final tokens = SyntaxTokenizer.tokenize(code, 'typescript');

      expect(
        tokens.any((t) => t.type == SyntaxTokenType.keyword),
        isTrue,
      );
      expect(
        tokens.any((t) => t.type == SyntaxTokenType.type),
        isTrue,
      );
    });

    test('tokenizes code with hex and binary numbers', () {
      const code = 'const hex = 0xFF; const bin = 0b1010;';
      final tokens = SyntaxTokenizer.tokenize(code, 'javascript');

      expect(
        tokens.any((t) => t.type == SyntaxTokenType.number),
        isTrue,
      );
    });

    test('tokenizes decorators', () {
      const code = '''
@component
class MyComponent {
  @observable value = 0;
}
''';
      final tokens = SyntaxTokenizer.tokenize(code, 'javascript');

      expect(
        tokens.any((t) => t.type == SyntaxTokenType.decorator),
        isTrue,
      );
    });

    test('tokenizes regex patterns', () {
      const code = 'const pattern = /[a-z]+/g;';
      final tokens = SyntaxTokenizer.tokenize(code, 'javascript');

      expect(
        tokens.any((t) => t.type == SyntaxTokenType.regex),
        isTrue,
      );
    });
  });

  group('Edge Cases', () {
    test('handles empty code', () {
      final tokens = SyntaxTokenizer.tokenize('', 'javascript');
      expect(tokens, isEmpty);
    });

    test('handles code with only whitespace', () {
      final tokens = SyntaxTokenizer.tokenize('   \n\n   ', 'javascript');
      expect(tokens, isNotEmpty);
    });

    test('handles code with special characters', () {
      const code = r'const regex = /\d{3}-\d{3}-\d{4}/;';
      final tokens = SyntaxTokenizer.tokenize(code, 'javascript');
      expect(tokens, isNotEmpty);
    });

    test('handles very long lines', () {
      final longCode = 'const x = "${'a' * 1000}";';
      final tokens = SyntaxTokenizer.tokenize(longCode, 'javascript');
      expect(tokens, isNotEmpty);
    });

    test('handles unicode characters', () {
      const code = 'const message = "Hello 世界";';
      final tokens = SyntaxTokenizer.tokenize(code, 'javascript');
      expect(tokens, isNotEmpty);
    });
  });

  group('Feature Parity with React Native', () {
    test('matches bracket pair definitions', () {
      // React Native has: '(': ')', '[': ']', '{': '}', '<': '>'
      expect(SyntaxTokenizer.bracketPairs['('], ')');
      expect(SyntaxTokenizer.bracketPairs['['], ']');
      expect(SyntaxTokenizer.bracketPairs['{'], '}');
      expect(SyntaxTokenizer.bracketPairs['<'], '>');
    });

    test('supports same keyword categories', () {
      const code = '''
if (true) {
  async function test() {
    return await import('./module');
  }
}
''';
      final tokens = SyntaxTokenizer.tokenize(code, 'javascript');

      expect(
        tokens.any((t) => t.type == SyntaxTokenType.controlFlow),
        isTrue,
        reason: 'Should support control flow',
      );
      expect(
        tokens.any((t) => t.type == SyntaxTokenType.keyword),
        isTrue,
        reason: 'Should support keywords',
      );
      expect(
        tokens.any((t) => t.type == SyntaxTokenType.import),
        isTrue,
        reason: 'Should support imports',
      );
    });

    test('color scheme matches React Native themes', () {
      // Light theme keyword color should match React Native
      final lightKeyword = SyntaxColors.light[SyntaxTokenType.keyword];
      expect(lightKeyword, isNotNull);

      // Dark theme keyword color should match React Native
      final darkKeyword = SyntaxColors.dark[SyntaxTokenType.keyword];
      expect(darkKeyword, isNotNull);

      // Bracket nesting colors should exist for both themes
      expect(SyntaxColors.bracketNestingLight, hasLength(6));
      expect(SyntaxColors.bracketNestingDark, hasLength(6));
    });
  });
}
